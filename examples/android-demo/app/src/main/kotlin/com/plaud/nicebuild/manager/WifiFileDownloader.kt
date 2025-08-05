package com.plaud.nicebuild.manager

import android.content.Context
import android.net.Network
import android.os.Environment
import android.util.Log
import com.plaud.nicebuild.data.WifiTransferProgress
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.roundToInt

/**
 * WiFi File Downloader - Downloads files from device via HTTP
 * Based on reference project's HTTP file transfer implementation
 */
class WifiFileDownloader(
    private val context: Context,
    private val wifiConnectionHelper: WifiConnectionHelper
) {
    
    companion object {
        private const val TAG = "WifiFileDownloader"
        private const val HTTP_TIMEOUT = 30000 // 30 seconds
        private const val BUFFER_SIZE = 8192 // 8KB buffer
        private const val MAX_RETRY_COUNT = 3
        private const val RETRY_DELAY = 2000L // 2 seconds
    }
    
    data class DeviceFile(
        val fileName: String,
        val fileSize: Long,
        val sessionId: Long,
        val downloadUrl: String
    )
    
    /**
     * Get file list from device
     */
    suspend fun getFileList(userId: String): Result<List<DeviceFile>> = withContext(Dispatchers.IO) {
        try {
            val deviceUrl = wifiConnectionHelper.getDeviceHttpUrl()
                ?: return@withContext Result.failure(Exception("Device not connected"))
            
            val network = wifiConnectionHelper.getCurrentNetwork()
                ?: return@withContext Result.failure(Exception("No active network"))
            
            Log.i(TAG, "Getting file list from device...")
            
            val url = URL("$deviceUrl/api/files")
            val connection = network.openConnection(url) as HttpURLConnection
            
            connection.apply {
                requestMethod = "GET"
                connectTimeout = HTTP_TIMEOUT
                readTimeout = HTTP_TIMEOUT
                setRequestProperty("User-Agent", "PlaudApp")
                setRequestProperty("X-User-ID", userId)
            }
            
            val responseCode = connection.responseCode
            if (responseCode != 200) {
                connection.disconnect()
                return@withContext Result.failure(Exception("HTTP error: $responseCode"))
            }
            
            val responseBody = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()
            
            // Parse JSON response
            val files = parseFileListResponse(responseBody, deviceUrl)
            
            Log.i(TAG, "Found ${files.size} files on device")
            return@withContext Result.success(files)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting file list: ${e.message}", e)
            return@withContext Result.failure(e)
        }
    }
    
    /**
     * Download files from device
     */
    suspend fun downloadFiles(
        files: List<DeviceFile>,
        userId: String,
        onProgress: (WifiTransferProgress) -> Unit
    ): Result<List<File>> = withContext(Dispatchers.IO) {
        try {
            val downloadedFiles = mutableListOf<File>()
            val downloadDir = getDownloadDirectory()
            
            var totalSize = 0L
            var transferredSize = 0L
            
            // Calculate total size
            files.forEach { totalSize += it.fileSize }
            
            // Download each file
            files.forEachIndexed { index, deviceFile ->
                Log.i(TAG, "Downloading file ${index + 1}/${files.size}: ${deviceFile.fileName}")
                
                // Update progress
                val progress = WifiTransferProgress(
                    totalFiles = files.size,
                    completedFiles = index,
                    currentFileName = deviceFile.fileName,
                    currentFileProgress = 0,
                    totalSize = totalSize,
                    transferredSize = transferredSize
                )
                onProgress(progress)
                
                // Download file with retry
                val downloadResult = downloadFileWithRetry(
                    deviceFile,
                    downloadDir,
                    userId
                ) { currentFileProgress, currentTransferred ->
                    // Update progress during file download
                    val updatedProgress = progress.copy(
                        currentFileProgress = currentFileProgress,
                        transferredSize = transferredSize + currentTransferred
                    )
                    onProgress(updatedProgress)
                }
                
                if (downloadResult.isSuccess) {
                    val downloadedFile = downloadResult.getOrThrow()
                    downloadedFiles.add(downloadedFile)
                    transferredSize += deviceFile.fileSize
                    
                    // Update progress after file completion
                    val completedProgress = WifiTransferProgress(
                        totalFiles = files.size,
                        completedFiles = index + 1,
                        currentFileName = deviceFile.fileName,
                        currentFileProgress = 100,
                        totalSize = totalSize,
                        transferredSize = transferredSize,
                        isCompleted = index + 1 == files.size
                    )
                    onProgress(completedProgress)
                    
                } else {
                    val error = downloadResult.exceptionOrNull()
                    Log.e(TAG, "Failed to download ${deviceFile.fileName}: ${error?.message}")
                    
                    // Update progress with error
                    val errorProgress = WifiTransferProgress(
                        totalFiles = files.size,
                        completedFiles = index,
                        currentFileName = deviceFile.fileName,
                        error = "Failed to download ${deviceFile.fileName}: ${error?.message}"
                    )
                    onProgress(errorProgress)
                    
                    return@withContext Result.failure(error ?: Exception("Download failed"))
                }
            }
            
            Log.i(TAG, "All files downloaded successfully")
            return@withContext Result.success(downloadedFiles)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading files: ${e.message}", e)
            
            val errorMessage = when (e) {
                is java.net.ConnectException -> "Connection failed - please check WiFi connection to device"
                is java.net.SocketTimeoutException -> "Download timeout - device may be busy, please try again"
                is java.net.UnknownHostException -> "Cannot reach device - please check WiFi connection"
                is java.io.IOException -> "File operation failed - please check storage permissions"
                is SecurityException -> "Storage permission denied - please grant storage access"
                else -> "Batch download failed: ${e.message}"
            }
            
            return@withContext Result.failure(Exception(errorMessage, e))
        }
    }
    
    /**
     * Download single file with retry mechanism
     */
    private suspend fun downloadFileWithRetry(
        deviceFile: DeviceFile,
        downloadDir: File,
        userId: String,
        onProgress: (Int, Long) -> Unit
    ): Result<File> = withContext(Dispatchers.IO) {
        var lastException: Exception? = null
        
        repeat(MAX_RETRY_COUNT) { attempt ->
            try {
                val result = downloadSingleFile(deviceFile, downloadDir, userId, onProgress)
                if (result.isSuccess) {
                    return@withContext result
                }
                lastException = result.exceptionOrNull() as? Exception
                
                if (attempt < MAX_RETRY_COUNT - 1) {
                    Log.w(TAG, "Download attempt ${attempt + 1} failed, retrying in ${RETRY_DELAY}ms...")
                    delay(RETRY_DELAY)
                }
                
            } catch (e: Exception) {
                lastException = e
                if (attempt < MAX_RETRY_COUNT - 1) {
                    Log.w(TAG, "Download attempt ${attempt + 1} failed: ${e.message}, retrying...")
                    delay(RETRY_DELAY)
                }
            }
        }
        
        return@withContext Result.failure(lastException ?: Exception("Download failed after $MAX_RETRY_COUNT attempts"))
    }
    
    /**
     * Download single file
     */
    private suspend fun downloadSingleFile(
        deviceFile: DeviceFile,
        downloadDir: File,
        userId: String,
        onProgress: (Int, Long) -> Unit
    ): Result<File> = withContext(Dispatchers.IO) {
        try {
            val network = wifiConnectionHelper.getCurrentNetwork()
                ?: return@withContext Result.failure(Exception("No active network"))
            
            val url = URL(deviceFile.downloadUrl)
            val connection = network.openConnection(url) as HttpURLConnection
            
            connection.apply {
                requestMethod = "GET"
                connectTimeout = HTTP_TIMEOUT
                readTimeout = HTTP_TIMEOUT
                setRequestProperty("User-Agent", "PlaudApp")
                setRequestProperty("X-User-ID", userId)
            }
            
            val responseCode = connection.responseCode
            if (responseCode != 200) {
                connection.disconnect()
                return@withContext Result.failure(Exception("HTTP error: $responseCode"))
            }
            
            val contentLength = connection.contentLengthLong
            val inputStream = connection.inputStream
            
            // Create output file
            val outputFile = File(downloadDir, deviceFile.fileName)
            val outputStream = FileOutputStream(outputFile)
            
            // Download with progress
            val buffer = ByteArray(BUFFER_SIZE)
            var totalBytesRead = 0L
            var bytesRead: Int
            
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
                totalBytesRead += bytesRead
                
                // Update progress
                val progress = if (contentLength > 0) {
                    (totalBytesRead * 100 / contentLength).toInt()
                } else {
                    0
                }
                onProgress(progress, totalBytesRead)
            }
            
            outputStream.close()
            inputStream.close()
            connection.disconnect()
            
            Log.i(TAG, "Downloaded ${deviceFile.fileName} (${totalBytesRead} bytes)")
            return@withContext Result.success(outputFile)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading ${deviceFile.fileName}: ${e.message}", e)
            
            val errorMessage = when (e) {
                is java.net.ConnectException -> "Connection failed - please check WiFi connection to device"
                is java.net.SocketTimeoutException -> "Download timeout - device may be busy, please try again"
                is java.net.UnknownHostException -> "Cannot reach device - please check WiFi connection"
                is java.io.IOException -> "File operation failed - please check storage permissions"
                is SecurityException -> "Storage permission denied - please grant storage access"
                is java.net.HttpRetryException -> "HTTP error - device may not be ready"
                else -> "Download failed: ${e.message}"
            }
            
            return@withContext Result.failure(Exception(errorMessage, e))
        }
    }
    
    /**
     * Parse file list JSON response
     */
    private fun parseFileListResponse(responseBody: String, deviceUrl: String): List<DeviceFile> {
        try {
            val jsonObject = JSONObject(responseBody)
            val filesArray = jsonObject.getJSONArray("files")
            val files = mutableListOf<DeviceFile>()
            
            for (i in 0 until filesArray.length()) {
                val fileObject = filesArray.getJSONObject(i)
                val fileName = fileObject.getString("name")
                val fileSize = fileObject.getLong("size")
                val sessionId = fileObject.optLong("sessionId", 0)
                val downloadPath = fileObject.getString("path")
                val downloadUrl = "$deviceUrl/api/download?path=$downloadPath"
                
                files.add(DeviceFile(fileName, fileSize, sessionId, downloadUrl))
            }
            
            return files
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing file list response: ${e.message}", e)
            return emptyList()
        }
    }
    
    /**
     * Get download directory
     */
    private fun getDownloadDirectory(): File {
        val downloadDir = File(
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
            "PlaudRecordings"
        )
        
        if (!downloadDir.exists()) {
            downloadDir.mkdirs()
        }
        
        return downloadDir
    }
    
    /**
     * Calculate transfer rate
     */
    private fun calculateTransferRate(bytesTransferred: Long, timeElapsed: Long): String {
        if (timeElapsed == 0L) return "0 B/s"
        
        val bytesPerSecond = bytesTransferred * 1000 / timeElapsed
        
        return when {
            bytesPerSecond < 1024 -> "${bytesPerSecond} B/s"
            bytesPerSecond < 1024 * 1024 -> "${(bytesPerSecond / 1024.0).roundToInt()} KB/s"
            else -> "${(bytesPerSecond / (1024.0 * 1024.0)).roundToInt()} MB/s"
        }
    }
}
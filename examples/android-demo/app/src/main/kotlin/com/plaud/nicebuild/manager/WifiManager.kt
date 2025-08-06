package com.plaud.nicebuild.manager

import android.content.Context
import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.plaud.nicebuild.R
import sdk.NiceBuildSdk
import sdk.penblesdk.core.IWifiAgent
import com.plaud.nicebuild.ble.BleCore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.coroutines.suspendCoroutine
import kotlin.coroutines.resume

/**
 * SDK-based WiFi Manager - Simplified WiFi management using SDK interface
 * Replaces the complex WifiTransferManager with a clean SDK-based implementation
 */
class WifiManager private constructor(private val context: Context) : IWifiAgent.WifiTransferCallback {
    
    companion object {
        private const val TAG = "SdkWifiManager"
        
        @Volatile
        private var instance: WifiManager? = null
        
        fun getInstance(context: Context): WifiManager {
            return instance ?: synchronized(this) {
                instance ?: WifiManager(context.applicationContext).also { instance = it }
            }
        }
    }
    
    // Public state for UI observing
    private val _connectionState = MutableLiveData<IWifiAgent.WifiConnectionState>(IWifiAgent.WifiConnectionState.NONE)
    val connectionState: LiveData<IWifiAgent.WifiConnectionState> = _connectionState
    
    private val _transferProgress = MutableLiveData<TransferProgress>()
    val transferProgress: LiveData<TransferProgress> = _transferProgress
    
    private val _errorMessage = MutableLiveData<String>()
    val errorMessage: LiveData<String> = _errorMessage
    
    private val _statusMessage = MutableLiveData<String>()
    val statusMessage: LiveData<String> = _statusMessage
    
    private val _fileTransferCompleted = MutableLiveData<FileTransferCompletedEvent>()
    val fileTransferCompleted: LiveData<FileTransferCompletedEvent> = _fileTransferCompleted
    
    private val _batchDownloadStatus = MutableLiveData<BatchDownloadStatus>()
    val batchDownloadStatus: LiveData<BatchDownloadStatus> = _batchDownloadStatus
    
    // Current session info
    private var currentSessionId: String = ""
    private var isActive: Boolean = false


    /**
     * Transfer progress data class for UI
     */
    data class TransferProgress(
        val sessionId: Long,
        val progress: Int,
        val speedKbps: Float,
        val bytesTransferred: Long,
        val totalBytes: Long,
        val fileName: String? = null
    )
    
    /**
     * File transfer completed event
     */
    data class FileTransferCompletedEvent(
        val sessionId: Long,
        val filePath: String
    )
    
    /**
     * Batch download status data class
     */
    data class BatchDownloadStatus(
        val isActive: Boolean = false,
        val currentIndex: Int = 0,
        val totalFiles: Int = 0,
        val currentFileName: String = "",
        val successCount: Int = 0,
        val failedCount: Int = 0
    )
    
    /**
     * Start WiFi transfer with simplified interface
     */
    fun startWifiTransfer(userId: String): Boolean {
        if (isActive) {
            Log.w(TAG, "WiFi transfer already active")
            return false
        }
        
        Log.i(TAG, "Starting WiFi transfer with userId: $userId")
        
        val wifiAgent = NiceBuildSdk.getWifiAgent()
        if (wifiAgent == null) {
            _errorMessage.postValue("WiFi agent not available - SDK not initialized")
            return false
        }
        
        return wifiAgent.startWifiTransfer(userId, this)
    }
    
    /**
     * Stop WiFi transfer
     */
    fun stopWifiTransfer(): Boolean {
        Log.i(TAG, "Stopping WiFi transfer")
        
        val wifiAgent = NiceBuildSdk.getWifiAgent()
        if (wifiAgent == null) {
            Log.w(TAG, "WiFi agent not available")
            return false
        }
        
        val result = wifiAgent.stopWifiTransfer()
        if (result) {
            isActive = false
            currentSessionId = ""
            _connectionState.postValue(IWifiAgent.WifiConnectionState.NONE)
        }
        
        return result
    }
    
    /**
     * Download all files from device
     */
    fun downloadAllFiles(): Boolean {
        Log.i(TAG, "Requesting to download all files")
        
        val wifiAgent = NiceBuildSdk.getWifiAgent()
        if (wifiAgent == null) {
            _errorMessage.postValue("WiFi agent not available")
            return false
        }
        
        if (!wifiAgent.isTransferActive()) {
            _errorMessage.postValue("WiFi transfer is not active")
            return false
        }
        
        return wifiAgent.downloadAllFiles()
    }
    

    /**
     * Get file list from device
     */
    fun getFileList(): Boolean {
        val wifiAgent = NiceBuildSdk.getWifiAgent()
        if (wifiAgent == null) {
            _errorMessage.postValue("WiFi agent not available")
            return false
        }
        
        return wifiAgent.getFileList()
    }
    
    /**
     * Check if WiFi transfer is currently active
     */
    fun isTransferActive(): Boolean {
        return isActive && NiceBuildSdk.isWifiTransferActive()
    }
    
    /**
     * Get current connection state
     */
    fun getCurrentConnectionState(): IWifiAgent.WifiConnectionState {
        val wifiAgent = NiceBuildSdk.getWifiAgent()
        return wifiAgent?.getConnectionState() ?: IWifiAgent.WifiConnectionState.NONE
    }
    
    /**
     * Check prerequisites for WiFi transfer
     */
    fun checkPrerequisites(): Boolean {
        val wifiAgent = NiceBuildSdk.getWifiAgent()
        return wifiAgent?.checkPrerequisites() ?: false
    }
    
    /**
     * Get current session ID
     */
    fun getCurrentSessionId(): String = currentSessionId
    
    /**
     * Get current user ID from connected BLE device
     */
    private fun getCurrentUserId(): String? {
        return try {
            // Use timestamp-based user ID for now
            // TODO: Integrate with BLE manager to get actual device info
            "user_${System.currentTimeMillis() / 1000}"
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get current user ID: ${e.message}")
            null
        }
    }
    
    // IWifiAgent.WifiTransferCallback implementations
    
    override fun onConnectionStateChanged(state: IWifiAgent.WifiConnectionState) {
        Log.i(TAG, "Connection state changed: $state")
        _connectionState.postValue(state)
        
        when (state) {
            IWifiAgent.WifiConnectionState.READY -> {
                isActive = true
                // Automatically get file list when ready
                val wifiAgent = NiceBuildSdk.getWifiAgent()
                wifiAgent?.getFileList()
            }
            IWifiAgent.WifiConnectionState.DISCONNECTED,
            IWifiAgent.WifiConnectionState.ERROR -> {
                isActive = false
                currentSessionId = ""
            }
            else -> { /* Other states handled by UI */ }
        }
    }
    
    override fun onHandshakeCompleted(sessionId: String) {
        Log.i(TAG, "Handshake completed: $sessionId")

        downloadAllFiles()
    }
    
    override fun onFileListReceived(files: List<IWifiAgent.WifiFileInfo>) {
        Log.i(TAG, "Received ${files.size} files from device")
        
        if (files.isNotEmpty()) {
            // For demonstration, download all files automatically
            // In real app, you might want to show file list to user
            val wifiAgent = NiceBuildSdk.getWifiAgent()
            wifiAgent?.downloadAllFiles()
        } else {
            Log.i(TAG, "No files to download")
        }
    }
    
    override fun onTransferProgress(
        sessionId: Long, 
        progress: Int, 
        speedKbps: Float,
        bytesTransferred: Long, 
        totalBytes: Long
    ) {
        Log.d(TAG, "Transfer progress: $progress% (${speedKbps} KB/s)")
        
        _transferProgress.postValue(
            TransferProgress(
                sessionId = sessionId,
                progress = progress,
                speedKbps = speedKbps,
                bytesTransferred = bytesTransferred,
                totalBytes = totalBytes
            )
        )
    }
    
    override fun onFileTransferCompleted(sessionId: Long, filePath: String) {
        Log.i(TAG, "File transfer completed: $filePath")
        
        // Update progress to show completion
        _transferProgress.postValue(
            TransferProgress(
                sessionId = sessionId,
                progress = 100,
                speedKbps = 0f,
                bytesTransferred = 0L,
                totalBytes = 0L,
                fileName = filePath.substringAfterLast("/")
            )
        )
        
        // Post a signal that file transfer is completed
        // This will be used by UI to refresh file list
        _fileTransferCompleted.postValue(FileTransferCompletedEvent(sessionId, filePath))
    }
    
    override fun onDeviceBatteryUpdate(batteryLevel: Int, isCharging: Boolean, voltage: Float) {
        Log.d(TAG, "Device battery update: level=$batteryLevel%, charging=$isCharging, voltage=${voltage}V")
        // Battery info is mainly for monitoring, can be used to show device status in UI if needed
    }
    
    override fun onError(code: Int, message: String) {
        Log.e(TAG, "WiFi transfer error: $message (code: $code)")
        
        // Handle specific WiFi connection failures that may leave device in WiFi mode
        when (code) {
            1003 -> { // Failed to connect to device WiFi
                Log.w(TAG, "WiFi connection failed - device may be stuck in WiFi mode, initiating BLE recovery...")
                handleWifiFailureRecovery("WiFi connection failed")
            }
            1004 -> { // WebSocket handshake failed  
                Log.w(TAG, "WiFi handshake failed - device may be stuck in WiFi mode, initiating BLE recovery...")
                handleWifiFailureRecovery("WiFi handshake failed")
            }
            1005 -> { // WebSocket port already in use
                Log.w(TAG, "WebSocket port conflict - initiating BLE recovery...")
                handleWifiFailureRecovery("WiFi port conflict")
            }
            else -> {
                Log.w(TAG, "WiFi error occurred: $message")
            }
        }
        
        _errorMessage.postValue(message)
    }
    
    override fun onWifiTransferStopped() {
        Log.i(TAG, "WiFi transfer stopped normally, initiating BLE reconnection...")
        
        // Use coroutine to handle BLE reconnection for normal WiFi transfer completion
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Waiting for device to completely exit WiFi mode after normal transfer...")

                // Wait longer for normal transfer since device needs to clean up transfer state
                delay(15000) // 15 seconds wait for device to cleanly exit WiFi mode
                
                val bleCore = BleCore.getInstance(context)
                val currentDevice = bleCore.getCurrentDevice()
                
                if (currentDevice != null && !bleCore.isConnected()) {
                    Log.i(TAG, "Starting BLE reconnection after normal WiFi transfer...")
                    
                    withContext(Dispatchers.Main) {
                        _statusMessage.postValue("Reconnecting BLE after WiFi transfer...")
                    }
                    
                    var reconnectionSuccess = false
                    
                    for (attempt in 1..3) {
                        Log.i(TAG, "BLE reconnection attempt $attempt/3 after normal transfer")
                        
                        val result = suspendCoroutine<Boolean> { continuation ->
                            bleCore.connectDevice(
                                currentDevice.serialNumber, 
                                currentDevice.serialNumber
                            ) { success, code, message ->
                                Log.i(TAG, "BLE reconnection attempt $attempt result: success=$success, code=$code, message=$message")
                                continuation.resume(success)
                            }
                        }
                        
                        if (result) {
                            delay(3000) // Wait for handshake
                            if (bleCore.isConnected()) {
                                reconnectionSuccess = true
                                Log.i(TAG, "BLE reconnection successful on attempt $attempt")
                                break
                            }
                        }
                        
                        if (attempt < 3) {
                            delay(5000) // 5s wait between attempts
                        }
                    }
                    
                    if (reconnectionSuccess) {
                        _statusMessage.postValue("BLE reconnected successfully")
                    } else {
                        _statusMessage.postValue("BLE reconnection failed - please manually reconnect")
                    }
                    
                } else if (bleCore.isConnected()) {
                    Log.i(TAG, "BLE already connected after WiFi transfer")
                    _statusMessage.postValue("BLE connection maintained")
                } else {
                    Log.w(TAG, "No device info available for BLE reconnection")
                    _statusMessage.postValue("No device available for reconnection")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error during normal BLE reconnection: ${e.message}", e)
                _statusMessage.postValue("BLE reconnection error: ${e.message}")
            }
        }
    }
    
    /**
     * Handle WiFi failure recovery - attempt to get device back to BLE mode
     */
    private fun handleWifiFailureRecovery(reason: String) {
        Log.i(TAG, "Starting WiFi failure recovery due to: $reason")
        
        // Use coroutine to handle BLE recovery
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "Waiting for device to exit failed WiFi state...")
                
                // Phase 1: Wait for device to potentially auto-recover from WiFi failure
                delay(5000) // Shorter initial wait since this is error recovery
                
                val bleCore = com.plaud.nicebuild.ble.BleCore.getInstance(context)
                val currentDevice = bleCore.getCurrentDevice()
                
                if (currentDevice != null) {
                    // Check if BLE is already connected (rare but possible)
                    if (bleCore.isConnected()) {
                        Log.i(TAG, "BLE already connected after WiFi failure - no recovery needed")
                        _statusMessage.postValue("BLE connection maintained")
                        return@launch
                    }
                    
                    // Phase 2: Attempt to force device back to BLE mode
                    Log.i(TAG, "Attempting to recover device to BLE mode after WiFi failure...")
                    
                    withContext(Dispatchers.Main) {
                        _statusMessage.postValue("Recovering device connection after WiFi error...")
                    }
                    
                    // Try immediate BLE reconnection first (device might auto-recover quickly)
                    var recoverySuccess = false
                    
                    Log.i(TAG, "Attempting immediate BLE recovery...")
                    val immediateResult = suspendCoroutine<Boolean> { continuation ->
                        bleCore.connectDevice(
                            currentDevice.serialNumber, 
                            currentDevice.serialNumber
                        ) { success, code, message ->
                            Log.i(TAG, "Immediate BLE recovery result: success=$success, code=$code, message=$message")
                            continuation.resume(success)
                        }
                    }
                    
                    if (immediateResult && bleCore.isConnected()) {
                        recoverySuccess = true
                        Log.i(TAG, "Immediate BLE recovery successful")
                    } else {
                        Log.w(TAG, "Immediate BLE recovery failed, waiting longer for device reset...")
                        
                        // Phase 3: Extended wait and multiple recovery attempts
                        delay(10000) // Additional 10s wait for device to reset from WiFi failure
                        
                        for (attempt in 1..3) { // Fewer attempts for error recovery
                            Log.i(TAG, "BLE recovery attempt $attempt/3 after WiFi failure")
                            
                            val result = suspendCoroutine<Boolean> { continuation ->
                                bleCore.connectDevice(
                                    currentDevice.serialNumber, 
                                    currentDevice.serialNumber
                                ) { success, code, message ->
                                    Log.i(TAG, "BLE recovery attempt $attempt result: success=$success, code=$code, message=$message")
                                    continuation.resume(success)
                                }
                            }
                            
                            if (result) {
                                // Verify the connection has completed handshake
                                delay(3000)
                                if (bleCore.isConnected()) {
                                    recoverySuccess = true
                                    Log.i(TAG, "BLE recovery successful on attempt $attempt")
                                    break
                                } else {
                                    Log.w(TAG, "BLE recovery attempt $attempt - connection lost immediately")
                                }
                            } else {
                                Log.w(TAG, "BLE recovery attempt $attempt failed")
                            }
                            
                            if (attempt < 3) {
                                val waitTime = attempt * 5000L // 5s, 10s wait between attempts
                                Log.i(TAG, "Waiting ${waitTime}ms before next recovery attempt...")
                                delay(waitTime)
                            }
                        }
                    }
                    
                    if (recoverySuccess) {
                        _statusMessage.postValue("Device connection recovered successfully")
                        Log.i(TAG, "WiFi failure recovery completed successfully")
                    } else {
                        _statusMessage.postValue("Device recovery failed - please manually reconnect")
                        Log.w(TAG, "WiFi failure recovery failed - manual intervention may be required")
                    }
                    
                } else {
                    Log.w(TAG, "No device info available for WiFi failure recovery")
                    _statusMessage.postValue("No device available for recovery")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error during WiFi failure recovery: ${e.message}", e)
                _statusMessage.postValue("Recovery error: ${e.message}")
            }
        }
    }
    
    // Implementation of new batch download callbacks
    override fun onBatchDownloadStarted(totalFiles: Int) {
        Log.i(TAG, "Batch download started: $totalFiles files")
        _batchDownloadStatus.postValue(
            BatchDownloadStatus(
                isActive = true,
                totalFiles = totalFiles
            )
        )
        _statusMessage.postValue(context.getString(R.string.wifi_batch_download_start, totalFiles))
    }

    override fun onBatchDownloadProgress(currentIndex: Int, totalFiles: Int, currentFileName: String) {
        Log.i(TAG, "Batch download progress: $currentIndex/$totalFiles - $currentFileName")
        _batchDownloadStatus.postValue(
            BatchDownloadStatus(
                isActive = true,
                currentIndex = currentIndex,
                totalFiles = totalFiles,
                currentFileName = currentFileName
            )
        )
                        _statusMessage.postValue(context.getString(R.string.wifi_batch_download_progress, currentIndex, totalFiles, currentFileName))
    }

    override fun onBatchDownloadCompleted(successCount: Int, failedCount: Int, results: MutableList<IWifiAgent.BatchDownloadResult>) {
        Log.i(TAG, "Batch download completed: $successCount success, $failedCount failed")
        _batchDownloadStatus.postValue(
            BatchDownloadStatus(
                isActive = false,
                successCount = successCount,
                failedCount = failedCount
            )
        )
        
        val message =             if (failedCount == 0) {
                context.getString(R.string.wifi_batch_download_success_all, successCount)
            } else {
                context.getString(R.string.wifi_batch_download_success_partial, successCount, failedCount)
            }
        _statusMessage.postValue(message)
    }
} 
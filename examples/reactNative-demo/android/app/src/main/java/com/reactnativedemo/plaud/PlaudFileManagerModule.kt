package com.reactnativedemo.plaud

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import sdk.penblesdk.TntAgent
import sdk.penblesdk.entity.AgentCallback
import sdk.penblesdk.entity.BleFile
import sdk.penblesdk.entity.bean.ble.response.GetRecSessionsRsp
import sdk.penblesdk.entity.bean.ble.response.StorageRsp
import sdk.penblesdk.entity.bean.ble.response.GetStateRsp
import sdk.penblesdk.entity.bean.ble.response.ClearRecordFileRsp
import sdk.penblesdk.entity.bean.ble.response.SyncFileHeadRsp
import sdk.penblesdk.entity.bean.ble.response.SyncFileTailRsp
import sdk.penblesdk.entity.bean.ble.response.BattStatusRsp
import sdk.penblesdk.viocedata.ISyncVoiceDataKeepOut
import java.util.Date
import java.text.SimpleDateFormat
import java.util.Locale
import java.io.File
import java.io.FileOutputStream
import android.os.Environment

class PlaudFileManagerModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val TAG = "PlaudFileManagerModule"

    override fun getName(): String {
        return "PlaudFileManager"
    }

    /**
     * 发送事件到React Native
     */
    private fun sendEvent(eventName: String, params: WritableMap?) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }

    /**
     * 获取录音文件列表
     */
    @ReactMethod
    fun getFileList(promise: Promise) {
        try {
            Log.i(TAG, "📁 Getting recording file list...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // 获取所有文件，sessionId设为0表示获取全部
            bleAgent.getRecSessions(
                0L,
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "📁 Get file list request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<GetRecSessionsRsp> {
                    override fun onCallback(response: GetRecSessionsRsp?) {
                        Log.i(TAG, "📁 Get file list response: $response")
                        if (response != null) {
                            val fileList = response.fileList
                            Log.i(TAG, "✅ Found ${fileList.size} files")
                            
                            // 转换为React Native可用的数据格式
                            val rnFileList = Arguments.createArray()
                            for ((index, file) in fileList.withIndex()) {
                                try {
                                    Log.d(TAG, "📄 Processing file $index: sessionId=${file.sessionId}, size=${file.fileSize}, scene=${file.scene}")
                                    
                                    val duration = BleFile.calculateOpusDuration(file.fileSize, 1)
                                    Log.d(TAG, "📄 File $index duration calculated: ${duration}ms")
                                    
                                    val fileInfo = Arguments.createMap().apply {
                                        putDouble("sessionId", file.sessionId.toDouble())
                                        putDouble("fileSize", file.fileSize.toDouble())
                                        putInt("scene", file.scene)
                                        putInt("attribute", file.attribute)
                                        putDouble("startTime", file.startTime.toDouble())
                                        putDouble("endTime", file.endTime.toDouble())
                                        putString("sceneName", getSceneName(file.scene))
                                        putString("duration", formatDuration(duration))
                                        putString("sizeText", formatFileSize(file.fileSize))
                                        putString("createTime", formatTime(file.startTime))
                                    }
                                    rnFileList.pushMap(fileInfo)
                                    Log.d(TAG, "📄 File $index added to array successfully")
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ Error processing file $index: ${e.message}", e)
                                    // 继续处理下一个文件，不要因为一个文件出错就停止
                                }
                            }
                            Log.i(TAG, "📁 Final file array size: ${rnFileList.size()}")
                            
                            promise.resolve(Arguments.createMap().apply {
                                putBoolean("success", true)
                                putArray("files", rnFileList)
                                putInt("total", fileList.size)
                                putString("message", "File list retrieved successfully")
                            })
                        } else {
                            Log.w(TAG, "❌ Get file list failed, no response")
                            promise.reject("GET_FILES_FAILED", "Get file list failed, no response")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Get file list error: $errorCode")
                        promise.reject("GET_FILES_ERROR", "Get file list error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Get file list error", e)
            promise.reject("GET_FILES_ERROR", "Get file list error: ${e.message}", e)
        }
    }

    /**
     * 获取设备存储信息
     */
    @ReactMethod
    fun getStorageInfo(promise: Promise) {
        try {
            Log.i(TAG, "💾 Getting storage info...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            bleAgent.getStorage(
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "💾 Get storage request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<StorageRsp> {
                    override fun onCallback(response: StorageRsp?) {
                        Log.i(TAG, "💾 Get storage response: $response")
                        if (response != null) {
                            val totalSpace = response.total
                            val freeSpace = response.free
                            val usedSpace = totalSpace - freeSpace
                            val usagePercent = if (totalSpace > 0) (usedSpace * 100.0 / totalSpace) else 0.0
                            
                            Log.i(TAG, "✅ Storage info: total=${formatFileSize(totalSpace)}, free=${formatFileSize(freeSpace)}, used=${formatFileSize(usedSpace)}")
                            
                            promise.resolve(Arguments.createMap().apply {
                                putBoolean("success", true)
                                putDouble("totalSpace", totalSpace.toDouble())
                                putDouble("freeSpace", freeSpace.toDouble())
                                putDouble("usedSpace", usedSpace.toDouble())
                                putDouble("usagePercent", usagePercent)
                                putString("totalSpaceText", formatFileSize(totalSpace))
                                putString("freeSpaceText", formatFileSize(freeSpace))
                                putString("usedSpaceText", formatFileSize(usedSpace))
                            })
                        } else {
                            Log.w(TAG, "❌ Get storage info failed, no response")
                            promise.reject("GET_STORAGE_FAILED", "Get storage info failed, no response")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Get storage info error: $errorCode")
                        promise.reject("GET_STORAGE_ERROR", "Get storage info error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Get storage info error", e)
            promise.reject("GET_STORAGE_ERROR", "Get storage info error: ${e.message}", e)
        }
    }

    /**
     * 获取设备状态
     */
    @ReactMethod
    fun getDeviceState(promise: Promise) {
        try {
            Log.i(TAG, "📱 Getting device state...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            bleAgent.getState(
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "📱 Get state request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<GetStateRsp> {
                    override fun onCallback(response: GetStateRsp?) {
                        Log.i(TAG, "📱 Get state response: $response")
                        if (response != null) {
                            promise.resolve(Arguments.createMap().apply {
                                putBoolean("success", true)
                                putDouble("state", response.stateCode.toDouble())
                                putDouble("sessionId", response.sessionId.toDouble())
                                putInt("scene", response.scene)
                                putString("sceneName", getSceneName(response.scene))
                                putBoolean("isRecording", response.stateCode == sdk.penblesdk.Constants.DEVICE_STATUS_RECORDING)
                            })
                        } else {
                            Log.w(TAG, "❌ Get device state failed, no response")
                            promise.reject("GET_STATE_FAILED", "Get device state failed, no response")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Get device state error: $errorCode")
                        promise.reject("GET_STATE_ERROR", "Get device state error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Get device state error", e)
            promise.reject("GET_STATE_ERROR", "Get device state error: ${e.message}", e)
        }
    }

    /**
     * 清理设备上的所有录音文件
     */
    @ReactMethod
    fun clearAllFiles(promise: Promise) {
        try {
            Log.i(TAG, "🗑️ Clearing all recording files...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            bleAgent.clearRecordFile(
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "🗑️ Clear files request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<ClearRecordFileRsp> {
                    override fun onCallback(response: ClearRecordFileRsp?) {
                        Log.i(TAG, "🗑️ Clear files response: $response")
                        if (response != null) {
                            val status = response.status
                            if (status == 0) {
                                Log.i(TAG, "✅ All files cleared successfully")
                                promise.resolve(Arguments.createMap().apply {
                                    putBoolean("success", true)
                                    putInt("status", status)
                                    putString("message", "All files cleared successfully")
                                })
                            } else {
                                Log.w(TAG, "❌ Clear files failed, status: $status")
                                promise.reject("CLEAR_FAILED", "Clear files failed, status: $status")
                            }
                        } else {
                            Log.w(TAG, "❌ Clear files failed, no response")
                            promise.reject("CLEAR_FAILED", "Clear files failed, no response")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Clear files error: $errorCode")
                        promise.reject("CLEAR_ERROR", "Clear files error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Clear files error", e)
            promise.reject("CLEAR_ERROR", "Clear files error: ${e.message}", e)
        }
    }

    /**
     * 获取设备电池状态
     */
    @ReactMethod
    fun getBatteryStatus(promise: Promise) {
        try {
            Log.i(TAG, "🔋 Getting battery status...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            bleAgent.getBattStatus(
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "🔋 Battery status request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<BattStatusRsp> {
                    override fun onCallback(response: BattStatusRsp?) {
                        Log.i(TAG, "🔋 Battery status response: $response")
                        if (response != null) {
                            promise.resolve(Arguments.createMap().apply {
                                putBoolean("success", true)
                                putInt("level", response.level)
                                putBoolean("charging", response.isCharging)
                                putString("batteryText", "${response.level}%")
                            })
                        } else {
                            promise.reject("BATTERY_ERROR", "Failed to get battery status")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Battery status error: $errorCode")
                        promise.reject("BATTERY_ERROR", "Battery status error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Get battery status error", e)
            promise.reject("BATTERY_ERROR", "Get battery status error: ${e.message}", e)
        }
    }

    /**
     * 获取设备固件版本
     */
    @ReactMethod
    fun getDeviceVersion(promise: Promise) {
        try {
            // 从缓存的设备信息中获取版本
            val discoveredDevices = PlaudBleCore.getInstance(reactApplicationContext).getDiscoveredDevices()
            if (discoveredDevices.isNotEmpty()) {
                val device = discoveredDevices.values.first()
                val versionName = device.versionName ?: "未知版本"
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("version", versionName)
                    putString("versionName", versionName)
                })
            } else {
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("version", "v1.0.0")
                    putString("versionName", "v1.0.0")
                })
            }

        } catch (e: Exception) {
            Log.e(TAG, "Get device version error", e)
            promise.reject("VERSION_ERROR", "Get device version error: ${e.message}", e)
        }
    }

    /**
     * 下载文件
     */
    @ReactMethod
    fun downloadFile(sessionId: Double, options: ReadableMap?, promise: Promise) {
        try {
            val sessionIdLong = sessionId.toLong()
            Log.i(TAG, "📥 Starting file download for sessionId: $sessionIdLong")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // 创建下载目录
            val downloadDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "PlaudRecordings")
            if (!downloadDir.exists()) {
                downloadDir.mkdirs()
            }
            
            val fileName = "recording_${sessionIdLong}_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.opus"
            val outputFile = File(downloadDir, fileName)
            
            try {
                val outputStream = FileOutputStream(outputFile)
                var totalBytes = 0L
                var lastUpdateTime = 0L
                
                // 创建数据处理回调
                val voiceDataCallback = object : ISyncVoiceDataKeepOut<ByteArray> {
                    override fun receiveVoiceData(data: ByteArray?, start: Long) {
                        data?.let { bytes ->
                            try {
                                outputStream.write(bytes)
                                totalBytes += bytes.size
                                
                                val currentTime = System.currentTimeMillis()
                                if (currentTime - lastUpdateTime >= 500) { // 每0.5秒更新一次进度
                                    sendEvent("onDownloadProgress", Arguments.createMap().apply {
                                        putDouble("sessionId", sessionId)
                                        putDouble("downloadedBytes", totalBytes.toDouble())
                                        putString("fileName", fileName)
                                    })
                                    lastUpdateTime = currentTime
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "写入文件数据出错: ${e.message}")
                            }
                        }
                    }
                    
                    override fun setOriginalDataCallBack(callBack: sdk.penblesdk.viocedata.IVoiceData<ByteArray>?): ISyncVoiceDataKeepOut<ByteArray> {
                        return this
                    }
                    
                    override fun setFinishCallBack(callBack: sdk.penblesdk.viocedata.ICallback.FinishCallback?): ISyncVoiceDataKeepOut<ByteArray> {
                        return this
                    }
                    
                    override fun finish(code: Int) {
                        Log.i(TAG, "文件处理完成，代码: $code")
                    }
                    
                    override fun hasCompleteTail(): Boolean = true
                    
                    override fun flush() {
                        Log.d(TAG, "数据刷新")
                    }
                }
                
                bleAgent.syncFileStart(
                    sessionIdLong,
                    0L,
                    0L,
                    object : AgentCallback.OnRequest {
                        override fun onCallback(success: Boolean) {
                            Log.d(TAG, "📥 File sync request sent: success=$success")
                            if (!success) {
                                try { outputStream.close() } catch (e: Exception) {}
                                outputFile.delete()
                                promise.reject("DOWNLOAD_FAILED", "Failed to start file sync")
                            }
                        }
                    },
                    object : AgentCallback.OnResponse<SyncFileHeadRsp> {
                        override fun onCallback(response: SyncFileHeadRsp?) {
                            Log.d(TAG, "📥 File sync head response: ${response?.status}")
                        }
                    },
                    object : AgentCallback.OnResponse<SyncFileTailRsp> {
                        override fun onCallback(response: SyncFileTailRsp?) {
                            try {
                                outputStream.close()
                                Log.i(TAG, "✅ File download completed: ${outputFile.absolutePath}")
                                
                                promise.resolve(Arguments.createMap().apply {
                                    putBoolean("success", true)
                                    putDouble("sessionId", sessionId)
                                    putString("filePath", outputFile.absolutePath)
                                    putString("fileName", fileName)
                                    putDouble("fileSize", totalBytes.toDouble())
                                    putString("message", "文件下载完成，已保存到Downloads/PlaudRecordings文件夹")
                                })
                                
                                // 发送下载完成事件
                                sendEvent("onDownloadComplete", Arguments.createMap().apply {
                                    putDouble("sessionId", sessionId)
                                    putString("filePath", outputFile.absolutePath)
                                    putString("fileName", fileName)
                                    putDouble("fileSize", totalBytes.toDouble())
                                })
                                
                            } catch (e: Exception) {
                                Log.e(TAG, "下载完成处理出错: ${e.message}")
                                promise.reject("DOWNLOAD_ERROR", "Download completion error: ${e.message}")
                            }
                        }
                    },
                    voiceDataCallback,
                    object : AgentCallback.OnError {
                        override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                            try { 
                                outputStream.close() 
                                outputFile.delete()
                            } catch (e: Exception) {}
                            
                            Log.e(TAG, "❌ File download error: $errorCode")
                            promise.reject("DOWNLOAD_ERROR", "File download error: $errorCode")
                        }
                    }
                )
                
            } catch (e: Exception) {
                Log.e(TAG, "文件输出流创建失败: ${e.message}")
                promise.reject("DOWNLOAD_ERROR", "Failed to create output stream: ${e.message}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Download file error", e)
            promise.reject("DOWNLOAD_ERROR", "Download file error: ${e.message}", e)
        }
    }

    /**
     * 兼容性方法：删除单个文件（目前SDK只支持清理全部文件）
     */
    @ReactMethod
    fun deleteFile(sessionId: Double, promise: Promise) {
        try {
            Log.i(TAG, "🗑️ Delete single file not supported, use clearAllFiles instead")
            
            promise.reject("NOT_SUPPORTED", "Delete single file not supported by SDK, use clearAllFiles instead")

        } catch (e: Exception) {
            Log.e(TAG, "Delete file error", e)
            promise.reject("DELETE_ERROR", "Delete file error: ${e.message}", e)
        }
    }

    /**
     * 格式化场景名称
     */
    private fun getSceneName(scene: Int): String {
        return when (scene) {
            1 -> "会议"
            2 -> "课堂"
            3 -> "访谈"
            4 -> "音乐"
            5 -> "备忘"
            else -> "未知"
        }
    }

    /**
     * 格式化文件大小
     */
    private fun formatFileSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "${bytes}B"
            bytes < 1024 * 1024 -> "${bytes / 1024}KB"
            bytes < 1024 * 1024 * 1024 -> "${"%.1f".format(bytes / (1024.0 * 1024.0))}MB"
            else -> "${"%.1f".format(bytes / (1024.0 * 1024.0 * 1024.0))}GB"
        }
    }

    /**
     * 格式化时长
     */
    private fun formatDuration(milliseconds: Long): String {
        val seconds = milliseconds / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        
        return when {
            hours > 0 -> String.format("%d:%02d:%02d", hours, minutes % 60, seconds % 60)
            else -> String.format("%d:%02d", minutes, seconds % 60)
        }
    }

    /**
     * 格式化时间
     */
    private fun formatTime(timestamp: Long): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }

    /**
     * 添加事件监听器方法
     */
    @ReactMethod
    fun addListener(eventName: String) {
        // React Native需要这个方法来避免警告
    }

    /**
     * 移除事件监听器方法
     */
    @ReactMethod
    fun removeListeners(count: Int) {
        // React Native需要这个方法来避免警告
    }
}

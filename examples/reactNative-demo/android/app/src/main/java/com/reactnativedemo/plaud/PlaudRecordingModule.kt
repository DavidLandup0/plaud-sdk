package com.reactnativedemo.plaud

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import sdk.penblesdk.TntAgent
import sdk.penblesdk.entity.AgentCallback
import sdk.penblesdk.entity.bean.ble.response.RecordStartRsp
import sdk.penblesdk.entity.bean.ble.response.RecordStopRsp

class PlaudRecordingModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val TAG = "PlaudRecordingModule"
    private var isRecording = false
    private var bleCore: PlaudBleCore? = null
    
    companion object {
        private var instance: PlaudRecordingModule? = null
        
        /**
         * 直接同步录音状态（解决模块获取问题）
         */
        fun syncRecordingState(isRecording: Boolean, sessionId: Long?) {
            instance?.let { module ->
                Log.d("PlaudRecordingModule", "🔄 Syncing recording state: isRecording=$isRecording, sessionId=$sessionId")
                module.handleRecordingStateChange(isRecording, sessionId)
            } ?: Log.w("PlaudRecordingModule", "❌ No instance available for state sync")
        }
    }

    override fun getName(): String {
        return "PlaudRecording"
    }

    init {
        // 设置实例引用
        instance = this
        // 不要在这里直接设置监听器，避免与PlaudBluetoothModule冲突
        bleCore = PlaudBleCore.getInstance(reactApplicationContext)
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
     * 开始录音
     */
    @ReactMethod
    fun startRecord(serialNumber: String, token: String, promise: Promise) {
        try {
            Log.i(TAG, "🎙️ Request to start recording - checking local state...")
            Log.d(TAG, "Current local recording state: $isRecording")
            
            // 简单检查本地状态
            if (isRecording) {
                promise.reject("ALREADY_RECORDING", "Already recording")
                return
            }

            // 直接开始录音，依赖录音事件来同步状态
            performStartRecord(promise)

        } catch (e: Exception) {
            Log.e(TAG, "Start record error", e)
            promise.reject("START_RECORD_ERROR", "Start record error: ${e.message}", e)
        }
    }
    
    /**
     * 执行实际的录音开始操作
     */
    private fun performStartRecord(promise: Promise) {
        try {
            Log.i(TAG, "🎙️ Performing start recording...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // 使用场景1（会议）作为默认场景
            val scene = 1
            
            bleAgent.startRecord(
                scene,
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "🎙️ Start record request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<RecordStartRsp> {
                    override fun onCallback(response: RecordStartRsp?) {
                        Log.i(TAG, "🎙️ Start record response: $response")
                        if (response != null) {
                            val status = response.status
                            val sessionId = response.sessionId
                            
                            if (status == 0 || status == 4) {
                                // 录音成功开始
                                isRecording = true
                                Log.i(TAG, "✅ Recording started successfully, sessionId: $sessionId")
                                
                                promise.resolve(Arguments.createMap().apply {
                                    putBoolean("success", true)
                                    putLong("sessionId", sessionId)
                                    putInt("status", status)
                                    putString("message", "Recording started successfully")
                                })
                                
                                // 发送录音开始事件（应用主动发起）
                                sendEvent("onRecordingStarted", Arguments.createMap().apply {
                                    putString("sessionId", sessionId.toString())
                                    putLong("timestamp", System.currentTimeMillis())
                                    putString("source", "app") // 标识来源是应用
                                })
                            } else {
                                Log.w(TAG, "❌ Recording start failed, status: $status")
                                promise.reject("START_FAILED", "Recording start failed, status: $status")
                            }
                        } else {
                            Log.w(TAG, "❌ Recording start failed, no response")
                            promise.reject("START_FAILED", "Recording start failed, no response")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Recording start error: $errorCode")
                        promise.reject("START_ERROR", "Recording start error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Start recording error", e)
            promise.reject("START_ERROR", "Start recording error: ${e.message}", e)
        }
    }

    /**
     * 停止录音
     */
    @ReactMethod
    fun stopRecord(serialNumber: String, promise: Promise) {
        try {
            Log.i(TAG, "🛑 Request to stop recording - checking local state...")
            Log.d(TAG, "Current local recording state: $isRecording")
            
            // 简单检查本地状态
            if (!isRecording) {
                promise.reject("NOT_RECORDING", "Not currently recording")
                return
            }

            // 直接停止录音，依赖录音事件来同步状态
            performStopRecord(promise)

        } catch (e: Exception) {
            Log.e(TAG, "Stop record error", e)
            promise.reject("STOP_RECORD_ERROR", "Stop record error: ${e.message}", e)
        }
    }
    
    /**
     * 执行实际的录音停止操作
     */
    private fun performStopRecord(promise: Promise) {
        try {
            Log.i(TAG, "🛑 Performing stop recording...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // 使用场景1（会议）
            val scene = 1
            
            bleAgent.stopRecord(
                scene,
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "🛑 Stop record request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<RecordStopRsp> {
                    override fun onCallback(response: RecordStopRsp?) {
                        Log.i(TAG, "🛑 Stop record response: $response")
                        if (response != null) {
                            val reason = response.reason
                            val sessionId = response.sessionId
                            val fileExist = response.isFileExist
                            val fileSize = response.fileSize
                            
                            // 只要收到RecordStopRsp就认为录音成功停止（参考原生demo处理方式）
                            isRecording = false
                            Log.i(TAG, "✅ Recording stopped successfully, sessionId: $sessionId, reason: $reason, fileExist: $fileExist, fileSize: $fileSize")
                            
                            promise.resolve(Arguments.createMap().apply {
                                putBoolean("success", true)
                                putLong("sessionId", sessionId)
                                putInt("reason", reason)
                                putBoolean("fileExist", fileExist)
                                putLong("fileSize", fileSize)
                                putString("message", "Recording stopped successfully")
                            })
                            
                            // 发送录音结束事件（应用主动发起）
                            sendEvent("onRecordingStopped", Arguments.createMap().apply {
                                putString("sessionId", sessionId.toString())
                                putLong("timestamp", System.currentTimeMillis())
                                putString("source", "app") // 标识来源是应用
                                putBoolean("fileExist", fileExist)
                                putLong("fileSize", fileSize)
                            })
                        } else {
                            Log.w(TAG, "❌ Recording stop failed, no response")
                            promise.reject("STOP_FAILED", "Recording stop failed, no response")
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "❌ Recording stop error: $errorCode")
                        promise.reject("STOP_ERROR", "Recording stop error: $errorCode")
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Perform stop record error", e)
            promise.reject("STOP_ERROR", "Perform stop record error: ${e.message}", e)
        }
    }

    /**
     * 智能录音切换 - 根据设备当前状态自动判断开始或停止录音
     */
    @ReactMethod
    fun toggleRecording(deviceId: String, options: ReadableMap?, promise: Promise) {
        try {
            Log.i(TAG, "🎙️ Toggle recording request - checking device state...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // 获取设备当前状态
            bleAgent.getState(
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "Toggle: Device state request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<sdk.penblesdk.entity.bean.ble.response.GetStateRsp> {
                    override fun onCallback(response: sdk.penblesdk.entity.bean.ble.response.GetStateRsp?) {
                        if (response != null) {
                            val deviceRecording = response.keyStateCode == 4L // 4表示正在录音
                            Log.i(TAG, "🎯 Device state: ${if (deviceRecording) "RECORDING" else "IDLE"} (keyState: ${response.keyStateCode})")
                            
                            // 同步本地状态
                            isRecording = deviceRecording
                            
                            if (deviceRecording) {
                                // 设备正在录音 → 执行停止录音
                                Log.i(TAG, "🛑 Device is recording, will STOP recording")
                                performStopRecord(promise)
                            } else {
                                // 设备空闲 → 执行开始录音
                                Log.i(TAG, "▶️ Device is idle, will START recording")
                                performStartRecord(promise)
                            }
                        } else {
                            Log.w(TAG, "Failed to get device state for toggle, fallback to local state")
                            if (isRecording) {
                                performStopRecord(promise)
                            } else {
                                performStartRecord(promise)
                            }
                        }
                    }
                },
                object : AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.w(TAG, "Failed to get device state for toggle (error: $errorCode), fallback to local state")
                        if (isRecording) {
                            performStopRecord(promise)
                        } else {
                            performStartRecord(promise)
                        }
                    }
                }
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Toggle recording error", e)
            promise.reject("TOGGLE_ERROR", "Toggle recording error: ${e.message}", e)
        }
    }

    /**
     * 开始录音的便捷方法（兼容性）
     */
    @ReactMethod
    fun startRecording(deviceId: String, options: ReadableMap?, promise: Promise) {
        startRecord(deviceId, "", promise)
    }

    /**
     * 停止录音的便捷方法（兼容性）
     */
    @ReactMethod
    fun stopRecording(promise: Promise) {
        stopRecord("", promise)
    }

    /**
     * 获取录音状态
     */
    @ReactMethod
    fun getRecordingStatus(promise: Promise) {
        try {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("isRecording", isRecording)
            })
        } catch (e: Exception) {
            promise.reject("GET_STATUS_ERROR", "Get recording status error: ${e.message}", e)
        }
    }

    /**
     * 开始实时录音同步（JS端兼容方法）
     */
    @ReactMethod
    fun startRealTimeSync(sessionId: Int, options: ReadableMap?, promise: Promise) {
        try {
            Log.d(TAG, "Starting real-time sync for session: $sessionId")
            
            // 直接调用真实的录音开始方法
            startRecord("", "", promise)

        } catch (e: Exception) {
            Log.e(TAG, "Start real-time sync error", e)
            promise.reject("SYNC_ERROR", "Start real-time sync error: ${e.message}", e)
        }
    }

    /**
     * 停止实时录音同步（JS端兼容方法）
     */
    @ReactMethod
    fun stopRealTimeSync(promise: Promise) {
        try {
            Log.d(TAG, "Stopping real-time sync")
            
            // 直接调用真实的录音停止方法
            stopRecord("", promise)

        } catch (e: Exception) {
            Log.e(TAG, "Stop real-time sync error", e)
            promise.reject("SYNC_ERROR", "Stop real-time sync error: ${e.message}", e)
        }
    }

    /**
     * 处理来自PlaudBluetoothModule转发的录音事件
     * 用于同步录音状态
     */
    fun handleRecordingStateChange(isRecording: Boolean, sessionId: Long?) {
        Log.d(TAG, "📱 Received recording state change from device: isRecording=$isRecording, sessionId=$sessionId")
        
        // 同步本地状态
        this.isRecording = isRecording
        
        if (isRecording) {
            // 设备开始录音
            sendEvent("onRecordingStarted", Arguments.createMap().apply {
                putString("sessionId", sessionId?.toString())
                putLong("timestamp", System.currentTimeMillis())
                putString("source", "device") // 标识来源是设备按键
            })
            Log.d(TAG, "✅ Device started recording - state synced")
        } else {
            // 设备结束录音
            sendEvent("onRecordingStopped", Arguments.createMap().apply {
                putString("sessionId", sessionId?.toString())
                putLong("timestamp", System.currentTimeMillis())
                putString("source", "device") // 标识来源是设备按键
            })
            Log.d(TAG, "✅ Device stopped recording - state synced")
        }
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

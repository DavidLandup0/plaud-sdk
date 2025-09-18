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
         * Directly sync recording state (solve module acquisition issues)
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
        // Set instance reference
        instance = this
        // Don't set listeners here directly to avoid conflicts with PlaudBluetoothModule
        bleCore = PlaudBleCore.getInstance(reactApplicationContext)
    }


    /**
     * Send event to React Native
     */
    private fun sendEvent(eventName: String, params: WritableMap?) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }

    /**
     * Start recording
     */
    @ReactMethod
    fun startRecord(serialNumber: String, token: String, promise: Promise) {
        try {
            Log.i(TAG, "🎙️ Request to start recording - checking local state...")
            Log.d(TAG, "Current local recording state: $isRecording")
            
            // Simple check of local state
            if (isRecording) {
                promise.reject("ALREADY_RECORDING", "Already recording")
                return
            }

            // Start recording directly, rely on recording events to sync state
            performStartRecord(promise)

        } catch (e: Exception) {
            Log.e(TAG, "Start record error", e)
            promise.reject("START_RECORD_ERROR", "Start record error: ${e.message}", e)
        }
    }
    
    /**
     * Execute actual recording start operation
     */
    private fun performStartRecord(promise: Promise) {
        try {
            Log.i(TAG, "🎙️ Performing start recording...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // Use scenario 1 (meeting) as default scenario
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
                                // Recording started successfully
                                isRecording = true
                                Log.i(TAG, "✅ Recording started successfully, sessionId: $sessionId")
                                
                                promise.resolve(Arguments.createMap().apply {
                                    putBoolean("success", true)
                                    putLong("sessionId", sessionId)
                                    putInt("status", status)
                                    putString("message", "Recording started successfully")
                                })
                                
                                // Send recording start event (initiated by app)
                                sendEvent("onRecordingStarted", Arguments.createMap().apply {
                                    putString("sessionId", sessionId.toString())
                                    putLong("timestamp", System.currentTimeMillis())
                                    putString("source", "app") // Identify source as app
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
     * Stop recording
     */
    @ReactMethod
    fun stopRecord(serialNumber: String, promise: Promise) {
        try {
            Log.i(TAG, "🛑 Request to stop recording - checking local state...")
            Log.d(TAG, "Current local recording state: $isRecording")
            
            // Simple check of local state
            if (!isRecording) {
                promise.reject("NOT_RECORDING", "Not currently recording")
                return
            }

            // Stop recording directly, rely on recording events to sync state
            performStopRecord(promise)

        } catch (e: Exception) {
            Log.e(TAG, "Stop record error", e)
            promise.reject("STOP_RECORD_ERROR", "Stop record error: ${e.message}", e)
        }
    }
    
    /**
     * Execute actual recording stop operation
     */
    private fun performStopRecord(promise: Promise) {
        try {
            Log.i(TAG, "🛑 Performing stop recording...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // Use scenario 1 (meeting)
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
                            
                            // Consider recording successfully stopped when RecordStopRsp is received (refer to native demo)
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
                            
                            // Send recording end event (initiated by app)
                            sendEvent("onRecordingStopped", Arguments.createMap().apply {
                                putString("sessionId", sessionId.toString())
                                putLong("timestamp", System.currentTimeMillis())
                                putString("source", "app") // Identify source as app
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
     * Smart recording toggle - automatically decide to start or stop recording based on current device state
     */
    @ReactMethod
    fun toggleRecording(deviceId: String, options: ReadableMap?, promise: Promise) {
        try {
            Log.i(TAG, "🎙️ Toggle recording request - checking device state...")
            
            val bleAgent = TntAgent.getInstant().bleAgent
            
            // Get current device state
            bleAgent.getState(
                object : AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "Toggle: Device state request sent: success=$success")
                    }
                },
                object : AgentCallback.OnResponse<sdk.penblesdk.entity.bean.ble.response.GetStateRsp> {
                    override fun onCallback(response: sdk.penblesdk.entity.bean.ble.response.GetStateRsp?) {
                        if (response != null) {
                            val deviceRecording = response.keyStateCode == 4L // 4 indicates recording
                            Log.i(TAG, "🎯 Device state: ${if (deviceRecording) "RECORDING" else "IDLE"} (keyState: ${response.keyStateCode})")
                            
                            // Sync local state
                            isRecording = deviceRecording
                            
                            if (deviceRecording) {
                                // Device is recording → execute stop recording
                                Log.i(TAG, "🛑 Device is recording, will STOP recording")
                                performStopRecord(promise)
                            } else {
                                // Device is idle → execute start recording
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
     * Convenient method for start recording (compatibility)
     */
    @ReactMethod
    fun startRecording(deviceId: String, options: ReadableMap?, promise: Promise) {
        startRecord(deviceId, "", promise)
    }

    /**
     * Convenient method for stop recording (compatibility)
     */
    @ReactMethod
    fun stopRecording(promise: Promise) {
        stopRecord("", promise)
    }

    /**
     * Get recording status
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
     * Start real-time recording sync (JS compatibility method)
     */
    @ReactMethod
    fun startRealTimeSync(sessionId: Int, options: ReadableMap?, promise: Promise) {
        try {
            Log.d(TAG, "Starting real-time sync for session: $sessionId")
            
            // Directly call the real recording start method
            startRecord("", "", promise)

        } catch (e: Exception) {
            Log.e(TAG, "Start real-time sync error", e)
            promise.reject("SYNC_ERROR", "Start real-time sync error: ${e.message}", e)
        }
    }

    /**
     * Stop real-time recording sync (JS compatibility method)
     */
    @ReactMethod
    fun stopRealTimeSync(promise: Promise) {
        try {
            Log.d(TAG, "Stopping real-time sync")
            
            // Directly call the real recording stop method
            stopRecord("", promise)

        } catch (e: Exception) {
            Log.e(TAG, "Stop real-time sync error", e)
            promise.reject("SYNC_ERROR", "Stop real-time sync error: ${e.message}", e)
        }
    }

    /**
     * Handle recording events forwarded from PlaudBluetoothModule
     * Used to sync recording state
     */
    fun handleRecordingStateChange(isRecording: Boolean, sessionId: Long?) {
        Log.d(TAG, "📱 Received recording state change from device: isRecording=$isRecording, sessionId=$sessionId")
        
        // Sync local state
        this.isRecording = isRecording
        
        if (isRecording) {
            // Device starts recording
            sendEvent("onRecordingStarted", Arguments.createMap().apply {
                putString("sessionId", sessionId?.toString())
                putLong("timestamp", System.currentTimeMillis())
                putString("source", "device") // Identify source as device button
            })
            Log.d(TAG, "✅ Device started recording - state synced")
        } else {
            // Device ends recording
            sendEvent("onRecordingStopped", Arguments.createMap().apply {
                putString("sessionId", sessionId?.toString())
                putLong("timestamp", System.currentTimeMillis())
                putString("source", "device") // Identify source as device button
            })
            Log.d(TAG, "✅ Device stopped recording - state synced")
        }
    }

    /**
     * Add event listener method
     */
    @ReactMethod
    fun addListener(eventName: String) {
        // React Native needs this method to avoid warnings
    }

    /**
     * Remove event listener method
     */
    @ReactMethod
    fun removeListeners(count: Int) {
        // React Native needs this method to avoid warnings
    }
}

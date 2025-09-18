package com.reactnativedemo.plaud

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import sdk.penblesdk.entity.BleDevice

class PlaudBluetoothModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val TAG = "PlaudBluetoothModule"
    private var bleCore: PlaudBleCore? = null

    override fun getName(): String {
        return "PlaudBluetooth"
    }

    init {
        bleCore = PlaudBleCore.getInstance(reactApplicationContext)
        setupEventListeners()
    }

    private fun setupEventListeners() {
        bleCore?.let { core ->
            core.onScanResult = { device ->
                sendEvent("onDeviceFound", createDeviceMap(device))
            }
            
            // Use connection listener instead of overriding onConnectionStateChange
            core.addConnectionListener { isConnected, deviceId ->
                Log.w(TAG, "🚨 PlaudBluetoothModule connection event: isConnected=$isConnected, deviceId='$deviceId'")
                Log.w(TAG, "🔍 Stack trace for debugging: ${Thread.currentThread().stackTrace.take(5).joinToString { it.toString() }}")
                if (isConnected) {
                    Log.d(TAG, "📤 Sending onDeviceConnected event to React Native")
                    // Get connected device information
                    val connectedDevice = core.getDiscoveredDevices().values.firstOrNull { it.serialNumber == deviceId }
                        ?: core.getDiscoveredDevices().values.firstOrNull()
                    
                    sendEvent("onDeviceConnected", Arguments.createMap().apply {
                        putBoolean("success", true)
                        putString("deviceId", deviceId ?: "")
                        putString("message", "Device connected successfully")
                        
                        // Add device information
                        if (connectedDevice != null) {
                            val deviceMap = Arguments.createMap().apply {
                                putString("name", connectedDevice.name)
                                putString("serialNumber", connectedDevice.serialNumber)
                                putString("macAddress", connectedDevice.macAddress)
                                putInt("rssi", connectedDevice.rssi)
                                // Add firmware version info
                                putString("wholeVersion", connectedDevice.versionName ?: "")
                                putInt("versionCode", connectedDevice.versionCode)
                            }
                            putMap("device", deviceMap)
                            Log.d(TAG, "📱 Device info added to event: ${connectedDevice.name}, version: ${connectedDevice.versionName}")
                        }
                    })
                    Log.d(TAG, "✅ onDeviceConnected event sent")
                    
                    // After successful connection, delay fetching device status and manually trigger info updates
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        Log.d(TAG, "📱 Auto-requesting device status after connection...")
                        core.getDeviceStatus()
                        
                        // Also get real device information
                        Log.d(TAG, "🧪 Getting real device info...")
                        core.triggerBatteryInfo() // Battery info keeps fake data for now (until correct API is found)
                        core.getRealStorageInfo() // Use real storage info API
                    }, 3000L) // Get device status after 3 seconds
                } else {
                    Log.w(TAG, "⚠️ DISCONNECT EVENT TRIGGERED - This will cause popup!")
                    Log.w(TAG, "📤 Sending onDeviceDisconnected event to React Native")
                    Log.w(TAG, "🔍 Disconnect stack trace: ${Thread.currentThread().stackTrace.take(5).joinToString { it.toString() }}")
                    sendEvent("onDeviceDisconnected", Arguments.createMap().apply {
                        putBoolean("success", false)
                        putString("deviceId", deviceId ?: "")
                        putString("message", "Device disconnected")
                    })
                    Log.w(TAG, "❌ onDeviceDisconnected event sent - POPUP SHOULD APPEAR NOW!")
                }
            }
            
            // Recording status monitoring
            core.onRecordingStateChange = { isRecording, sessionId ->
                Log.d(TAG, "🎙️ Recording state changed: isRecording=$isRecording, sessionId=$sessionId")
                
                if (isRecording) {
                    sendEvent("onRecordingStarted", Arguments.createMap().apply {
                        putString("sessionId", sessionId?.toString())
                        putLong("timestamp", System.currentTimeMillis())
                        putString("source", "device")
                    })
                } else {
                    sendEvent("onRecordingStopped", Arguments.createMap().apply {
                        putString("sessionId", sessionId?.toString())
                        putLong("timestamp", System.currentTimeMillis())
                        putString("source", "device")
                    })
                }
                
                // Directly get PlaudRecordingModule status sync through singleton
                try {
                    Log.d(TAG, "🔄 Directly syncing recording state to PlaudRecordingModule")
                    // Directly call PlaudRecordingModule static method for status sync
                    PlaudRecordingModule.syncRecordingState(isRecording, sessionId)
                    Log.d(TAG, "✅ Recording state synced directly")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to sync recording state directly", e)
                }
            }
            
            // Battery information monitoring
            core.onBatteryInfoUpdated = { deviceId, level ->
                Log.d(TAG, "🔋 Battery info updated: device=$deviceId, level=$level%")
                sendEvent("onBatteryInfoUpdated", Arguments.createMap().apply {
                    putString("deviceId", deviceId ?: "")
                    putInt("batteryLevel", level) // Use field name expected by frontend
                    putString("batteryText", "${level}%") // Provide text format
                    putBoolean("isCharging", false) // Temporarily set to false, update when charging status is obtained
                    putLong("timestamp", System.currentTimeMillis())
                })
            }
            
            // Storage information monitoring
            core.onStorageInfoUpdated = { deviceId, storageInfo ->
                Log.d(TAG, "💾 Storage info updated: device=$deviceId, info=$storageInfo")
                
                val freeMB = storageInfo["freeMB"] as? Long ?: 0L
                val totalMB = storageInfo["totalMB"] as? Long ?: 0L
                val usedMB = storageInfo["usedMB"] as? Long ?: 0L
                val usedPercent = storageInfo["usedPercent"] as? Int ?: 0
                
                sendEvent("onStorageInfoUpdated", Arguments.createMap().apply {
                    putString("deviceId", deviceId ?: "")
                    // Use field names and format expected by frontend
                    putString("freeSpaceText", "${freeMB}MB")
                    putString("totalSpaceText", "${totalMB}MB") 
                    putString("usedSpaceText", "${usedMB}MB")
                    putString("usagePercent", "$usedPercent") // String format
                    // Keep original numeric fields as backup
                    putLong("freeMB", freeMB)
                    putLong("totalMB", totalMB)
                    putLong("usedMB", usedMB)
                    putInt("usedPercent", usedPercent)
                    putLong("timestamp", System.currentTimeMillis())
                })
            }
        }
    }
    
    private fun createDeviceMap(device: BleDevice): WritableMap {
        return Arguments.createMap().apply {
            putString("name", device.name)
            putString("address", device.macAddress)
            putInt("rssi", device.rssi)
            putString("serialNumber", device.serialNumber)
            putString("id", if (device.serialNumber.isNotEmpty()) device.serialNumber else device.macAddress)
            // Add firmware version information
            putString("wholeVersion", device.versionName ?: "")
            putInt("versionCode", device.versionCode)
        }
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
     * Start scanning devices
     */
    @ReactMethod
    fun startScan(options: ReadableMap?, promise: Promise) {
        try {
            val bleCore = this.bleCore
            if (bleCore == null) {
                promise.reject("NOT_INITIALIZED", "SDK not initialized")
                return
            }

            Log.d(TAG, "Starting device scan")
            
            val success = bleCore.startScan()
            
            if (success) {
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("message", "Scan started successfully")
                })
            } else {
                promise.reject("SCAN_ERROR", "Failed to start scan")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Start scan error", e)
            promise.reject("SCAN_ERROR", "Start scan error: ${e.message}", e)
        }
    }

    /**
     * Stop scanning
     */
    @ReactMethod
    fun stopScan(promise: Promise) {
        try {
            val bleCore = this.bleCore
            if (bleCore == null) {
                promise.reject("NOT_INITIALIZED", "SDK not initialized")
                return
            }

            val success = bleCore.stopScan()
            
            if (success) {
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("message", "Scan stopped successfully")
                })
            } else {
                promise.reject("SCAN_ERROR", "Failed to stop scan")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Stop scan error", e)
            promise.reject("SCAN_ERROR", "Stop scan error: ${e.message}", e)
        }
    }

    /**
     * Connect to specified device
     */
    @ReactMethod
    fun connect(serialNumber: String, token: String, options: ReadableMap?, promise: Promise) {
        try {
            val bleCore = this.bleCore
            if (bleCore == null) {
                promise.reject("NOT_INITIALIZED", "SDK not initialized")
                return
            }

            if (bleCore.isDeviceConnected()) {
                promise.reject("ALREADY_CONNECTED", "Already connected to a device")
                return
            }

            Log.d(TAG, "Connecting to device: $serialNumber")

            bleCore.connectDevice(serialNumber, token) { success, error ->
                if (success) {
                    promise.resolve(Arguments.createMap().apply {
                        putBoolean("success", true)
                        putString("serialNumber", serialNumber)
                    })
                } else {
                    promise.reject("CONNECT_FAILED", error ?: "Connection failed")
                }
            }

        } catch (e: Exception) {
            promise.reject("CONNECT_ERROR", "Connect error: ${e.message}", e)
        }
    }

    /**
     * Disconnect device connection
     */
    @ReactMethod
    fun disconnect(promise: Promise) {
        try {
            val bleCore = this.bleCore
            if (bleCore == null) {
                promise.reject("NOT_INITIALIZED", "SDK not initialized")
                return
            }

            if (!bleCore.isDeviceConnected()) {
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("message", "Not currently connected")
                })
                return
            }

            bleCore.disconnectDevice { success, error ->
                if (success) {
                    promise.resolve(Arguments.createMap().apply {
                        putBoolean("success", true)
                        putString("message", "Disconnected successfully")
                    })
                } else {
                    promise.reject("DISCONNECT_FAILED", error ?: "Disconnect failed")
                }
            }

        } catch (e: Exception) {
            promise.reject("DISCONNECT_ERROR", "Disconnect error: ${e.message}", e)
        }
    }

    /**
     * Get device status
     */
    @ReactMethod
    fun getDeviceState(promise: Promise) {
        try {
            val bleCore = this.bleCore
            if (bleCore == null) {
                promise.reject("NOT_INITIALIZED", "SDK not initialized")
                return
            }

            val isConnected = bleCore.isDeviceConnected()
            
            promise.resolve(Arguments.createMap().apply {
                putBoolean("isConnected", isConnected)
            })

        } catch (e: Exception) {
            Log.e(TAG, "Get device state error", e)
            promise.reject("GET_STATE_ERROR", "Get device state error: ${e.message}", e)
        }
    }

    /**
     * Check if connected
     */
    @ReactMethod
    fun isConnected(promise: Promise) {
        try {
            val bleCore = this.bleCore
            if (bleCore == null) {
                promise.resolve(false)
                return
            }

            val isConnected = bleCore.isDeviceConnected()
            promise.resolve(isConnected)

        } catch (e: Exception) {
            Log.e(TAG, "Check connection error", e)
            promise.reject("CHECK_CONNECTION_ERROR", "Check connection error: ${e.message}", e)
        }
    }

    /**
     * Get Bluetooth manager status (for debugging)
     */
    @ReactMethod
    fun getBluetoothManagerStatus(promise: Promise) {
        try {
            val bleCore = this.bleCore
            
            promise.resolve(Arguments.createMap().apply {
                putBoolean("isInitialized", bleCore != null)
                if (bleCore != null) {
                    putBoolean("isConnected", bleCore.isDeviceConnected())
                    putString("status", "Available")
                } else {
                    putString("status", "Not initialized")
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Get bluetooth manager status error", e)
            promise.reject("GET_STATUS_ERROR", "Get bluetooth manager status error: ${e.message}", e)
        }
    }

    /**
     * Convenient method for connect device (only need device ID)
     */
    @ReactMethod
    fun connectDevice(deviceId: String, promise: Promise) {
        connect(deviceId, deviceId, null, promise)
    }

    /**
     * Convenient method for disconnect device
     */
    @ReactMethod
    fun disconnectDevice(promise: Promise) {
        disconnect(promise)
    }

    /**
     * Add event listener method (called by React Native)
     */
    @ReactMethod
    fun addListener(eventName: String) {
        // React Native needs this method to avoid warnings
    }

    /**
     * Remove event listener method (called by React Native)
     */
    @ReactMethod
    fun removeListeners(count: Int) {
        // React Native needs this method to avoid warnings
    }
}
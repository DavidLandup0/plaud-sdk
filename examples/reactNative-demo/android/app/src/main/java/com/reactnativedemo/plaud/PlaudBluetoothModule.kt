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
            
            // 使用连接监听器而不是覆盖onConnectionStateChange
            core.addConnectionListener { isConnected, deviceId ->
                Log.w(TAG, "🚨 PlaudBluetoothModule connection event: isConnected=$isConnected, deviceId='$deviceId'")
                Log.w(TAG, "🔍 Stack trace for debugging: ${Thread.currentThread().stackTrace.take(5).joinToString { it.toString() }}")
                if (isConnected) {
                    Log.d(TAG, "📤 Sending onDeviceConnected event to React Native")
                    // 获取连接的设备信息
                    val connectedDevice = core.getDiscoveredDevices().values.firstOrNull { it.serialNumber == deviceId }
                        ?: core.getDiscoveredDevices().values.firstOrNull()
                    
                    sendEvent("onDeviceConnected", Arguments.createMap().apply {
                        putBoolean("success", true)
                        putString("deviceId", deviceId ?: "")
                        putString("message", "Device connected successfully")
                        
                        // 添加设备信息
                        if (connectedDevice != null) {
                            val deviceMap = Arguments.createMap().apply {
                                putString("name", connectedDevice.name)
                                putString("serialNumber", connectedDevice.serialNumber)
                                putString("macAddress", connectedDevice.macAddress)
                                putInt("rssi", connectedDevice.rssi)
                                // 添加固件版本信息
                                putString("wholeVersion", connectedDevice.versionName ?: "")
                                putInt("versionCode", connectedDevice.versionCode)
                            }
                            putMap("device", deviceMap)
                            Log.d(TAG, "📱 Device info added to event: ${connectedDevice.name}, version: ${connectedDevice.versionName}")
                        }
                    })
                    Log.d(TAG, "✅ onDeviceConnected event sent")
                    
                    // 连接成功后，延时获取设备状态信息和手动触发信息更新
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        Log.d(TAG, "📱 Auto-requesting device status after connection...")
                        core.getDeviceStatus()
                        
                        // 同时获取真实的设备信息
                        Log.d(TAG, "🧪 Getting real device info...")
                        core.triggerBatteryInfo() // 电池信息先保留假数据（等找到正确的API）
                        core.getRealStorageInfo() // 使用真实的存储信息API
                    }, 3000L) // 3秒后获取设备状态
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
            
            // 录音状态监听
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
                
                // 直接通过单例获取 PlaudRecordingModule 的状态同步
                try {
                    Log.d(TAG, "🔄 Directly syncing recording state to PlaudRecordingModule")
                    // 直接调用 PlaudRecordingModule 的静态方法进行状态同步
                    PlaudRecordingModule.syncRecordingState(isRecording, sessionId)
                    Log.d(TAG, "✅ Recording state synced directly")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to sync recording state directly", e)
                }
            }
            
            // 电池信息监听
            core.onBatteryInfoUpdated = { deviceId, level ->
                Log.d(TAG, "🔋 Battery info updated: device=$deviceId, level=$level%")
                sendEvent("onBatteryInfoUpdated", Arguments.createMap().apply {
                    putString("deviceId", deviceId ?: "")
                    putInt("batteryLevel", level) // 使用前端期望的字段名
                    putString("batteryText", "${level}%") // 提供文本格式
                    putBoolean("isCharging", false) // 临时设为false，等获取到充电状态后更新
                    putLong("timestamp", System.currentTimeMillis())
                })
            }
            
            // 存储信息监听
            core.onStorageInfoUpdated = { deviceId, storageInfo ->
                Log.d(TAG, "💾 Storage info updated: device=$deviceId, info=$storageInfo")
                
                val freeMB = storageInfo["freeMB"] as? Long ?: 0L
                val totalMB = storageInfo["totalMB"] as? Long ?: 0L
                val usedMB = storageInfo["usedMB"] as? Long ?: 0L
                val usedPercent = storageInfo["usedPercent"] as? Int ?: 0
                
                sendEvent("onStorageInfoUpdated", Arguments.createMap().apply {
                    putString("deviceId", deviceId ?: "")
                    // 使用前端期望的字段名和格式
                    putString("freeSpaceText", "${freeMB}MB")
                    putString("totalSpaceText", "${totalMB}MB") 
                    putString("usedSpaceText", "${usedMB}MB")
                    putString("usagePercent", "$usedPercent") // 字符串格式
                    // 保留原始数值字段作为备用
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
            // 添加固件版本信息
            putString("wholeVersion", device.versionName ?: "")
            putInt("versionCode", device.versionCode)
        }
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
     * 开始扫描设备
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
     * 停止扫描
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
     * 连接到指定设备
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
     * 断开设备连接
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
     * 获取设备状态
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
     * 检查是否已连接
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
     * 获取蓝牙管理器状态（用于调试）
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
     * Connect device的便捷方法（只需要设备ID）
     */
    @ReactMethod
    fun connectDevice(deviceId: String, promise: Promise) {
        connect(deviceId, deviceId, null, promise)
    }

    /**
     * Disconnect device的便捷方法
     */
    @ReactMethod
    fun disconnectDevice(promise: Promise) {
        disconnect(promise)
    }

    /**
     * 添加事件监听器方法（React Native端会调用）
     */
    @ReactMethod
    fun addListener(eventName: String) {
        // React Native需要这个方法来避免警告
    }

    /**
     * 移除事件监听器方法（React Native端会调用）
     */
    @ReactMethod
    fun removeListeners(count: Int) {
        // React Native需要这个方法来避免警告
    }
}
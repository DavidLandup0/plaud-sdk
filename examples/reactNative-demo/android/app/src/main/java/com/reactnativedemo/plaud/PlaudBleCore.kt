package com.reactnativedemo.plaud

import android.content.Context
import android.util.Log
import sdk.NiceBuildSdk
import sdk.penblesdk.entity.BleDevice
import sdk.penblesdk.entity.BluetoothStatus
import sdk.penblesdk.impl.ble.BleAgentListener
import sdk.penblesdk.TntAgent

/**
 * Simplified BLE core manager designed specifically for React Native bridging
 */
class PlaudBleCore private constructor(private val context: Context) {
    private val TAG = "PlaudBleCore"
    
    // Callback functions
    var onScanResult: ((BleDevice) -> Unit)? = null
    var onConnectionStateChange: ((Boolean, String?) -> Unit)? = null
    var onRecordingStateChange: ((Boolean, Long?) -> Unit)? = null
    var onBatteryInfoUpdated: ((String?, Int) -> Unit)? = null
    var onStorageInfoUpdated: ((String?, Map<String, Any>) -> Unit)? = null
    
    // Connection listeners list, supporting multiple listeners
    private val connectionListeners = mutableListOf<(Boolean, String?) -> Unit>()
    
    private var isInitialized = false
    
    // Cache scanned device information for retrieving complete device info during connection
    private val discoveredDevices = mutableMapOf<String, BleDevice>()
    
    /**
     * Get discovered devices list (for other modules to access device information)
     */
    fun getDiscoveredDevices(): Map<String, BleDevice> = discoveredDevices.toMap()
    
    /**
     * Add connection state listener
     */
    fun addConnectionListener(listener: (Boolean, String?) -> Unit) {
        synchronized(connectionListeners) {
            connectionListeners.add(listener)
            Log.d(TAG, "Added connection listener, total: ${connectionListeners.size}")
        }
    }
    
    /**
     * 移除连接状态监听器
     */
    fun removeConnectionListener(listener: (Boolean, String?) -> Unit) {
        synchronized(connectionListeners) {
            connectionListeners.remove(listener)
            Log.d(TAG, "Removed connection listener, total: ${connectionListeners.size}")
        }
    }
    
    /**
     * 通知所有连接监听器
     */
    private fun notifyConnectionListeners(isConnected: Boolean, deviceId: String?) {
        synchronized(connectionListeners) {
            Log.d(TAG, "🔔 Notifying ${connectionListeners.size} connection listeners: isConnected=$isConnected, deviceId='$deviceId'")
            connectionListeners.forEach { listener ->
                try {
                    listener.invoke(isConnected, deviceId)
                } catch (e: Exception) {
                    Log.e(TAG, "Error notifying connection listener", e)
                }
            }
        }
    }
    
    companion object {
        @Volatile
        private var instance: PlaudBleCore? = null
        
        fun getInstance(context: Context): PlaudBleCore {
            return instance ?: synchronized(this) {
                instance ?: PlaudBleCore(context.applicationContext).also { instance = it }
            }
        }
    }
    
    /**
     * 初始化SDK
     */
    fun initSdk(appKey: String? = null, appSecret: String? = null, environment: String? = null, forceReinit: Boolean = false): Boolean {
        return try {
            if (isInitialized && !forceReinit) {
                Log.d(TAG, "SDK already initialized")
                return true
            }
            
            if (forceReinit) {
                Log.i(TAG, "Force re-initializing SDK...")
                try {
                    // Clean up old SDK instance first
                    NiceBuildSdk.logout()
                    Log.d(TAG, "SDK logout completed")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to logout from old SDK: ${e.message}")
                }
                isInitialized = false // Reset state for re-initialization
            }
            
            // 如果提供了参数，则使用参数；否则从配置获取
            val envConfig = if (appKey != null && appSecret != null && environment != null) {
                // 使用传入的参数构造临时配置
                val envDisplayName = when (environment) {
                    "US_PROD" -> "US Production Environment"
                    "US_TEST" -> "US Test Environment" 
                    "COMMON_TEST" -> "Common Test Environment"
                    "CHINA_PROD" -> "China Production Environment"
                    else -> environment
                }
                PlaudEnvironmentConfig.EnvConfig(
                    name = environment,
                    displayName = envDisplayName,
                    baseUrl = "", // baseUrl不影响SDK初始化，只用于switchEnvironment
                    appKey = appKey,
                    appSecret = appSecret
                )
            } else {
                // 从原生配置获取
                try {
                    PlaudEnvironmentConfig.getCurrentConfig(context)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to get environment config, using default: ${e.message}")
                    // 使用默认测试环境配置
                    PlaudEnvironmentConfig.EnvConfig(
                        name = "test",
                        displayName = "Common Test Environment",
                        baseUrl = "https://platform-beta.plaud.ai",
                        appKey = "plaud-uj5LWcHX-1755488820087",
                        appSecret = "aksk_SRzfcAAGnr4q9ZIK1kCaAjLEbaPX9Sfg"
                    )
                }
            }
            
            val finalAppKey = envConfig.appKey
            val finalAppSecret = envConfig.appSecret
            
            // 确定要切换到的服务器环境
            val serverEnvironment = when (environment ?: envConfig.name) {
                "US_TEST" -> sdk.ServerEnvironment.US_TEST
                "COMMON_TEST" -> sdk.ServerEnvironment.COMMON_TEST
                "CHINA_PROD" -> sdk.ServerEnvironment.CHINA_PROD
                "US_PROD" -> sdk.ServerEnvironment.US_PROD
                else -> {
                    // 如果没有明确的environment参数，根据baseUrl判断
                    when (envConfig.baseUrl) {
                        "https://dev-api-us-test.plaud.work" -> sdk.ServerEnvironment.US_TEST
                        "https://platform-beta.plaud.ai" -> sdk.ServerEnvironment.COMMON_TEST
                        "https://platform.plaud.cn" -> sdk.ServerEnvironment.CHINA_PROD
                        "https://platform.plaud.ai" -> sdk.ServerEnvironment.US_PROD
                        else -> sdk.ServerEnvironment.CHINA_PROD // 默认
                    }
                }
            }
            
            Log.d(TAG, "Initializing PlaudSDK...")
            Log.d(TAG, "Environment: ${envConfig.displayName}")
            Log.d(TAG, "Base URL: ${envConfig.baseUrl}")
            Log.d(TAG, "Using AppKey: $finalAppKey")
            Log.d(TAG, "Target server environment: ${serverEnvironment.name}")
            
            val bleAgentListener = object : BleAgentListener {
                override fun scanBleDeviceReceiver(device: BleDevice) {
                    Log.d(TAG, "Scan result: ${device.name} - SN: ${device.serialNumber} - MAC: ${device.macAddress}")
                    
                    // 缓存发现的设备信息，用于连接时使用
                    discoveredDevices[device.serialNumber] = device
                    Log.d(TAG, "Cached device: ${device.serialNumber}")
                    
                    onScanResult?.invoke(device)
                }
                
                override fun btStatusChange(sn: String?, status: BluetoothStatus) {
                    Log.i(TAG, "🔗 Bluetooth status change: device=$sn -> $status")
                    when (status) {
                        BluetoothStatus.CONNECTED -> {
                            Log.i(TAG, "✅ Device fully connected and handshake completed: $sn")
                            // 通知所有监听器
                            onConnectionStateChange?.invoke(true, sn)
                            notifyConnectionListeners(true, sn)
                        }
                        BluetoothStatus.CONNECTING -> {
                            Log.i(TAG, "🔄 Device connecting or handshaking: $sn")
                            // 不触发连接状态变化，等待真正的CONNECTED
                        }
                        BluetoothStatus.DISCONNECTED -> {
                            Log.i(TAG, "❌ Device disconnected: $sn")
                            // 通知所有监听器
                            onConnectionStateChange?.invoke(false, sn)
                            notifyConnectionListeners(false, sn)
                        }
                        else -> {
                            Log.d(TAG, "📡 Other status: $status")
                        }
                    }
                }
                
                // 实现必需的抽象方法
                override fun bleConnectFail(p0: String?, p1: sdk.penblesdk.Constants.ConnectBleFailed) {
                    Log.w(TAG, "BLE connect failed: $p0, reason: $p1")
                    // 连接失败时触发回调
                    onConnectionStateChange?.invoke(false, p0)
                    notifyConnectionListeners(false, p0)
                }
                
                override fun scanFail(p0: sdk.penblesdk.Constants.ScanFailed) {
                    Log.w(TAG, "Scan failed: $p0")
                }
                
                override fun handshakeWaitSure(p0: String?, p1: Long) {
                    Log.i(TAG, "🤝 Handshake wait sure: device=$p0, timeout=${p1}ms")
                    Log.i(TAG, "🔄 Handshake process started, waiting for device response...")
                }
                
                override fun rssiChange(p0: String?, p1: Int) {
                    Log.d(TAG, "RSSI change: $p0, rssi: $p1")
                }
                
                override fun mtuChange(p0: String?, p1: Int, p2: Boolean) {
                    Log.d(TAG, "MTU change: $p0, mtu: $p1, success: $p2")
                }
                
                override fun batteryLevelUpdate(p0: String?, p1: Int) {
                    Log.i(TAG, "🔋 Battery level update: device=$p0, level=$p1%")
                    onBatteryInfoUpdated?.invoke(p0, p1)
                }
                
                override fun chargingStatusChange(p0: String?, p1: Boolean) {
                    Log.d(TAG, "Charging status change: $p0, charging: $p1")
                }
                
                override fun deviceOpRecordStart(p0: String?, p1: sdk.penblesdk.entity.bean.ble.response.RecordStartRsp) {
                    Log.i(TAG, "🎙️ Device record start: device=$p0, sessionId=${p1.sessionId}, status=${p1.status}")
                    onRecordingStateChange?.invoke(true, p1.sessionId)
                }
                
                override fun deviceOpRecordStop(p0: String?, p1: sdk.penblesdk.entity.bean.ble.response.RecordStopRsp) {
                    Log.i(TAG, "⏹️ Device record stop: device=$p0, sessionId=${p1.sessionId}")
                    onRecordingStateChange?.invoke(false, p1.sessionId)
                }
                
                override fun deviceStatusRsp(p0: String?, p1: sdk.penblesdk.entity.bean.ble.response.GetStateRsp) {
                    Log.i(TAG, "📱 Device status response: device=$p0, state=${p1.stateCode}, sessionId=${p1.sessionId}")
                    
                    // 提取存储信息 - 先简单处理，后面再找到正确的属性
                    try {
                        val storageInfo = mutableMapOf<String, Any>()
                        
                        // 临时使用假数据，等找到正确的属性后再替换
                        // TODO: 找到GetStateRsp中存储相关的正确属性名
                        val freeSpace = 1000L * 1024 * 1024 // 临时：1GB
                        val totalSpace = 8000L * 1024 * 1024 // 临时：8GB
                        val usedSpace = totalSpace - freeSpace
                        
                        storageInfo["freeMB"] = freeSpace / (1024 * 1024)
                        storageInfo["totalMB"] = totalSpace / (1024 * 1024)
                        storageInfo["usedMB"] = usedSpace / (1024 * 1024)
                        storageInfo["freePercent"] = if (totalSpace > 0) (freeSpace * 100 / totalSpace).toInt() else 0
                        storageInfo["usedPercent"] = if (totalSpace > 0) (usedSpace * 100 / totalSpace).toInt() else 0
                        
                        Log.i(TAG, "💾 Storage info (temporary): free=${storageInfo["freeMB"]}MB, total=${storageInfo["totalMB"]}MB, used=${storageInfo["usedMB"]}MB")
                        
                        onStorageInfoUpdated?.invoke(p0, storageInfo)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to extract storage info from device status", e)
                    }
                }
            }
            
            // Use customDomain parameter to directly set the correct URL for the environment
            val customDomainUrl = serverEnvironment.url
            Log.d(TAG, "Using customDomain for initialization: $customDomainUrl")
            
            NiceBuildSdk.initSdk(
                context = context,
                appKey = finalAppKey,
                appSecret = finalAppSecret,
                bleAgentListener = bleAgentListener,
                hostName = "Plaud RN Demo",
                extra = null,
                customDomain = customDomainUrl
            )
            
            // After SDK initialization, switch environment to save preference for future use
            Log.d(TAG, "Post-switching to environment: ${serverEnvironment.name}")
            NiceBuildSdk.switchEnvironment(serverEnvironment)
            
            // SDK初始化成功，环境已在初始化前切换
            Log.d(TAG, "SDK initialization completed with environment: ${serverEnvironment.name}")
            Log.d(TAG, "Environment parameter: $environment")
            Log.d(TAG, "Config baseUrl: ${envConfig.baseUrl}")
            
            isInitialized = true
            Log.i(TAG, "SDK initialized successfully with environment: ${envConfig.displayName}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize SDK", e)
            false
        }
    }
    
    /**
     * 获取认证和权限
     */
    suspend fun getAuthAndPermission(appKey: String, appSecret: String): Boolean {
        return try {
            NiceBuildSdk.getAuthAndPermission(appKey, appSecret)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get auth and permission", e)
            false
        }
    }
    
    /**
     * 检查是否已登录
     */
    fun isLoggedIn(): Boolean {
        return try {
            NiceBuildSdk.isLoggedIn()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check login status", e)
            false
        }
    }
    
    /**
     * 登出
     */
    fun logout() {
        try {
            NiceBuildSdk.logout()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to logout", e)
        }
    }
    
    /**
     * 开始扫描设备
     */
    fun startScan(): Boolean {
        return try {
            if (!isInitialized) {
                Log.e(TAG, "SDK not initialized, cannot start scan")
                return false
            }
            
            Log.d(TAG, "Starting BLE device scan...")
            
            // 使用TntAgent的BLE代理来开始扫描
            val bleAgent = TntAgent.getInstant().bleAgent
            val success = bleAgent.scanBle(true) { errorCode ->
                Log.e(TAG, "Scan error: $errorCode")
            }
            
            if (success) {
                Log.i(TAG, "BLE scan started successfully")
            } else {
                Log.e(TAG, "Failed to start BLE scan")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start scan", e)
            false
        }
    }
    
    /**
     * 停止扫描
     */
    fun stopScan(): Boolean {
        return try {
            Log.d(TAG, "Stopping BLE device scan...")
            
            // 使用TntAgent的BLE代理来停止扫描
            val bleAgent = TntAgent.getInstant().bleAgent
            val success = bleAgent.scanBle(false) { errorCode ->
                Log.e(TAG, "Stop scan error: $errorCode")
            }
            
            if (success) {
                Log.i(TAG, "BLE scan stopped successfully")
            } else {
                Log.e(TAG, "Failed to stop BLE scan")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop scan", e)
            false
        }
    }
    
    /**
     * 连接设备
     */
    fun connectDevice(serialNumber: String, token: String, callback: (Boolean, String?) -> Unit) {
        try {
            if (!isInitialized) {
                Log.e(TAG, "SDK not initialized, cannot connect device")
                callback(false, "SDK not initialized")
                return
            }
            
            Log.i(TAG, "🚀 Connecting to device: $serialNumber")
            Log.i(TAG, "🔑 Using token: $token (length: ${token.length})")
            
            // 停止扫描
            stopScan()
            
            // 从缓存中获取设备信息
            val device = discoveredDevices[serialNumber]
            if (device == null) {
                Log.e(TAG, "Device not found in scan results: $serialNumber")
                callback(false, "Device not found. Please scan for devices first.")
                return
            }
            
            Log.i(TAG, "📱 Using cached device info:")
            Log.i(TAG, "   📛 Name: ${device.name}")
            Log.i(TAG, "   🏷️ MAC: ${device.macAddress}")
            Log.i(TAG, "   🔢 SN: ${device.serialNumber}")
            
            Log.i(TAG, "🔌 Starting BLE connection process...")
            
            // 设置连接状态监听
            var connectionCallback: ((Boolean, String?) -> Unit)? = callback
            
            // 创建临时连接监听器
            lateinit var tempConnectionListener: (Boolean, String?) -> Unit
            tempConnectionListener = { isConnected, deviceId ->
                Log.d(TAG, "Temp connection listener: isConnected=$isConnected, deviceId='$deviceId'")
                if (isConnected) {
                    // 连接成功，不管设备ID是否匹配（因为某些情况下设备ID可能为空）
                    Log.i(TAG, "Device connected and handshake completed: $serialNumber")
                    connectionCallback?.invoke(true, null)
                    connectionCallback = null // 防止重复调用
                    // 移除临时监听器
                    removeConnectionListener(tempConnectionListener)
                } else if (!isConnected) {
                    Log.w(TAG, "Device disconnected")
                    connectionCallback?.invoke(false, "Connection lost")
                    connectionCallback = null
                    // 移除临时监听器
                    removeConnectionListener(tempConnectionListener)
                }
            }
            
            // 添加临时监听器
            addConnectionListener(tempConnectionListener)
            
            // 使用TntAgent的BLE代理进行连接
            val bleAgent = TntAgent.getInstant().bleAgent
            bleAgent.connectionBLE(
                device,
                token,      // bindToken
                null,       // devToken
                null,       // userName
                10000L,     // connectTimeout: 10秒
                30000L      // handshakeTimeout: 30秒
            )
            
            Log.i(TAG, "BLE connection initiated for device: $serialNumber")
            
            // 设置连接超时
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (connectionCallback != null) {
                    Log.w(TAG, "Connection timeout for device: $serialNumber")
                    connectionCallback?.invoke(false, "Connection timeout")
                    connectionCallback = null
                }
            }, 15000L) // 15秒超时
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect device", e)
            callback(false, e.message)
        }
    }
    
    /**
     * 断开设备连接
     */
    fun disconnectDevice(callback: (Boolean, String?) -> Unit) {
        try {
            Log.d(TAG, "Disconnecting device")
            
            // 使用TntAgent的BLE代理进行断开连接
            val bleAgent = TntAgent.getInstant().bleAgent
            bleAgent.disconnectBle()
            
            Log.i(TAG, "Device disconnection initiated")
            
            // 监听断开连接状态
            onConnectionStateChange = { isConnected, deviceId ->
                Log.d(TAG, "Disconnect state changed: isConnected=$isConnected")
                if (!isConnected) {
                    Log.i(TAG, "Device disconnected successfully")
                    callback(true, null)
                    onConnectionStateChange = null // 清除监听
                }
            }
            
            // 设置断开连接超时
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                Log.i(TAG, "Disconnect operation completed (timeout)")
                callback(true, null) // 断开连接即使超时也认为成功
            }, 5000L) // 5秒超时
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disconnect device", e)
            callback(false, e.message)
        }
    }
    
    /**
     * 检查是否已连接
     */
    fun isDeviceConnected(): Boolean {
        return try {
            if (!isInitialized) {
                return false
            }
            
            // 使用TntAgent的BLE代理检查连接状态
            val bleAgent = TntAgent.getInstant().bleAgent
            val isConnected = bleAgent.isConnected()
            
            Log.d(TAG, "Device connection status: $isConnected")
            isConnected
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check connection status", e)
            false
        }
    }
    
    /**
     * 获取设备状态（电池、存储等信息）
     */
    fun getDeviceStatus() {
        try {
            if (!isInitialized) {
                Log.w(TAG, "SDK not initialized, cannot get device status")
                return
            }
            
            val bleAgent = TntAgent.getInstant().bleAgent
            if (!bleAgent.isConnected()) {
                Log.w(TAG, "Device not connected, cannot get device status")
                return
            }
            
            Log.d(TAG, "📱 Requesting device status...")
            bleAgent.getState(
                object : sdk.penblesdk.entity.AgentCallback.OnRequest {
                    override fun onCallback(success: Boolean) {
                        Log.d(TAG, "📱 Get device status request sent: success=$success")
                    }
                },
                object : sdk.penblesdk.entity.AgentCallback.OnResponse<sdk.penblesdk.entity.bean.ble.response.GetStateRsp> {
                    override fun onCallback(response: sdk.penblesdk.entity.bean.ble.response.GetStateRsp?) {
                        Log.d(TAG, "📱 Get device status response received: $response")
                        // deviceStatusRsp 会自动被调用，无需手动处理
                    }
                },
                object : sdk.penblesdk.entity.AgentCallback.OnError {
                    override fun onError(errorCode: sdk.penblesdk.entity.BleErrorCode) {
                        Log.e(TAG, "Get device status error: $errorCode")
                    }
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get device status", e)
        }
    }
    
    /**
     * 手动触发电池信息更新（用于测试）
     */
    fun triggerBatteryInfo() {
        try {
            Log.d(TAG, "🔋 Manually triggering battery info...")
            // 模拟电池信息（等找到实际API后替换）
            val fakeLevel = (70..90).random() // 随机70-90%
            onBatteryInfoUpdated?.invoke("", fakeLevel)
            Log.d(TAG, "🔋 Fake battery info triggered: $fakeLevel%")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger battery info", e)
        }
    }
    
    /**
     * 获取真实的存储信息（使用正确的API）
     */
    fun getRealStorageInfo() {
        try {
            if (!isInitialized) {
                Log.w(TAG, "SDK not initialized, cannot get storage info")
                return
            }
            
            val bleAgent = TntAgent.getInstant().bleAgent
            if (!bleAgent.isConnected()) {
                Log.w(TAG, "Device not connected, cannot get storage info")
                return
            }
            
            Log.d(TAG, "💾 Getting real storage info...")
            // 使用简化的getStorage方法，就像原生项目一样
            bleAgent.getStorage({ success ->
                Log.d(TAG, "💾 Get storage request sent: success=$success")
            }, { response ->
                Log.d(TAG, "💾 Get storage response received: $response")
                if (response != null) {
                    try {
                        val freeBytes = response.getFree() ?: 0L
                        val totalBytes = response.getTotal() ?: 0L
                        val usedBytes = totalBytes - freeBytes
                        
                        val storageInfo = mutableMapOf<String, Any>()
                        storageInfo["freeMB"] = freeBytes / (1024 * 1024)
                        storageInfo["totalMB"] = totalBytes / (1024 * 1024)
                        storageInfo["usedMB"] = usedBytes / (1024 * 1024)
                        storageInfo["freePercent"] = if (totalBytes > 0) (freeBytes * 100 / totalBytes).toInt() else 0
                        storageInfo["usedPercent"] = if (totalBytes > 0) (usedBytes * 100 / totalBytes).toInt() else 0
                        
                        Log.i(TAG, "💾 Real storage info: free=${storageInfo["freeMB"]}MB, total=${storageInfo["totalMB"]}MB, used=${storageInfo["usedMB"]}MB")
                        
                        onStorageInfoUpdated?.invoke("", storageInfo)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse storage response", e)
                    }
                }
            }, { errorCode ->
                Log.e(TAG, "Get storage error: $errorCode")
            })
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get real storage info", e)
        }
    }
}
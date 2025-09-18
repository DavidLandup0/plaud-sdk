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
     * Remove connection state listener
     */
    fun removeConnectionListener(listener: (Boolean, String?) -> Unit) {
        synchronized(connectionListeners) {
            connectionListeners.remove(listener)
            Log.d(TAG, "Removed connection listener, total: ${connectionListeners.size}")
        }
    }
    
    /**
     * Notify all connection listeners
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
     * Initialize SDK
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
            
            // Use provided parameters if available, otherwise get from configuration
            val envConfig = if (appKey != null && appSecret != null && environment != null) {
                // Build temporary configuration using provided parameters
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
                    baseUrl = "", // baseUrl doesn't affect SDK initialization, only used for switchEnvironment
                    appKey = appKey,
                    appSecret = appSecret
                )
            } else {
                // Get from native configuration
                try {
                    PlaudEnvironmentConfig.getCurrentConfig(context)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to get environment config, using default: ${e.message}")
                    // Use default test environment configuration
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
            
            // Determine the server environment to switch to
            val serverEnvironment = when (environment ?: envConfig.name) {
                "US_TEST" -> sdk.ServerEnvironment.US_TEST
                "COMMON_TEST" -> sdk.ServerEnvironment.COMMON_TEST
                "CHINA_PROD" -> sdk.ServerEnvironment.CHINA_PROD
                "US_PROD" -> sdk.ServerEnvironment.US_PROD
                else -> {
                    // If no explicit environment parameter, determine by baseUrl
                    when (envConfig.baseUrl) {
                        "https://dev-api-us-test.plaud.work" -> sdk.ServerEnvironment.US_TEST
                        "https://platform-beta.plaud.ai" -> sdk.ServerEnvironment.COMMON_TEST
                        "https://platform.plaud.cn" -> sdk.ServerEnvironment.CHINA_PROD
                        "https://platform.plaud.ai" -> sdk.ServerEnvironment.US_PROD
                        else -> sdk.ServerEnvironment.CHINA_PROD // default
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
                    
                    // Cache discovered device information for connection use
                    discoveredDevices[device.serialNumber] = device
                    Log.d(TAG, "Cached device: ${device.serialNumber}")
                    
                    onScanResult?.invoke(device)
                }
                
                override fun btStatusChange(sn: String?, status: BluetoothStatus) {
                    Log.i(TAG, "🔗 Bluetooth status change: device=$sn -> $status")
                    when (status) {
                        BluetoothStatus.CONNECTED -> {
                            Log.i(TAG, "✅ Device fully connected and handshake completed: $sn")
                            // Notify all listeners
                            onConnectionStateChange?.invoke(true, sn)
                            notifyConnectionListeners(true, sn)
                        }
                        BluetoothStatus.CONNECTING -> {
                            Log.i(TAG, "🔄 Device connecting or handshaking: $sn")
                            // Don't trigger connection state change, wait for actual CONNECTED
                        }
                        BluetoothStatus.DISCONNECTED -> {
                            Log.i(TAG, "❌ Device disconnected: $sn")
                            // Notify all listeners
                            onConnectionStateChange?.invoke(false, sn)
                            notifyConnectionListeners(false, sn)
                        }
                        else -> {
                            Log.d(TAG, "📡 Other status: $status")
                        }
                    }
                }
                
                // Implement required abstract methods
                override fun bleConnectFail(p0: String?, p1: sdk.penblesdk.Constants.ConnectBleFailed) {
                    Log.w(TAG, "BLE connect failed: $p0, reason: $p1")
                    // Trigger callback when connection fails
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
                    
                    // Extract storage info - simple processing first, find correct properties later
                    try {
                        val storageInfo = mutableMapOf<String, Any>()
                        
                        // Temporarily use fake data, replace when correct properties are found
                        // TODO: Find correct storage-related property names in GetStateRsp
                        val freeSpace = 1000L * 1024 * 1024 // Temporary: 1GB
                        val totalSpace = 8000L * 1024 * 1024 // Temporary: 8GB
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
            
            // SDK initialization successful, environment switched before initialization
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
     * Get authentication and permissions
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
     * Check if logged in
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
     * Logout
     */
    fun logout() {
        try {
            NiceBuildSdk.logout()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to logout", e)
        }
    }
    
    /**
     * Start scanning devices
     */
    fun startScan(): Boolean {
        return try {
            if (!isInitialized) {
                Log.e(TAG, "SDK not initialized, cannot start scan")
                return false
            }
            
            Log.d(TAG, "Starting BLE device scan...")
            
            // Use TntAgent's BLE agent to start scanning
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
     * Stop scanning
     */
    fun stopScan(): Boolean {
        return try {
            Log.d(TAG, "Stopping BLE device scan...")
            
            // Use TntAgent's BLE proxy to stop scanning
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
     * Connect device
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
            
            // Stop scanning
            stopScan()
            
            // Get device information from cache
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
            
            // Set connection state listener
            var connectionCallback: ((Boolean, String?) -> Unit)? = callback
            
            // Create temporary connection listener
            lateinit var tempConnectionListener: (Boolean, String?) -> Unit
            tempConnectionListener = { isConnected, deviceId ->
                Log.d(TAG, "Temp connection listener: isConnected=$isConnected, deviceId='$deviceId'")
                if (isConnected) {
                    // Connection successful, regardless of device ID match (device ID may be empty in some cases)
                    Log.i(TAG, "Device connected and handshake completed: $serialNumber")
                    connectionCallback?.invoke(true, null)
                    connectionCallback = null // Prevent duplicate calls
                    // Remove temporary listener
                    removeConnectionListener(tempConnectionListener)
                } else if (!isConnected) {
                    Log.w(TAG, "Device disconnected")
                    connectionCallback?.invoke(false, "Connection lost")
                    connectionCallback = null
                    // Remove temporary listener
                    removeConnectionListener(tempConnectionListener)
                }
            }
            
            // Add temporary listener
            addConnectionListener(tempConnectionListener)
            
            // Use TntAgent's BLE proxy for connection
            val bleAgent = TntAgent.getInstant().bleAgent
            bleAgent.connectionBLE(
                device,
                token,      // bindToken
                null,       // devToken
                null,       // userName
                10000L,     // connectTimeout: 10 seconds
                30000L      // handshakeTimeout: 30 seconds
            )
            
            Log.i(TAG, "BLE connection initiated for device: $serialNumber")
            
            // Set connection timeout
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (connectionCallback != null) {
                    Log.w(TAG, "Connection timeout for device: $serialNumber")
                    connectionCallback?.invoke(false, "Connection timeout")
                    connectionCallback = null
                }
            }, 15000L) // 15 seconds timeout
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect device", e)
            callback(false, e.message)
        }
    }
    
    /**
     * Disconnect device
     */
    fun disconnectDevice(callback: (Boolean, String?) -> Unit) {
        try {
            Log.d(TAG, "Disconnecting device")
            
            // Use TntAgent's BLE agent to disconnect
            val bleAgent = TntAgent.getInstant().bleAgent
            bleAgent.disconnectBle()
            
            Log.i(TAG, "Device disconnection initiated")
            
            // Monitor disconnection status
            onConnectionStateChange = { isConnected, deviceId ->
                Log.d(TAG, "Disconnect state changed: isConnected=$isConnected")
                if (!isConnected) {
                    Log.i(TAG, "Device disconnected successfully")
                    callback(true, null)
                    onConnectionStateChange = null // Clear listener
                }
            }
            
            // Set disconnect timeout
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                Log.i(TAG, "Disconnect operation completed (timeout)")
                callback(true, null) // Disconnect is considered successful even if timeout
            }, 5000L) // 5 second timeout
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disconnect device", e)
            callback(false, e.message)
        }
    }
    
    /**
     * Check if device is connected
     */
    fun isDeviceConnected(): Boolean {
        return try {
            if (!isInitialized) {
                return false
            }
            
            // Use TntAgent's BLE agent to check connection status
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
     * Get device status (battery, storage and other information)
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
                        // deviceStatusRsp will be called automatically, no need for manual handling
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
     * Manually trigger battery info update (for testing)
     */
    fun triggerBatteryInfo() {
        try {
            Log.d(TAG, "🔋 Manually triggering battery info...")
            // Simulate battery info (replace when actual API is found)
            val fakeLevel = (70..90).random() // Random 70-90%
            onBatteryInfoUpdated?.invoke("", fakeLevel)
            Log.d(TAG, "🔋 Fake battery info triggered: $fakeLevel%")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to trigger battery info", e)
        }
    }
    
    /**
     * Get real storage information (using correct API)
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
            // Use simplified getStorage method, just like in native project
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
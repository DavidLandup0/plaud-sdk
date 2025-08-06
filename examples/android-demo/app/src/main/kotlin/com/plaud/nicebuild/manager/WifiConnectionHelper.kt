package com.plaud.nicebuild.manager

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * WiFi Connection Helper - Handles phone connection to device WiFi hotspot
 * Based on reference project's WiFi connection implementation
 */
class WifiConnectionHelper(private val context: Context) {
    
    companion object {
        private const val TAG = "WifiConnectionHelper"
        // Try multiple common ports that devices might use
        private val DEVICE_HTTP_PORTS = intArrayOf(8080, 80, 8000, 8888, 9000)
        private const val CONNECTION_TIMEOUT = 30000 // 30 seconds
        private const val HTTP_TIMEOUT = 15000 // 15 seconds
        private const val HTTP_RETRY_COUNT = 3
        private const val HTTP_RETRY_DELAY = 3000L // 3 seconds
    }
    
    private val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    private var currentNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var connectedNetwork: Network? = null
    private var successfulHttpPort: Int = DEVICE_HTTP_PORTS[0] // Default to first port
    
    /**
     * Connect to device WiFi hotspot
     */
    suspend fun connectToDeviceWifi(
        ssid: String,
        password: String,
        userId: String,
        skipHttpTest: Boolean = false
    ): Result<Network> = withContext(Dispatchers.Main) {
        try {
            Log.i(TAG, "Connecting to device WiFi: $ssid")
            
            return@withContext if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                connectWifiAndroidQ(ssid, password, userId, skipHttpTest)
            } else {
                connectWifiLegacy(ssid, password, userId, skipHttpTest)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to WiFi: ${e.message}", e)
            Result.failure(e)
        }
    }
    
    /**
     * Connect WiFi on Android Q+ using NetworkRequest
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private suspend fun connectWifiAndroidQ(
        ssid: String,
        password: String,
        userId: String,
        skipHttpTest: Boolean = false
    ): Result<Network> = suspendCoroutine { continuation ->
        try {
            // Create WiFi network specifier
            val specifier = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password)
                .build()
            
            // Create network request
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .setNetworkSpecifier(specifier)
                .build()
            
            // Create network callback
            val networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.i(TAG, "WiFi network available: $network")
                    connectedNetwork = network
                    currentNetworkCallback = null
                    
                    if (skipHttpTest) {
                        // For WebSocket mode, skip HTTP test and return network directly
                        Log.i(TAG, "Skipping HTTP test for WebSocket mode")
                        if (continuation.context.isActive) {
                            continuation.resume(Result.success(network))
                        }
                    } else {
                        // Test HTTP connection for legacy mode
                        testHttpConnection(network, userId) { success ->
                            if (success) {
                                if (continuation.context.isActive) {
                                    continuation.resume(Result.success(network))
                                }
                            } else {
                                if (continuation.context.isActive) {
                                    continuation.resume(Result.failure(Exception("HTTP connection test failed")))
                                }
                            }
                        }
                    }
                }
                
                override fun onUnavailable() {
                    Log.e(TAG, "WiFi network unavailable")
                    currentNetworkCallback = null
                    if (continuation.context.isActive) {
                        continuation.resume(Result.failure(Exception("WiFi connection unavailable")))
                    }
                }
                
                override fun onLost(network: Network) {
                    Log.w(TAG, "WiFi network lost: $network")
                    if (network == connectedNetwork) {
                        connectedNetwork = null
                    }
                }
            }
            
            currentNetworkCallback = networkCallback
            
            // Request network connection
            connectivityManager.requestNetwork(request, networkCallback, CONNECTION_TIMEOUT)
            
            Log.i(TAG, "WiFi connection request sent for: $ssid")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in connectWifiAndroidQ: ${e.message}", e)
            if (continuation.context.isActive) {
                continuation.resume(Result.failure(e))
            }
        }
    }
    
    /**
     * Connect WiFi on Android < Q using WifiConfiguration
     */
    @Suppress("DEPRECATION")
    private suspend fun connectWifiLegacy(
        ssid: String,
        password: String,
        userId: String,
        skipHttpTest: Boolean = false
    ): Result<Network> = withContext(Dispatchers.IO) {
        try {
            // Create WiFi configuration
            val config = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                preSharedKey = "\"$password\""
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                allowedProtocols.set(WifiConfiguration.Protocol.RSN)
                allowedProtocols.set(WifiConfiguration.Protocol.WPA)
                allowedGroupCiphers.set(WifiConfiguration.GroupCipher.WEP40)
                allowedGroupCiphers.set(WifiConfiguration.GroupCipher.WEP104)
                allowedGroupCiphers.set(WifiConfiguration.GroupCipher.CCMP)
                allowedGroupCiphers.set(WifiConfiguration.GroupCipher.TKIP)
                allowedPairwiseCiphers.set(WifiConfiguration.PairwiseCipher.CCMP)
                allowedPairwiseCiphers.set(WifiConfiguration.PairwiseCipher.TKIP)
            }
            
            // Add network
            val networkId = wifiManager.addNetwork(config)
            if (networkId == -1) {
                return@withContext Result.failure(Exception("Failed to add WiFi network"))
            }
            
            // Connect to network
            val connected = wifiManager.enableNetwork(networkId, true)
            if (!connected) {
                wifiManager.removeNetwork(networkId)
                return@withContext Result.failure(Exception("Failed to enable WiFi network"))
            }
            
            // Wait for connection
            var attempts = 0
            while (attempts < 30) { // 30 seconds timeout
                delay(1000)
                attempts++
                
                val connectionInfo = wifiManager.connectionInfo
                if (connectionInfo?.ssid?.removeSurrounding("\"") == ssid) {
                    Log.i(TAG, "Connected to WiFi: $ssid")
                    
                    // Get current network
                    val network = connectivityManager.activeNetwork
                    if (network != null) {
                        connectedNetwork = network
                        
                        // Test HTTP connection
                        val httpSuccess = withContext(Dispatchers.IO) {
                            testHttpConnectionSync(network, userId)
                        }
                        
                        return@withContext if (httpSuccess) {
                            Result.success(network)
                        } else {
                            Result.failure(Exception("HTTP connection test failed"))
                        }
                    }
                }
            }
            
            // Clean up on timeout
            wifiManager.removeNetwork(networkId)
            return@withContext Result.failure(Exception("WiFi connection timeout"))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in connectWifiLegacy: ${e.message}", e)
            return@withContext Result.failure(e)
        }
    }
    
    /**
     * Test HTTP connection to device (async)
     */
    private fun testHttpConnection(network: Network, userId: String, callback: (Boolean) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            val success = testHttpConnectionSync(network, userId)
            withContext(Dispatchers.Main) {
                callback(success)
            }
        }
    }
    
    /**
     * Test HTTP connection to device (sync)
     */
    private suspend fun testHttpConnectionSync(network: Network, userId: String): Boolean = withContext(Dispatchers.IO) {
        val deviceIp = getDeviceIpAddress() ?: return@withContext false
        Log.i(TAG, "Testing HTTP connection to device: $deviceIp")
        
        // Additional wait for device HTTP service to fully start
        Log.i(TAG, "Waiting extra 3 seconds for device HTTP service to be ready...")
        delay(3000)
        
        // Try different API endpoints that the device might support
        val testPaths = arrayOf(
            "",           // Root path
            "/",          // Root with slash
            "/api/ping",  // Standard ping endpoint
            "/ping",      // Simple ping
            "/status",    // Status endpoint
            "/api/status",// API status
            "/files",     // Files endpoint
            "/api/files"  // API files
        )
        
        // Try each port with multiple paths and retries
        for (port in DEVICE_HTTP_PORTS) {
            Log.i(TAG, "Testing port: $port")
            
            for (retry in 1..HTTP_RETRY_COUNT) {
                for (path in testPaths) {
                    try {
                        val url = URL("http://$deviceIp:$port$path")
                        val connection = network.openConnection(url) as HttpURLConnection
                        
                        connection.apply {
                            requestMethod = "GET"
                            connectTimeout = HTTP_TIMEOUT
                            readTimeout = HTTP_TIMEOUT
                            setRequestProperty("User-Agent", "PlaudApp")
                            setRequestProperty("X-User-ID", userId)
                            setRequestProperty("Accept", "*/*")
                            setRequestProperty("Connection", "close")
                        }
                        
                        val responseCode = connection.responseCode
                        connection.disconnect()
                        
                        // Accept any successful HTTP response (200-299) or even some 4xx responses
                        // as it indicates the HTTP server is running
                        if (responseCode in 200..299 || responseCode in 400..499) {
                            Log.i(TAG, "HTTP connection successful: $url (code: $responseCode)")
                            successfulHttpPort = port // Save the working port
                            return@withContext true
                        }
                        
                        Log.d(TAG, "HTTP test $url: code=$responseCode")
                        
                    } catch (e: Exception) {
                        Log.d(TAG, "HTTP test failed for $deviceIp:$port$path (retry $retry): ${e.message}")
                    }
                }
                
                // Wait before retry (except for last attempt)
                if (retry < HTTP_RETRY_COUNT) {
                    Log.i(TAG, "Waiting ${HTTP_RETRY_DELAY}ms before retry $retry for port $port")
                    delay(HTTP_RETRY_DELAY)
                }
            }
        }
        
        Log.e(TAG, "All HTTP connection attempts failed for device: $deviceIp")
        return@withContext false
    }
    
    /**
     * Get device IP address from WiFi gateway
     */
    private fun getDeviceIpAddress(): String? {
        try {
            val dhcpInfo = wifiManager.dhcpInfo
            val gateway = dhcpInfo?.gateway
            
            if (gateway != null && gateway != 0) {
                // Convert IP address from integer to string
                val ip = String.format(
                    "%d.%d.%d.%d",
                    gateway and 0xff,
                    gateway shr 8 and 0xff,
                    gateway shr 16 and 0xff,
                    gateway shr 24 and 0xff
                )
                Log.i(TAG, "Device IP address: $ip")
                return ip
            }
            
            return null
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting device IP: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Disconnect from current WiFi network
     */
    suspend fun disconnectWifi(): Result<Unit> = withContext(Dispatchers.Main) {
        try {
            Log.i(TAG, "Disconnecting from WiFi...")
            
            // Unregister network callback
            currentNetworkCallback?.let { callback ->
                try {
                    connectivityManager.unregisterNetworkCallback(callback)
                } catch (e: Exception) {
                    Log.w(TAG, "Error unregistering network callback: ${e.message}")
                }
                currentNetworkCallback = null
            }
            
            // Clear connected network and reset port
            connectedNetwork = null
            successfulHttpPort = DEVICE_HTTP_PORTS[0] // Reset to default port
            
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                // For legacy Android, try to disconnect from current network
                try {
                    wifiManager.disconnect()
                    delay(1000) // Wait a bit for disconnection
                    wifiManager.reconnect() // Reconnect to previous network
                } catch (e: Exception) {
                    Log.w(TAG, "Error in legacy WiFi disconnect: ${e.message}")
                }
            }
            
            Log.i(TAG, "WiFi disconnected successfully")
            return@withContext Result.success(Unit)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting WiFi: ${e.message}", e)
            return@withContext Result.failure(e)
        }
    }
    
    /**
     * Check if currently connected to device WiFi
     */
    fun isConnectedToDeviceWifi(deviceSsid: String): Boolean {
        try {
            val connectionInfo = wifiManager.connectionInfo
            val currentSsid = connectionInfo?.ssid?.removeSurrounding("\"")
            return currentSsid == deviceSsid
        } catch (e: Exception) {
            Log.e(TAG, "Error checking WiFi connection: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Get current connected network
     */
    fun getCurrentNetwork(): Network? = connectedNetwork
    
    /**
     * Get device IP for HTTP requests using the successfully tested port
     */
    fun getDeviceHttpUrl(): String? {
        val deviceIp = getDeviceIpAddress()
        return deviceIp?.let { "http://$it:$successfulHttpPort" }
    }
}
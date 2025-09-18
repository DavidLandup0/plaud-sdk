package com.reactnativedemo.plaud

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import sdk.NiceBuildSdk

class PlaudSDKModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val TAG = "PlaudSDKModule"

    override fun getName(): String {
        return "PlaudSDK"
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
     * Initialize SDK
     */
    @ReactMethod
    fun initSdk(options: ReadableMap?, promise: Promise) {
        try {
            // If options are provided, use appKey and appSecret from them
            // Otherwise use default values from environment configuration
            val appKey = options?.getString("appKey")
            val appSecret = options?.getString("appSecret")
            val environment = options?.getString("environment")

            Log.d(TAG, "Initializing SDK with force reinit...")
            Log.d(TAG, "AppKey: $appKey")
            Log.d(TAG, "Environment: $environment")

            CoroutineScope(Dispatchers.Main).launch {
                try {
                    val bleCore = PlaudBleCore.getInstance(reactApplicationContext)
                    // Force reinitialization to ensure new AppKey and AppSecret are used
                    val success = bleCore.initSdk(appKey, appSecret, environment, true)

                    if (success) {
                        promise.resolve(Arguments.createMap().apply {
                            putBoolean("success", true)
                            putString("message", "SDK initialized successfully")
                        })
                    } else {
                        promise.reject("INIT_FAILED", "SDK initialization failed")
                    }

                } catch (e: Exception) {
                    Log.e(TAG, "Failed to initialize SDK", e)
                    promise.reject("INIT_FAILED", "SDK initialization failed: ${e.message}", e)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "SDK init error", e)
            promise.reject("INIT_ERROR", "SDK init error: ${e.message}", e)
        }
    }

    /**
     * User login
     */
    @ReactMethod
    fun login(appKey: String, appSecret: String, promise: Promise) {
        try {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val bleCore = PlaudBleCore.getInstance(reactApplicationContext)
                    val result = bleCore.getAuthAndPermission(appKey, appSecret)
                    
                    launch(Dispatchers.Main) {
                        if (result) {
                            promise.resolve(Arguments.createMap().apply {
                                putBoolean("success", true)
                                putString("message", "Login successful")
                            })
                        } else {
                            promise.reject("LOGIN_FAILED", "Login failed")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Login error", e)
                    launch(Dispatchers.Main) {
                        promise.reject("LOGIN_ERROR", "Login error: ${e.message}", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Login error", e)
            promise.reject("LOGIN_ERROR", "Login error: ${e.message}", e)
        }
    }

    /**
     * User logout
     */
    @ReactMethod
    fun logout(promise: Promise) {
        try {
            val bleCore = PlaudBleCore.getInstance(reactApplicationContext)
            bleCore.logout()
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
                putString("message", "Logout successful")
            })
        } catch (e: Exception) {
            Log.e(TAG, "Logout error", e)
            promise.reject("LOGOUT_ERROR", "Logout error: ${e.message}", e)
        }
    }

    /**
     * Check if user is logged in
     */
    @ReactMethod
    fun isLoggedIn(promise: Promise) {
        try {
            val bleCore = PlaudBleCore.getInstance(reactApplicationContext)
            val isLoggedIn = bleCore.isLoggedIn()
            promise.resolve(Arguments.createMap().apply {
                putBoolean("isLoggedIn", isLoggedIn)
            })
        } catch (e: Exception) {
            Log.e(TAG, "Check login status error", e)
            promise.reject("CHECK_LOGIN_ERROR", "Check login status error: ${e.message}", e)
        }
    }

    /**
     * Switch server environment
     */
    @ReactMethod
    fun switchEnvironment(environment: String, promise: Promise) {
        try {
            val serverEnv = when (environment) {
                "US_PROD" -> sdk.ServerEnvironment.US_PROD
                "US_TEST" -> sdk.ServerEnvironment.US_TEST
                "COMMON_TEST" -> sdk.ServerEnvironment.COMMON_TEST
                else -> sdk.ServerEnvironment.CHINA_PROD
            }

            NiceBuildSdk.switchEnvironment(serverEnv)
            
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
                putString("environment", environment)
            })
        } catch (e: Exception) {
            Log.e(TAG, "Switch environment error", e)
            promise.reject("SWITCH_ENV_ERROR", "Switch environment error: ${e.message}", e)
        }
    }

    /**
     * Get current environment information
     */
    @ReactMethod
    fun getCurrentEnvironment(promise: Promise) {
        try {
            val currentEnv = NiceBuildSdk.getCurrentEnvironment()
            promise.resolve(Arguments.createMap().apply {
                putString("environment", currentEnv.name)
                putString("url", currentEnv.url)
            })
        } catch (e: Exception) {
            Log.e(TAG, "Get current environment error", e)
            promise.reject("GET_ENV_ERROR", "Get current environment error: ${e.message}", e)
        }
    }

    /**
     * Bind device
     */
    @ReactMethod
    fun bindDevice(ownerId: String, sn: String, snType: String, promise: Promise) {
        try {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    NiceBuildSdk.bindDevice(ownerId, sn, snType)
                    
                    launch(Dispatchers.Main) {
                        promise.resolve(Arguments.createMap().apply {
                            putBoolean("success", true)
                            putString("message", "Device bound successfully")
                        })
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Bind device error", e)
                    launch(Dispatchers.Main) {
                        promise.reject("BIND_DEVICE_ERROR", "Bind device error: ${e.message}", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Bind device error", e)
            promise.reject("BIND_DEVICE_ERROR", "Bind device error: ${e.message}", e)
        }
    }

    /**
     * Unbind device
     */
    @ReactMethod
    fun unbindDevice(ownerId: String, sn: String, snType: String, promise: Promise) {
        try {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    NiceBuildSdk.unbindDevice(ownerId, sn, snType)
                    
                    launch(Dispatchers.Main) {
                        promise.resolve(Arguments.createMap().apply {
                            putBoolean("success", true)
                            putString("message", "Device unbound successfully")
                        })
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Unbind device error", e)
                    launch(Dispatchers.Main) {
                        promise.reject("UNBIND_DEVICE_ERROR", "Unbind device error: ${e.message}", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unbind device error", e)
            promise.reject("UNBIND_DEVICE_ERROR", "Unbind device error: ${e.message}", e)
        }
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

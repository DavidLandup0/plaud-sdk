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
     * 发送事件到React Native
     */
    private fun sendEvent(eventName: String, params: WritableMap?) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }

    /**
     * 初始化SDK
     */
    @ReactMethod
    fun initSdk(options: ReadableMap?, promise: Promise) {
        try {
            // 如果提供了options，则使用其中的appKey和appSecret
            // 否则使用环境配置中的默认值
            val appKey = options?.getString("appKey")
            val appSecret = options?.getString("appSecret")
            val environment = options?.getString("environment")

            Log.d(TAG, "Initializing SDK with force reinit...")
            Log.d(TAG, "AppKey: $appKey")
            Log.d(TAG, "Environment: $environment")

            CoroutineScope(Dispatchers.Main).launch {
                try {
                    val bleCore = PlaudBleCore.getInstance(reactApplicationContext)
                    // 强制重新初始化，确保使用新的AppKey和AppSecret
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
     * 用户登录
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
     * 用户登出
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
     * 检查是否已登录
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
     * 切换服务器环境
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
     * 获取当前环境信息
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
     * 绑定设备
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
     * 解绑设备
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

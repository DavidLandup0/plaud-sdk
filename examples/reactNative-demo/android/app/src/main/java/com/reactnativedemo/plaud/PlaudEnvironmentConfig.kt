package com.reactnativedemo.plaud

import android.content.Context
import android.content.SharedPreferences
import com.facebook.react.bridge.*

object PlaudEnvironmentConfig {
    private const val PREFS_NAME = "plaud_env_config"
    private const val KEY_CURRENT_ENV = "current_environment"
    
    enum class Environment {
        DEVELOPMENT,
        TEST, 
        PRODUCTION
    }
    
    data class EnvConfig(
        val name: String,
        val displayName: String,
        val baseUrl: String,
        val appKey: String,
        val appSecret: String
    )
    
    private val environments = mapOf(
        Environment.DEVELOPMENT to EnvConfig(
            name = "development",
            displayName = "US Production Environment",
            baseUrl = "https://platform.plaud.ai",
            appKey = "plaud-rVDQilOD-1749538697969",
            appSecret = "aksk_3OWsepikIeI3EGsaPSmUUf5TAaNSktEh"
        ),
        Environment.TEST to EnvConfig(
            name = "test",
            displayName = "Common Test Environment", 
            baseUrl = "https://platform-beta.plaud.ai",
            appKey = "plaud-4K5x9xLR-1753174087583",
            appSecret = "aksk_2FYowKzT1b44kxb8gATiuGyEgHzEzY8Y"
        ),
        Environment.PRODUCTION to EnvConfig(
            name = "production",
            displayName = "China Production Environment",
            baseUrl = "https://platform.plaud.cn",
            appKey = "plaud-zoem8KYd-1748487531106", 
            appSecret = "aksk_hAyGDINVTsG3vsob2Shqku3iBqgI7clL"
        )
    )
    
    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    fun getCurrentEnvironment(context: Context): Environment {
        val prefs = getPrefs(context)
        val envName = prefs.getString(KEY_CURRENT_ENV, Environment.TEST.name)
        return try {
            Environment.valueOf(envName ?: Environment.TEST.name)
        } catch (e: IllegalArgumentException) {
            Environment.TEST
        }
    }
    
    fun setCurrentEnvironment(context: Context, environment: Environment) {
        val prefs = getPrefs(context)
        prefs.edit().putString(KEY_CURRENT_ENV, environment.name).apply()
    }
    
    fun getCurrentConfig(context: Context): EnvConfig {
        val currentEnv = getCurrentEnvironment(context)
        return environments[currentEnv] ?: environments[Environment.TEST]!!
    }
    
    fun getAllEnvironments(): List<EnvConfig> {
        return environments.values.toList()
    }
}

class PlaudEnvironmentModule(reactContext: ReactApplicationContext) : 
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        private const val MODULE_NAME = "PlaudEnvironmentModule"
    }

    override fun getName(): String = MODULE_NAME

    @ReactMethod
    fun getCurrentEnvironment(promise: Promise) {
        try {
            val config = PlaudEnvironmentConfig.getCurrentConfig(reactApplicationContext)
            val result = Arguments.createMap().apply {
                putString("name", config.name)
                putString("displayName", config.displayName)
                putString("baseUrl", config.baseUrl)
                putString("appKey", config.appKey)
                putString("appSecret", config.appSecret)
            }
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("GET_ENV_FAILED", e.message, e)
        }
    }
    
    @ReactMethod
    fun getAllEnvironments(promise: Promise) {
        try {
            val environments = PlaudEnvironmentConfig.getAllEnvironments()
            val result = Arguments.createArray()
            
            environments.forEach { config ->
                val envMap = Arguments.createMap().apply {
                    putString("name", config.name)
                    putString("displayName", config.displayName)
                    putString("baseUrl", config.baseUrl)
                    putString("appKey", config.appKey)
                    putString("appSecret", config.appSecret)
                }
                result.pushMap(envMap)
            }
            
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("GET_ENVS_FAILED", e.message, e)
        }
    }
    
    @ReactMethod
    fun setEnvironment(envName: String, promise: Promise) {
        try {
            val environment = when (envName.lowercase()) {
                "development", "dev" -> PlaudEnvironmentConfig.Environment.DEVELOPMENT
                "test" -> PlaudEnvironmentConfig.Environment.TEST
                "production", "prod" -> PlaudEnvironmentConfig.Environment.PRODUCTION
                else -> {
                    promise.reject("INVALID_ENV", "Invalid environment name: $envName")
                    return
                }
            }
            
            PlaudEnvironmentConfig.setCurrentEnvironment(reactApplicationContext, environment)
            
            val config = PlaudEnvironmentConfig.getCurrentConfig(reactApplicationContext)
            val result = Arguments.createMap().apply {
                putBoolean("success", true)
                putString("message", "Environment switched to ${config.displayName}")
                putString("name", config.name)
                putString("displayName", config.displayName)
                putString("baseUrl", config.baseUrl)
            }
            
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("SET_ENV_FAILED", e.message, e)
        }
    }
}

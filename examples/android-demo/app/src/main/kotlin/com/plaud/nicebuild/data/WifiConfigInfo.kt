package com.plaud.nicebuild.data

/**
 * WiFi configuration information returned by device
 * Corresponds to WifiConfigInfoEntity in reference project
 */
data class WifiConfigInfo(
    val wifiName: String?,
    val wifiPass: String?,
    val isSuccess: Boolean = false,
    val errorMessage: String? = null
) {
    companion object {
        fun success(wifiName: String, wifiPass: String): WifiConfigInfo {
            return WifiConfigInfo(wifiName, wifiPass, true)
        }

        fun error(message: String): WifiConfigInfo {
            return WifiConfigInfo(null, null, false, message)
        }
    }
}
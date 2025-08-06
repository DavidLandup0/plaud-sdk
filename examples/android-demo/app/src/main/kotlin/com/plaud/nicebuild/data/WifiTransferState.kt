package com.plaud.nicebuild.data

/**
 * WiFi transfer states corresponding to the reference project's DeviceWiFiState
 */
enum class WifiTransferState(val value: Int) {
    NONE(0),
    TURNING_ON(1),
    ON(2),
    WIFI_CONNECTED(3),
    DEVICE_CONNECTED(4),
    DEVICE_DISCONNECTED(5),
    ERROR(-1);

    companion object {
        fun getByValue(value: Int): WifiTransferState {
            return values().find { it.value == value } ?: ERROR
        }
    }
}
package com.plaud.nicebuild.data

/**
 * WiFi transfer types corresponding to reference project's TransferType
 */
enum class WifiTransferType {
    NONE,       // Initial state
    CHECK,      // Checking prerequisites 
    CONNECT,    // Connecting to device WiFi
    RUNNING,    // File transfer in progress
    COMPLETED,  // Transfer completed
    ERROR       // Error occurred
}
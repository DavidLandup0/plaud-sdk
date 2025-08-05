package com.plaud.nicebuild.utils

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment

/**
 * WiFi Transfer Permissions - Handles all permission checks and requests for WiFi transfer
 * Based on Android standards and reference project requirements
 */
object WifiTransferPermissions {
    private const val TAG = "WifiTransferPermissions"
    
    /**
     * Required permissions for WiFi transfer
     * Only includes permissions that require user authorization
     */
    private val REQUIRED_PERMISSIONS = arrayOf(
        // Location permissions (required for WiFi scanning on Android 6+)
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION
    ).let { permissions ->
        val permissionsList = permissions.toMutableList()
        
        // Add storage permission for Android 10 and below
        // For Android 11+, storage permission is handled separately
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            permissionsList.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        
        // Add Android 13+ specific permissions if available
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                // NEARBY_WIFI_DEVICES permission for Android 13+
//                permissionsList.add(Manifest.permission.NEARBY_WIFI_DEVICES)
            } catch (e: Exception) {
                // Permission doesn't exist in this build, use original array
                Log.w(TAG, "NEARBY_WIFI_DEVICES permission not available: ${e.message}")
            }
        }
        
        permissionsList.toTypedArray()
    }
    
    /**
     * Permissions that are automatically granted (normal permissions)
     * These don't require user authorization but are needed for functionality
     */
    private val NORMAL_PERMISSIONS = arrayOf(
        Manifest.permission.ACCESS_WIFI_STATE,
        Manifest.permission.CHANGE_WIFI_STATE,
        Manifest.permission.ACCESS_NETWORK_STATE,
        Manifest.permission.CHANGE_NETWORK_STATE,
        Manifest.permission.INTERNET
    )
    
    /**
     * Check if all required permissions are granted for WiFi transfer
     * Reuses existing permission checking logic
     */
    fun hasAllPermissions(context: Context): Boolean {
        // Check normal permissions (automatically granted)
        val normalPermissionsGranted = NORMAL_PERMISSIONS.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
        
        // Check location permissions (same as scan requirements)
        val locationPermissionsGranted = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ).all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
        
        // Check Android 13+ WiFi permissions if applicable
        val wifiDevicePermissionGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                ContextCompat.checkSelfPermission(context, Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED
            } catch (e: Exception) {
                true // Permission doesn't exist, consider it granted
            }
        } else {
            true // Not applicable for older versions
        }
        
        // Check storage permission (same as file list requirements)
        val storagePermissionGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
        
        // Check WRITE_SETTINGS permission (required for WiFi network modification on Android Q+)
        val writeSettingsPermissionGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Settings.System.canWrite(context)
        } else {
            true // Not required for older versions
        }
        
        return normalPermissionsGranted && locationPermissionsGranted && wifiDevicePermissionGranted && storagePermissionGranted && writeSettingsPermissionGranted
    }
    
    /**
     * Get list of missing permissions that require user authorization
     * Normal permissions are automatically granted and don't need to be requested
     */
    fun getMissingPermissions(context: Context): List<String> {
        return REQUIRED_PERMISSIONS.filter { permission ->
            ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED
        }
    }
    
    /**
     * Check if normal permissions are available
     * These should always be granted but we can verify
     */
    fun hasNormalPermissions(context: Context): Boolean {
        return NORMAL_PERMISSIONS.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    /**
     * Check if WiFi is enabled
     */
    fun isWifiEnabled(context: Context): Boolean {
        return try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiManager.isWifiEnabled
        } catch (e: Exception) {
            Log.e(TAG, "Error checking WiFi state: ${e.message}", e)
            false
        }
    }
    
    /**
     * Check if location services are enabled
     */
    fun isLocationEnabled(context: Context): Boolean {
        return try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                    locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking location state: ${e.message}", e)
            false
        }
    }
    
    /**
     * Get permission names in a readable format
     */
    fun getPermissionDisplayNames(permissions: List<String>): List<String> {
        return permissions.map { permission ->
            when {
                permission.contains("WIFI") -> "WiFi access"
                permission.contains("LOCATION") -> "Location services"
                permission.contains("STORAGE") -> "Storage access"
                permission.contains("NEARBY_WIFI_DEVICES") -> "Nearby WiFi devices"
                else -> permission.substringAfterLast(".")
            }
        }
    }
    
    /**
     * Open WiFi settings
     */
    fun openWifiSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening WiFi settings: ${e.message}", e)
        }
    }
    
    /**
     * Open location settings
     */
    fun openLocationSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening location settings: ${e.message}", e)
        }
    }
    
    /**
     * Open app settings
     */
    fun openAppSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", context.packageName, null)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app settings: ${e.message}", e)
        }
    }
    
    /**
     * Check if WRITE_SETTINGS permission is granted (required for Android Q+)
     */
    fun hasWriteSettingsPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Settings.System.canWrite(context)
        } else {
            true // Not required for older versions
        }
    }
    
    /**
     * Open WRITE_SETTINGS permission settings
     */
    fun openWriteSettingsPermission(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening write settings permission: ${e.message}", e)
            // Fallback to general app settings
            openAppSettings(context)
        }
    }
    
    /**
     * Comprehensive pre-transfer check
     */
    fun checkTransferPrerequisites(context: Context): TransferPrerequisiteResult {
        val missingPermissions = getMissingPermissions(context)
        val wifiEnabled = isWifiEnabled(context)
        val locationEnabled = isLocationEnabled(context)
        val writeSettingsPermission = hasWriteSettingsPermission(context)
        
        return TransferPrerequisiteResult(
            hasAllPermissions = missingPermissions.isEmpty(),
            missingPermissions = missingPermissions,
            isWifiEnabled = wifiEnabled,
            isLocationEnabled = locationEnabled,
            hasWriteSettingsPermission = writeSettingsPermission,
            canProceed = missingPermissions.isEmpty() && wifiEnabled && locationEnabled && writeSettingsPermission
        )
    }
    
    /**
     * Data class for prerequisite check result
     */
    data class TransferPrerequisiteResult(
        val hasAllPermissions: Boolean,
        val missingPermissions: List<String>,
        val isWifiEnabled: Boolean,
        val isLocationEnabled: Boolean,
        val hasWriteSettingsPermission: Boolean,
        val canProceed: Boolean
    ) {
        fun getErrorMessage(): String? {
            return when {
                !hasAllPermissions -> "Missing permissions: ${missingPermissions.joinToString()}"
                !isWifiEnabled -> "WiFi is not enabled"
                !isLocationEnabled -> "Location services are not enabled"
                !hasWriteSettingsPermission -> "System settings modification permission is required"
                else -> null
            }
        }
    }
}
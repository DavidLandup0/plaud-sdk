package com.reactnativedemo.plaud

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.facebook.react.modules.permissions.PermissionsModule

class PlaudPermissionModule(reactContext: ReactApplicationContext) : 
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        private const val TAG = "PlaudPermissionModule"
        private const val MODULE_NAME = "PlaudPermissionModule"
    }

    override fun getName(): String = MODULE_NAME

    @ReactMethod
    fun checkPermissions(promise: Promise) {
        try {
            val context = reactApplicationContext
            val requiredPermissions = getRequiredPermissions()
            val permissionStatus = mutableMapOf<String, Boolean>()
            
            for (permission in requiredPermissions) {
                val isGranted = ContextCompat.checkSelfPermission(context, permission) == 
                    PackageManager.PERMISSION_GRANTED
                permissionStatus[permission] = isGranted
            }
            
            val result = Arguments.createMap().apply {
                putBoolean("allGranted", permissionStatus.values.all { it })
                
                // Detailed permission status
                putBoolean("bluetooth", checkBluetoothPermissions())
                putBoolean("location", checkLocationPermissions())
                putBoolean("audio", checkAudioPermissions())
                putBoolean("storage", checkStoragePermissions())
            }
            
            promise.resolve(result)
            
        } catch (e: Exception) {
            promise.reject("PERMISSION_CHECK_FAILED", e.message, e)
        }
    }
    
    @ReactMethod
    fun requestPermissions(promise: Promise) {
        try {
            // Simplify permission request, let frontend use React Native's PermissionsAndroid
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
                putString("message", "Please use PermissionsAndroid in JavaScript for better compatibility")
            })
        } catch (e: Exception) {
            promise.reject("PERMISSION_REQUEST_FAILED", e.message, e)
        }
    }

    private fun getRequiredPermissions(): List<String> {
        val permissions = mutableListOf<String>()
        
        // Basic Bluetooth permissions
        permissions.addAll(listOf(
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ))
        
        // Android 12+ Bluetooth permissions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.addAll(listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE
            ))
        }
        
        // Audio recording permission
        permissions.add(Manifest.permission.RECORD_AUDIO)
        
        // Storage permissions
        permissions.addAll(listOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ))
        
        return permissions
    }
    
    private fun checkBluetoothPermissions(): Boolean {
        val context = reactApplicationContext
        val basicBluetooth = listOf(
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN
        ).all { 
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED 
        }
        
        val android12Bluetooth = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            ).all { 
                ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED 
            }
        } else true
        
        return basicBluetooth && android12Bluetooth
    }
    
    private fun checkLocationPermissions(): Boolean {
        val context = reactApplicationContext
        return listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ).all { 
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED 
        }
    }
    
    private fun checkAudioPermissions(): Boolean {
        val context = reactApplicationContext
        return ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun checkStoragePermissions(): Boolean {
        val context = reactApplicationContext
        return listOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ).all { 
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED 
        }
    }
}

package com.reactnativedemo.plaud

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class PlaudReactPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        return listOf(
            PlaudSDKModule(reactContext),
            PlaudBluetoothModule(reactContext),
            PlaudRecordingModule(reactContext),
            PlaudFileManagerModule(reactContext),
            PlaudUploadModule(reactContext),
            PlaudPermissionModule(reactContext),
            PlaudEnvironmentModule(reactContext)
        )
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return emptyList()
    }
}

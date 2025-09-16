package com.plaud.nicebuild.viewmodel

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.plaud.nicebuild.R
import com.plaud.nicebuild.ble.BleCore
import com.plaud.nicebuild.ble.BleManager
import com.plaud.nicebuild.data.WifiCacheManager
import com.plaud.nicebuild.manager.WifiManager
import com.plaud.nicebuild.utils.WifiTransferPermissions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import sdk.NiceBuildSdk
import sdk.network.manager.S3UploadManager
import sdk.penblesdk.core.IWifiAgent
import sdk.penblesdk.entity.BleDevice
import sdk.penblesdk.entity.BleFile
import sdk.penblesdk.entity.bean.ble.response.GetWifiInfoRsp
import java.io.File
import java.util.TimeZone
import kotlinx.coroutines.withTimeoutOrNull
import sdk.network.model.WorkflowResultResponse
import sdk.network.model.WorkflowStatusResponse
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val _deviceList = MutableLiveData<List<BleDevice>>(emptyList())
    val deviceList: LiveData<List<BleDevice>> = _deviceList

    private val _currentDevice = MutableLiveData<BleDevice?>()
    val currentDevice: LiveData<BleDevice?> = _currentDevice

    private val _fileList = MutableLiveData<List<BleFile>>(emptyList())
    val fileList: LiveData<List<BleFile>> = _fileList

    private val _wifiList = MutableLiveData<List<GetWifiInfoRsp>>(emptyList())
    val wifiList: LiveData<List<GetWifiInfoRsp>> = _wifiList

    private val _isLoading = MutableLiveData<Boolean>()
    val isLoading: LiveData<Boolean> = _isLoading

    private val _workflowStatus = MutableLiveData<WorkflowStatusResponse?>()
    val workflowStatus: LiveData<WorkflowStatusResponse?> = _workflowStatus

    private val _workflowResult = MutableLiveData<WorkflowResultResponse?>()
    val workflowResult: LiveData<WorkflowResultResponse?> = _workflowResult

    private val bleManager = BleManager.getInstance(application) // UI-aware manager
    private val bleCore = BleCore.getInstance(application)   // Pure data agent
    private val s3UploadManager: S3UploadManager by lazy { NiceBuildSdk.s3UploadManager }
    private val appContext = application.applicationContext
    

    // WiFi transfer manager - for WiFi fast transfer functionality
    private val wifiManager by lazy { WifiManager.getInstance(appContext) }
    

    private val _connectionStatus = MutableLiveData<String>(appContext.getString(R.string.status_not_connected))
    val connectionStatus: LiveData<String> = _connectionStatus
    
    private val _recordingStatus = MutableLiveData<String>(appContext.getString(R.string.status_not_recording))
    val recordingStatus: LiveData<String> = _recordingStatus
    
    private val _batteryLevel = MutableLiveData<Int>(0)
    val batteryLevel: LiveData<Int> = _batteryLevel
    
    private val _toastMessage = MutableLiveData<String>()
    val toastMessage: LiveData<String> = _toastMessage
    

    // Audio parameters
    private val OPUS_FRAME_SIZE_MONO = 80
    private val OPUS_FRAME_DURATION_MS = 20
    

    /**
     * Convert byte position to time position (seconds)
     */
    private fun bytesToSeconds(bytePosition: Long): Double {
        val framesCount = bytePosition / OPUS_FRAME_SIZE_MONO
        return (framesCount * OPUS_FRAME_DURATION_MS) / 1000.0
    }


    fun setLoading(loading: Boolean) {
        _isLoading.postValue(loading)
    }

    fun updateDeviceList(list: List<BleDevice>) {
        _deviceList.postValue(list)
    }

    fun setCurrentDevice(device: BleDevice?) {
        _currentDevice.value = device
    }

    fun updateFileList(list: List<BleFile>) {
        _fileList.postValue(list)
    }

    fun uploadFile(
        opusFile: File,
        bleFile: BleFile,
        onProgress: (Float) -> Unit,
        onResult: (Boolean, String?, String?) -> Unit // success, errorMessage, fileId
    ) {
        val sn = currentDevice.value?.serialNumber ?: "Unknown"
        s3UploadManager.uploadFileAsync(
            filePath = opusFile.absolutePath,
            fileSize = opusFile.length(),
            fileType = "opus",
            snType = "notepin",
            sn = sn,
            startTime = bleFile.startTime,  // Use BleFile's new method
            endTime = bleFile.endTime,      // Use BleFile's new method
            timezone = TimeZone.getDefault().rawOffset / 3600000,
            zoneMins = (TimeZone.getDefault().rawOffset % 3600000) / 60000,
            onProgress = onProgress,
            onSuccess = { fileId ->
                onResult(true, null, fileId)
            },
            onError = { exception ->
                Log.e("MainViewModel", "Upload failed", exception)
                onResult(false, exception.message, null)
            }
        )
        Log.d("MainViewModel", "startTime:${bleFile.startTime},endTime:${bleFile.endTime}")

        /*
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val sn = currentDevice.value?.serialNumber ?: "Unknown"

                val fileId = s3UploadManager.uploadFile(
                    filePath = opusFile.absolutePath,
                    fileSize = opusFile.length(),
                    fileType = "opus",
                    snType = "notepin",
                    sn = sn,
                    startTime = bleFile.sessionId,
                    endTime = bleFile.endTime, // Placeholder
                    timezone = TimeZone.getDefault().rawOffset / 3600000,
                    zoneMins = (TimeZone.getDefault().rawOffset % 3600000) / 60000,
                    onProgress = onProgress
                )

                launch(Dispatchers.Main) { onResult(true, null, fileId) }

            } catch (e: Exception) {
                Log.e("MainViewModel", "Upload failed", e)
                launch(Dispatchers.Main) { onResult(false, e.message, null) }
            }
        }
        */
    }

    fun submit(fileId: String, onResult: (workflowId: String?, success: Boolean, message: String) -> Unit) {
        viewModelScope.launch {
            val response = NiceBuildSdk.submit(fileId)
            if (response != null) {
                val message = "Status: ${response.status}"
                onResult(response.id, true, message)
            } else {
                onResult(null, false, "Submit failed: Response was null")
            }
        }
    }

    fun getWorkflowStatus(workflowId: String) {
        viewModelScope.launch {
            try {
                withTimeout(60_000_000L) {
                    while (isActive) {
                        val statusResponse = NiceBuildSdk.getWorkflowStatus(workflowId)

                        if (statusResponse == null) {
                            _workflowStatus.postValue(null)
                            break
                        }

                        when {
                            statusResponse.status.equals("SUCCESS", ignoreCase = true) ||
                                    statusResponse.status.equals("FAILURE", ignoreCase = true) -> {
                                val resultResponse = NiceBuildSdk.getWorkflowResult(workflowId)
                                if (statusResponse.status.equals("SUCCESS", ignoreCase = true)) {
                                    _workflowResult.postValue(resultResponse)
                                }
                                break
                            }

                            statusResponse.status.equals("PROGRESS", ignoreCase = true) ||
                                    statusResponse.status.equals("PENDING", ignoreCase = true) -> {
                                _workflowStatus.postValue(statusResponse)
                                delay(5_000L)
                            }

                            else -> {
                                _workflowStatus.postValue(statusResponse)
                                break
                            }
                        }
                    }
                }
            } catch (e: TimeoutCancellationException) {
                val timeoutResponse = WorkflowStatusResponse(
                    id = workflowId,
                    status = "TIMEOUT",
                    totalTasks = 0,
                    completedTasks = 0,
                    startTime = 0,
                    updateTime = 0,
                    endTime = 0
                )
                _workflowStatus.postValue(timeoutResponse)
            }
        }
    }

    fun loadWifiList() {
        viewModelScope.launch(Dispatchers.IO) {
            val cachedList = WifiCacheManager.getWifiListFromCache(appContext)
            _wifiList.postValue(cachedList.sortedBy { it.getSSID() })

            bleCore.getWifiList { rsp ->
                viewModelScope.launch(Dispatchers.IO) {
                    val newWifiIds = rsp?.list?.map { it.toLong() } ?: emptyList()
                    val cachedWifiIds = cachedList.map { it.getWifiIndex() }

                    val idsToRemove = cachedWifiIds.filter { it !in newWifiIds }
                    if (idsToRemove.isNotEmpty()) {
                        val currentCache = WifiCacheManager.getWifiListFromCache(appContext)
                        currentCache.removeAll { it.getWifiIndex() in idsToRemove }
                        WifiCacheManager.saveWifiListToCache(appContext, currentCache)
                        _wifiList.postValue(currentCache.sortedBy { it.getSSID() })
                    }

                    newWifiIds.forEach { wifiId ->
                        val info = withTimeoutOrNull(3000L) {
                            suspendCoroutine<GetWifiInfoRsp?> { continuation ->
                                bleCore.getWifiInfo(wifiId.toInt()) { infoResult ->
                                    if (continuation.context.isActive) {
                                        continuation.resume(infoResult)
                                    }
                                }
                            }
                        }
                        if (info != null) {
                            WifiCacheManager.addOrUpdateWifiInCache(appContext, info)
                        }
                    }

                    val finalList = WifiCacheManager.getWifiListFromCache(appContext)
                    _wifiList.postValue(finalList.sortedBy { it.getSSID() })
                }
            }
        }
    }

    fun setWifi(
        operation: Int,
        ssid: String,
        pwd: String,
        wifiIndex: Int,
        callback: (Boolean) -> Unit
    ) {
        _isLoading.postValue(true)
        bleManager.setWifi(operation, ssid, pwd, wifiIndex) { success ->
            _isLoading.postValue(false)
            callback(success)
        }
    }

    fun deleteWifi(wifiIndex: Int, callback: (Boolean) -> Unit) {
        _isLoading.postValue(true)
        bleManager.deleteWifi(wifiIndex) { success ->
            _isLoading.postValue(false)
            callback(success)
        }
    }

    fun clearWifiCache() {
        WifiCacheManager.clearCache(appContext)
        _wifiList.postValue(emptyList())
    }
    

    /**
     * Start WiFi fast transfer with progress dialog
     */
    fun startWifiTransfer(lifecycleOwner: LifecycleOwner) {
        viewModelScope.launch {
            try {
                _isLoading.postValue(true)
                
                // Get user ID (use device serial number as fallback)
                val userId = currentDevice.value?.serialNumber ?: "anonymous_user"
                
                Log.i("MainViewModel", "Starting WiFi transfer for user: $userId")
                
                val result = wifiManager.startWifiTransfer(userId)
                
                if (result) {
                    Log.i("MainViewModel", "WiFi transfer started successfully")
                } else {
                    Log.e("MainViewModel", "WiFi transfer failed to start")
                }
                
            } catch (e: Exception) {
                Log.e("MainViewModel", "Error starting WiFi transfer: ${e.message}", e)
            } finally {
                _isLoading.postValue(false)
            }
        }
    }
    
    /**
     * Download all files via WiFi transfer
     */
    fun downloadAllFiles() {
        if (wifiManager.connectionState.value == IWifiAgent.WifiConnectionState.READY) {
            val success = wifiManager.downloadAllFiles()
            if (!success) {
                _toastMessage.postValue(appContext.getString(R.string.wifi_batch_download_failed_start))
            }
        } else {
            _toastMessage.postValue(appContext.getString(R.string.wifi_not_ready))
        }
    }

    // Expose batch download status and wifi manager
    val batchDownloadStatus = wifiManager.batchDownloadStatus
    val wifiConnectionState = wifiManager.connectionState
    
    /**
     * Check if WiFi transfer is available
     */
    fun isWifiTransferAvailable(): Boolean {
        val prerequisiteResult = WifiTransferPermissions.checkTransferPrerequisites(appContext)
        return prerequisiteResult.canProceed && bleCore.isConnected()
    }
    
    /**
     * Get WiFi transfer state
     */
    fun getWifiTransferState() = wifiManager.connectionState
    
    /**
     * Get WiFi transfer progress
     */
    fun getWifiTransferProgress() = wifiManager.transferProgress
    


    override fun onCleared() {
        super.onCleared()
    }
}
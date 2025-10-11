package com.plaud.nicebuild.manager

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import sdk.NiceBuildSdk
import sdk.penblesdk.entity.BleDevice
import com.plaud.nicebuild.data.*
import com.plaud.nicebuild.R
import com.plaud.nicebuild.utils.LocaleHelper
import sdk.penblesdk.TntAgent
import sdk.penblesdk.entity.AgentCallback
import sdk.penblesdk.impl.ble.BleAgentImpl
import sdk.penblesdk.utils.SimpleFirmwareTransfer
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlin.coroutines.suspendCoroutine
import kotlin.coroutines.resume
import kotlin.math.min

/**
 * 固件更新管理器
 * 负责检查更新、下载固件、安装固件的核心逻辑
 */
class FirmwareUpdateManager private constructor(private val context: Context) {
    
    // 获取正确语言设置的Context
    private val localizedContext: Context by lazy {
        LocaleHelper.onAttach(context)
    }
    
    companion object {
        private const val TAG = "FirmwareUpdateManager"
        
        @Volatile
        private var INSTANCE: FirmwareUpdateManager? = null
        
        fun getInstance(context: Context): FirmwareUpdateManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: FirmwareUpdateManager(context.applicationContext).also { INSTANCE = it }
            }
        }

        fun calculateSnType(sn: String): String {
            return if (sn.length >= 3) {
                val prefix = sn.substring(0, 3)
                when (prefix) {
                    "880" -> "notepin"
                    "888" -> "note"
                    else -> "notepin"
                }
            } else {
                "notepin"
            }
        }

        /**
         * 获取期望的设备类型描述
         */
        private fun getExpectedDeviceType(snType: String): String {
            return when (snType) {
                "notepin" -> "Plaud NOTE Pin 设备"
                "note" -> "Plaud NOTE 设备"
                else -> "未知设备类型"
            }
        }

        /**
         * 验证版本格式是否有效
         */
        private fun isValidVersionFormat(version: String): Boolean {
            if (version.isBlank()) return false
            
            // 检查是否符合 V + 4位数字的格式，如 V1012
            val pattern = Regex("^[VT]\\d{4}$")
            return pattern.matches(version)
        }

        /**
         * 检查是否为版本降级
         */
        private fun isVersionDowngrade(currentVersion: String, targetVersion: String): Boolean {
            try {
                // 提取版本号数字部分
                val currentNum = currentVersion.substring(1).toIntOrNull() ?: 0
                val targetNum = targetVersion.substring(1).toIntOrNull() ?: 0
                
                return targetNum < currentNum
            } catch (e: Exception) {
                return false
            }
        }
    }
    
    private var currentJob: Job? = null
    private var callback: FirmwareUpdateCallback? = null
    private var currentProgress: Int = 0  // 跟踪当前安装进度
    
    /**
     * 检查固件更新
     * @param device 当前连接的设备
     * @param callback 更新回调
     */
    fun checkForUpdate(device: BleDevice, callback: FirmwareUpdateCallback) {
        this.callback = callback
        
        currentJob?.cancel()
        currentJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.i(TAG, "开始检查固件更新 - 设备: ${device.serialNumber}")
                
                // 获取设备模型和类型
                val model = try {
                    device.serialNumber.substring(0, 3)
                } catch (e: Exception) {
                    device.projectCode.toString()
                }
                
                val snType = calculateSnType(device.serialNumber)
                val currentVersion = device.versionName ?: "未知"
                
                Log.i(TAG, "设备信息: 型号=$model, 类型=$snType, 当前版本=$currentVersion")
                
                // 调用SDK API检查最新版本
                val versionResponse = NiceBuildSdk.getLatestDeviceVersionNew(
                    snType = snType,
                    model = model,
                    versionType = "V"
                )
                
                withContext(Dispatchers.Main) {
                    if (versionResponse != null) {
                        val updateInfo = FirmwareUpdateInfo.from(
                            versionResponse = versionResponse,
                            currentVersion = currentVersion
                        )
                        Log.i(TAG, "更新检查完成: $currentVersion -> ${updateInfo.versionResponse.versionNumber}, 有更新=${updateInfo.hasUpdate}")
                        callback.onUpdateCheckResult(Result.success(updateInfo))
                    } else {
                        Log.e(TAG, "更新检查失败: API返回null")
                        callback.onUpdateCheckResult(Result.failure(Exception(localizedContext.getString(R.string.firmware_update_error_network_connection))))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "更新检查异常: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    callback.onUpdateCheckResult(Result.failure(e))
                }
            }
        }
    }
    
    /**
     * 阶段1: 下载固件文件
     * @param updateInfo 固件更新信息
     * @param callback 更新回调
     */
    fun downloadFirmware(updateInfo: FirmwareUpdateInfo, callback: FirmwareUpdateCallback) {
        this.callback = callback
        
        currentJob?.cancel()
        currentJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                val downloadUrl = updateInfo.versionResponse.downloadUrl
                val expectedMd5 = updateInfo.versionResponse.fileMd5
                val fileName = "firmware_${updateInfo.versionResponse.versionCode}.bin"
                
                Log.i(TAG, "【阶段1-下载】开始下载固件: ${updateInfo.versionResponse.versionCode}")
                
                // 创建下载目录
                val downloadDir = File(context.filesDir, "firmware_downloads")
                if (!downloadDir.exists()) {
                    downloadDir.mkdirs()
                }
                
                val downloadFile = File(downloadDir, fileName)
                
                // 检查文件是否已存在且MD5匹配
                if (downloadFile.exists()) {
                    val existingMd5 = calculateMD5(downloadFile)
                    if (existingMd5.equals(expectedMd5, ignoreCase = true)) {
                        Log.i(TAG, "【阶段1-跳过】固件已存在且校验通过，跳过下载")
                        withContext(Dispatchers.Main) {
                            val downloadCompleteMessage = localizedContext.getString(R.string.firmware_update_download_complete)
                            callback.onDownloadProgress(UpdateProgress(100, downloadCompleteMessage, ""))
                            callback.onDownloadComplete(
                                FirmwareDownloadResult(
                                    success = true,
                                    file = downloadFile,
                                    md5Valid = true
                                )
                            )
                        }
                        return@launch
                    } else {
                        Log.i(TAG, "【阶段1-重下】固件文件MD5校验失败，重新下载")
                        downloadFile.delete()
                    }
                }
                
                // 开始下载
                val result = downloadFileWithProgress(downloadUrl, downloadFile, expectedMd5) { progress, message ->
                    CoroutineScope(Dispatchers.Main).launch {
                        val downloadingMessage = localizedContext.getString(R.string.firmware_update_downloading_progress)
                        callback.onDownloadProgress(UpdateProgress(progress, downloadingMessage, message))
                    }
                }
                
                withContext(Dispatchers.Main) {
                    if (result.success) {
                        Log.i(TAG, "【阶段1-完成】固件下载成功, 文件大小: ${downloadFile.length()} bytes")
                    } else {
                        Log.e(TAG, "【阶段1-失败】固件下载失败: ${result.error}")
                    }
                    callback.onDownloadComplete(result)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "【阶段1-异常】下载固件异常: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    callback.onDownloadComplete(
                        FirmwareDownloadResult(
                            success = false,
                            error = e.message ?: localizedContext.getString(R.string.firmware_update_error_download_failed)
                        )
                    )
                }
            }
        }
    }
    
    /**
     * 阶段2-4: 安装固件到设备（包含传输、重启、结果获取）
     * @param firmwareFile 固件文件
     * @param device 目标设备
     * @param updateInfo 固件更新信息
     * @param callback 更新回调
     */
    fun installFirmware(firmwareFile: File, device: BleDevice, updateInfo: FirmwareUpdateInfo, callback: FirmwareUpdateCallback) {
        this.callback = callback
        
        currentJob?.cancel()
        currentJob = CoroutineScope(Dispatchers.IO).launch {
            try {
                // 重置当前进度
                currentProgress = 0
                
                val currentVersion = updateInfo.currentVersion ?: device.versionName ?: "V0000"
                val targetVersion = updateInfo.versionResponse.versionCode
                
                Log.i(TAG, "【阶段2-安装】开始固件安装: $currentVersion -> $targetVersion")
                Log.i(TAG, "【阶段2-安装】文件: ${firmwareFile.name}, 大小: ${firmwareFile.length()} bytes")
                
                withContext(Dispatchers.Main) {
                    val preparingMessage = localizedContext.getString(R.string.firmware_update_install_preparing)
                    callback.onInstallProgress(UpdateProgress(0, preparingMessage, ""))
                }
                
                // 初始化检查
                val tntAgent = TntAgent.getInstant()
                if (tntAgent == null) {
                    Log.e(TAG, "【阶段2-错误】TntAgent未初始化")
                    withContext(Dispatchers.Main) {
                        callback.onInstallComplete(
                            FirmwareInstallResult(
                                success = false,
                                error = localizedContext.getString(R.string.firmware_update_error_sdk_not_initialized)
                            )
                        )
                    }
                    return@launch
                }
                
                val bleAgent = tntAgent.getBleAgent() as? BleAgentImpl
                if (bleAgent == null) {
                    Log.e(TAG, "【阶段2-错误】BLE代理未初始化或类型不正确")
                    withContext(Dispatchers.Main) {
                        callback.onInstallComplete(
                            FirmwareInstallResult(
                                success = false,
                                error = localizedContext.getString(R.string.firmware_update_error_agent_not_initialized)
                            )
                        )
                    }
                    return@launch
                }
                
                // 检查设备状态
                if (!bleAgent.isConnected()) {
                    Log.e(TAG, "【阶段2-错误】设备未连接")
                    withContext(Dispatchers.Main) {
                        callback.onInstallComplete(
                            FirmwareInstallResult(
                                success = false,
                                error = localizedContext.getString(R.string.firmware_update_error_device_not_connected)
                            )
                        )
                    }
                    return@launch
                }
                
                if (bleAgent.isFotaPushing()) {
                    Log.w(TAG, "【阶段2-警告】固件传输已在进行中")
                    withContext(Dispatchers.Main) {
                        callback.onInstallComplete(
                            FirmwareInstallResult(
                                success = false,
                                error = localizedContext.getString(R.string.firmware_update_error_transfer_in_progress)
                            )
                        )
                    }
                    return@launch
                }
                
                // 版本验证
                if (!isValidVersionFormat(currentVersion) || !isValidVersionFormat(targetVersion)) {
                    Log.e(TAG, "【阶段2-错误】版本格式无效: $currentVersion -> $targetVersion")
                    withContext(Dispatchers.Main) {
                        callback.onInstallComplete(
                            FirmwareInstallResult(
                                success = false,
                                error = "固件版本格式错误"
                            )
                        )
                    }
                    return@launch
                }
                
                if (isVersionDowngrade(currentVersion, targetVersion)) {
                    Log.w(TAG, "【阶段2-警告】检测到版本降级: $currentVersion -> $targetVersion")
                }
                
                val snType = calculateSnType(device.serialNumber ?: "")
                Log.i(TAG, "【阶段2-就绪】设备类型: $snType")
                
                // 开始固件传输流程
                val firmwareTransferCompleted = suspendCoroutine<Boolean> { continuation ->
                    // 设置5分钟超时
                    val timeoutHandler = android.os.Handler(android.os.Looper.getMainLooper())
                    val timeoutRunnable = Runnable {
                        Log.e(TAG, "【升级超时】固件升级超时，结束流程")
                        callback.onInstallProgress(UpdateProgress.upgradeFailed("升级超时", "升级过程超过5分钟"))
                        continuation.resume(false)
                    }
                    timeoutHandler.postDelayed(timeoutRunnable, 5 * 60 * 1000)
                    
                    // 安全的continuation回调，避免重复调用
                    var isCompleted = false
                    val safeContinuation = object {
                        fun resume(value: Boolean) {
                            if (!isCompleted) {
                                isCompleted = true
                                timeoutHandler.removeCallbacks(timeoutRunnable)
                                continuation.resume(value)
                            } else {
                                Log.w(TAG, "【重复完成】尝试重复完成升级过程，已忽略")
                            }
                        }
                    }
                    
                    bleAgent.appFotaPush(
                        firmwareFile.absolutePath,
                        currentVersion,
                        targetVersion,
                        0,
                        object : AgentCallback.BleAgentOtaPushListener {
                            override fun otaPushProgress(progress: Double) {
                                val percent = progress.toInt()
                                currentProgress = percent
                                
                                // 仅在重要进度节点记录日志
                                if (percent % 20 == 0 || percent == 100) {
                                    Log.i(TAG, "【阶段2-传输】进度: $percent%")
                                }
                                
                                val installingMessage = localizedContext.getString(R.string.firmware_update_installing_progress)
                                val updateProgress = UpdateProgress.transferring(
                                    progress = percent,
                                    message = installingMessage,
                                    detail = if (percent < 100) localizedContext.getString(R.string.firmware_update_detail_transfer_progress, percent) else ""
                                )
                                
                                callback.onInstallProgress(updateProgress)
                            }
                            
                            override fun otaPushStatusUpdate(progress: Double, message: String) {
                                val percent = progress.toInt()
                                currentProgress = percent
                                
                                // 根据状态标识符创建相应的UpdateProgress对象
                                val updateProgress = when {
                                    message == "TRANSFER_COMPLETE_WAITING" -> {
                                        Log.i(TAG, "【阶段2-完成】固件传输完成，等待设备确认")
                                        val displayMessage = localizedContext.getString(R.string.firmware_update_transfer_complete_waiting)
                                        UpdateProgress.transferCompleteWaiting(displayMessage)
                                    }
                                    message == "DEVICE_RESTARTING" -> {
                                        Log.i(TAG, "【阶段3-重启】设备开始重启升级")
                                        val displayMessage = localizedContext.getString(R.string.firmware_update_device_restarting)
                                        UpdateProgress.deviceRestarting(displayMessage)
                                    }
                                    message == "RECONNECTING_DEVICE" -> {
                                        Log.i(TAG, "【阶段3-重连】设备重连中")
                                        val displayMessage = localizedContext.getString(R.string.firmware_update_reconnecting_device)
                                        UpdateProgress.deviceRestarting(displayMessage)
                                    }
                                    message == "WAITING_UPGRADE_RESULT" -> {
                                        Log.i(TAG, "【阶段4-等待】等待升级结果")
                                        val displayMessage = localizedContext.getString(R.string.firmware_update_waiting_upgrade_result)
                                        UpdateProgress.deviceRestarting(displayMessage)
                                    }
                                    message == "UPGRADE_COMPLETE_SUCCESS" -> {
                                        Log.i(TAG, "【阶段4-成功】固件升级成功")
                                        val displayMessage = localizedContext.getString(R.string.firmware_update_install_complete)
                                        
                                        // 延迟完成升级过程，让用户看到成功状态
                                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                            safeContinuation.resume(true)
                                        }, 1500)
                                        
                                        UpdateProgress.upgradeComplete(displayMessage)
                                    }
                                    message.startsWith("UPGRADE_COMPLETE_FAILED:") -> {
                                        val parts = message.split(":", limit = 3)
                                        val errorReason = if (parts.size >= 3) parts[2] else "未知错误"
                                        Log.e(TAG, "【阶段4-失败】固件升级失败: $errorReason")
                                        
                                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                            safeContinuation.resume(false)
                                        }, 2000)
                                        
                                        UpdateProgress.upgradeFailed("固件升级失败", errorReason)
                                    }
                                    message.startsWith("REQUEST_RECONNECT:") -> {
                                        val serialNumber = message.substringAfter("REQUEST_RECONNECT:")
                                        Log.i(TAG, "【阶段3-重连请求】开始重连设备: $serialNumber")
                                        
                                        performDeviceReconnect(serialNumber)
                                        
                                        val displayMessage = localizedContext.getString(R.string.firmware_update_reconnecting_device)
                                        UpdateProgress.deviceRestarting(displayMessage)
                                    }
                                    else -> {
                                        val installingMessage = localizedContext.getString(R.string.firmware_update_installing_progress)
                                        UpdateProgress.transferring(
                                            progress = percent,
                                            message = installingMessage,
                                            detail = if (percent < 100) localizedContext.getString(R.string.firmware_update_detail_transfer_progress, percent) else ""
                                        )
                                    }
                                }
                                
                                callback.onInstallProgress(updateProgress)
                            }
                            
                            override fun otaPushSpeed(speed: Double, avgSpeed: Double) {
                                // 减少速度日志输出，仅在较低速度时警告
                                if (avgSpeed > 0 && avgSpeed < 5.0) {
                                    Log.w(TAG, "【传输速度】速度较慢: %.1f KB/s".format(avgSpeed))
                                }
                            }
                            
                            override fun otaPushFinish() {
                                Log.i(TAG, "【阶段2-完成】固件传输完成，等待设备重启")
                                
                                val restartingMessage = localizedContext.getString(R.string.firmware_update_device_restarting)
                                val updateProgress = UpdateProgress.deviceRestarting(restartingMessage)
                                callback.onInstallProgress(updateProgress)
                            }
                            
                            override fun otaPushError(error: sdk.penblesdk.Constants.OtaPushError) {
                                // 根据错误类型提供相应的错误消息
                                val errorMessage = when (error) {
                                    sdk.penblesdk.Constants.OtaPushError.OTA_PUSH_ERROR_USER_INTERRUPT -> {
                                        Log.w(TAG, "【阶段2-中断】用户取消了升级")
                                        localizedContext.getString(R.string.firmware_update_error_user_interrupt)
                                    }
                                    sdk.penblesdk.Constants.OtaPushError.OTA_PUSH_ERROR_FILE_NOT_EXISTS -> {
                                        Log.e(TAG, "【阶段2-错误】固件文件不存在")
                                        localizedContext.getString(R.string.firmware_update_error_file_not_exists)
                                    }
                                    sdk.penblesdk.Constants.OtaPushError.OTA_PUSH_ERROR_FILE_ERROR -> {
                                        Log.e(TAG, "【阶段2-错误】固件文件错误")
                                        localizedContext.getString(R.string.firmware_update_error_file_error)
                                    }
                                    sdk.penblesdk.Constants.OtaPushError.OTA_PUSH_ERROR_BT_DISCONNECT -> {
                                        Log.e(TAG, "【阶段2-错误】蓝牙连接断开")
                                        localizedContext.getString(R.string.firmware_update_error_bt_disconnect)
                                    }
                                    sdk.penblesdk.Constants.OtaPushError.OTA_PUSH_ERROR_DEVICE_UPGRADE_FAIL -> {
                                        Log.e(TAG, "【阶段4-失败】设备升级失败")
                                        
                                        // 检查是否是保护机制
                                        val errorStr = error.toString()
                                        if (errorStr.contains("status=5") || errorStr.contains("尝试次数过多")) {
                                            Log.w(TAG, "【保护机制】设备升级保护机制触发")
                                            localizedContext.getString(R.string.firmware_update_error_retry_limit)
                                        } else {
                                            "设备升级失败，请检查设备状态后重试"
                                        }
                                    }
                                    else -> {
                                        Log.e(TAG, "【升级错误】未知错误: $error")
                                        localizedContext.getString(R.string.firmware_update_error_transfer_failed, error.toString())
                                    }
                                }
                                
                                val updateProgress = when (error) {
                                    sdk.penblesdk.Constants.OtaPushError.OTA_PUSH_ERROR_DEVICE_UPGRADE_FAIL ->
                                        UpdateProgress.upgradeFailed(errorMessage)
                                    else ->
                                        UpdateProgress.transferFailed(errorMessage)
                                }
                                
                                callback.onInstallProgress(updateProgress)
                                
                                // 给用户时间看到错误信息后结束
                                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                    safeContinuation.resume(false)
                                }, 2000)
                            }
                        }
                    )
                }
                
                // 检查传输结果
                withContext(Dispatchers.Main) {
                    if (firmwareTransferCompleted) {
                        callback.onInstallComplete(
                            FirmwareInstallResult(
                                success = true,
                                error = null
                            )
                        )
                    }
                    // 如果失败，错误已经在otaPushError中处理了
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "安装固件异常", e)
                withContext(Dispatchers.Main) {
                    callback.onInstallComplete(
                        FirmwareInstallResult(
                            success = false,
                            error = e.message ?: localizedContext.getString(R.string.firmware_update_error_install_failed)
                        )
                    )
                }
            }
        }
    }
    
    /**
     * 取消当前操作
     */
    fun cancel() {
        Log.i(TAG, "【取消操作】用户取消了固件更新操作")
        
        try {
            val tntAgent = TntAgent.getInstant()
            val bleAgent = tntAgent?.getBleAgent()
            if (bleAgent is BleAgentImpl) {
                val firmwareTransfer = bleAgent.getFirmwareTransfer()
                if (firmwareTransfer != null && firmwareTransfer.isTransferring()) {
                    Log.i(TAG, "【通知设备】发送取消通知给设备（status=1表示用户主动退出）")
                    // 调用interruptTransfer会自动发送取消通知
                    firmwareTransfer.interruptTransfer()
                } else {
                    Log.i(TAG, "【跳过通知】没有正在进行的固件传输，跳过设备通知")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "【通知异常】发送设备取消通知异常: ${e.message}", e)
        }
        
        // 取消当前协程任务
        currentJob?.cancel()
        currentJob = null
        callback = null
    }
    
    /**
     * 下载文件并显示进度
     */
    private suspend fun downloadFileWithProgress(
        url: String,
        outputFile: File,
        expectedMd5: String,
        onProgress: (Int, String) -> Unit
    ): FirmwareDownloadResult = withContext(Dispatchers.IO) {
        try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            connection.connect()
            
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return@withContext FirmwareDownloadResult(
                    success = false,
                    error = localizedContext.getString(R.string.firmware_update_error_http_failed, connection.responseCode)
                )
            }
            
            val contentLength = connection.contentLength
            val inputStream = connection.inputStream
            val outputStream = FileOutputStream(outputFile)
            
            val buffer = ByteArray(8192)
            var totalBytes = 0
            var bytes: Int
            var lastProgressReport = 0
            
            while (inputStream.read(buffer).also { bytes = it } != -1) {
                outputStream.write(buffer, 0, bytes)
                totalBytes += bytes
                
                if (contentLength > 0) {
                    val progress = (totalBytes * 100 / contentLength)
                    // 只在进度变化较大时更新
                    if (progress - lastProgressReport >= 10 || progress == 100) {
                        val downloadedKB = totalBytes / 1024
                        val totalKB = contentLength / 1024
                        val detailMessage = localizedContext.getString(R.string.firmware_update_download_detail, downloadedKB, totalKB)
                        onProgress(progress, detailMessage)
                        lastProgressReport = progress
                    }
                }
            }
            
            outputStream.close()
            inputStream.close()
            connection.disconnect()
            
            // 验证MD5
            val actualMd5 = calculateMD5(outputFile)
            val md5Valid = expectedMd5.isNullOrEmpty() || actualMd5.equals(expectedMd5, ignoreCase = true)

            if (!md5Valid) {
                Log.e(TAG, "【阶段1-MD5错误】期望: $expectedMd5, 实际: $actualMd5")
                outputFile.delete()
                return@withContext FirmwareDownloadResult(
                    success = false,
                    error = localizedContext.getString(R.string.firmware_update_file_integrity_error)
                )
            }
            
            FirmwareDownloadResult(
                success = true,
                file = outputFile,
                md5Valid = true
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "【阶段1-异常】下载异常: ${e.message}", e)
            if (outputFile.exists()) {
                outputFile.delete()
            }
            FirmwareDownloadResult(
                success = false,
                error = e.message ?: localizedContext.getString(R.string.firmware_update_error_download_failed)
            )
        }
    }
    
    /**
     * 计算文件MD5值
     */
    private fun calculateMD5(file: File): String {
        return try {
            val md = MessageDigest.getInstance("MD5")
            val inputStream = FileInputStream(file)
            val buffer = ByteArray(8192)
            var bytes: Int
            
            while (inputStream.read(buffer).also { bytes = it } != -1) {
                md.update(buffer, 0, bytes)
            }
            
            inputStream.close()
            md.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            Log.e(TAG, "【MD5计算异常】${e.message}", e)
            ""
        }
    }
    


    /**
     * 阶段3: 执行设备重连操作
     */
    private fun performDeviceReconnect(serialNumber: String) {
        Log.i(TAG, "【阶段3-重连】开始重连设备: $serialNumber")
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val bleCore = com.plaud.nicebuild.ble.BleCore.getInstance(context)
                
                // 检查当前连接状态
                if (bleCore.isConnected()) {
                    Log.i(TAG, "【阶段3-跳过】设备已连接，跳过重连")
                    withContext(Dispatchers.Main) {
                        val bleAgent = TntAgent.getInstant().getBleAgent()
                        if (bleAgent is BleAgentImpl) {
                            bleAgent.getFirmwareTransfer()?.notifyReconnectResult(true)
                        }
                    }
                    return@launch
                }
                
                // 执行重连
                Log.i(TAG, "【阶段3-执行】开始重连操作")
                val reconnectResult = suspendCoroutine<Boolean> { continuation ->
                    val lastToken = bleCore.getLastToken() ?: serialNumber
                    bleCore.connectDevice(
                        serialNumber,
                        lastToken
                    ) { success, errorCode, errorMessage ->
                        if (success) {
                            Log.i(TAG, "【阶段3-成功】设备重连成功")
                        } else {
                            Log.e(TAG, "【阶段3-失败】设备重连失败: $errorMessage (code: $errorCode)")
                        }
                        continuation.resume(success)
                    }
                }
                
                // 通知重连结果
                withContext(Dispatchers.Main) {
                    val bleAgent = TntAgent.getInstant().getBleAgent()
                    if (bleAgent is BleAgentImpl) {
                        bleAgent.getFirmwareTransfer()?.notifyReconnectResult(reconnectResult)
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "【阶段3-异常】重连过程异常: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    val bleAgent = TntAgent.getInstant().getBleAgent()
                    if (bleAgent is BleAgentImpl) {
                        bleAgent.getFirmwareTransfer()?.notifyReconnectResult(false)
                    }
                }
            }
        }
    }
}
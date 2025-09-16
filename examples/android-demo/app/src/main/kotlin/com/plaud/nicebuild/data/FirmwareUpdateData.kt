package com.plaud.nicebuild.data

import sdk.network.model.DeviceVersionResponse
import java.io.File

/**
 * 固件更新状态枚举
 */
enum class UpdateStatus {
    /** 检查更新中 */
    CHECKING,
    /** 有可用更新 */
    AVAILABLE,
    /** 没有可用更新 */
    NOT_AVAILABLE,
    /** 下载中 */
    DOWNLOADING,
    /** 下载完成 */
    DOWNLOADED,
    /** 安装中 */
    INSTALLING,
    /** 安装成功 */
    INSTALLED,
    /** 失败 */
    FAILED
}

/**
 * 固件传输阶段枚举
 */
enum class FirmwareTransferPhase {
    /** 传输中 */
    TRANSFERRING,
    /** 传输完成，等待设备确认 */
    TRANSFER_COMPLETE_WAITING,
    /** 设备重启升级中 */
    DEVICE_RESTARTING,
    /** 升级完成 */
    UPGRADE_COMPLETE,
    /** 传输失败 */
    TRANSFER_FAILED,
    /** 升级失败 */
    UPGRADE_FAILED
}

/**
 * 固件更新进度数据类
 */
data class UpdateProgress(
    /** 进度百分比 (0-100) */
    val progress: Int = 0,
    /** 进度文本描述 */
    val message: String = "",
    /** 详细描述 */
    val detail: String = "",
    /** 固件传输阶段（可选） */
    val transferPhase: FirmwareTransferPhase? = null
) {
    companion object {
        fun checking() = UpdateProgress(0, "检查更新中...", "")
        fun downloading(progress: Int) = UpdateProgress(progress, "下载中...", "$progress%")
        fun installing(progress: Int) = UpdateProgress(progress, "安装中...", "$progress%")
        fun success(message: String) = UpdateProgress(100, message, "")
        fun failed(message: String) = UpdateProgress(0, "失败", message)
        
        // 固件传输专用方法
        fun transferring(progress: Int, message: String, detail: String = "") = 
            UpdateProgress(progress, message, detail, FirmwareTransferPhase.TRANSFERRING)
        
        fun transferCompleteWaiting(message: String) = 
            UpdateProgress(100, message, "", FirmwareTransferPhase.TRANSFER_COMPLETE_WAITING)
        
        fun deviceRestarting(message: String) = 
            UpdateProgress(100, message, "", FirmwareTransferPhase.DEVICE_RESTARTING)
        
        fun upgradeComplete(message: String) = 
            UpdateProgress(100, message, "", FirmwareTransferPhase.UPGRADE_COMPLETE)
        
        fun transferFailed(message: String, detail: String = "") = 
            UpdateProgress(0, message, detail, FirmwareTransferPhase.TRANSFER_FAILED)
        
        fun upgradeFailed(message: String, detail: String = "") = 
            UpdateProgress(0, message, detail, FirmwareTransferPhase.UPGRADE_FAILED)
    }
}

/**
 * 固件更新信息数据类
 */
data class FirmwareUpdateInfo(
    /** 设备版本响应 */
    val versionResponse: DeviceVersionResponse,
    /** 当前设备版本 */
    val currentVersion: String,
    /** 是否有新版本 */
    val hasUpdate: Boolean,
    /** 是否强制更新 */
    val isForceUpdate: Boolean
) {
    companion object {
        fun from(
            versionResponse: DeviceVersionResponse,
            currentVersion: String
        ): FirmwareUpdateInfo {
            val hasUpdate = !versionResponse.versionNumber.equals(currentVersion, ignoreCase = true)
            return FirmwareUpdateInfo(
                versionResponse = versionResponse,
                currentVersion = currentVersion,
                hasUpdate = hasUpdate,
                isForceUpdate = versionResponse.isForce
            )
        }
    }
}

/**
 * 固件文件下载结果
 */
data class FirmwareDownloadResult(
    /** 是否成功 */
    val success: Boolean,
    /** 下载的文件 */
    val file: File? = null,
    /** 错误信息 */
    val error: String? = null,
    /** MD5校验结果 */
    val md5Valid: Boolean = false
)

/**
 * 固件安装结果
 */
data class FirmwareInstallResult(
    /** 是否成功 */
    val success: Boolean,
    /** 错误信息 */
    val error: String? = null
)

/**
 * 固件更新回调接口
 */
interface FirmwareUpdateCallback {
    /** 检查更新结果回调 */
    fun onUpdateCheckResult(result: Result<FirmwareUpdateInfo>)
    
    /** 下载进度回调 */
    fun onDownloadProgress(progress: UpdateProgress)
    
    /** 下载完成回调 */
    fun onDownloadComplete(result: FirmwareDownloadResult)
    
    /** 安装进度回调 */
    fun onInstallProgress(progress: UpdateProgress)
    
    /** 安装完成回调 */
    fun onInstallComplete(result: FirmwareInstallResult)
}

/**
 * 简化的固件更新回调接口（可选实现）
 */
abstract class SimpleFirmwareUpdateCallback : FirmwareUpdateCallback {
    override fun onUpdateCheckResult(result: Result<FirmwareUpdateInfo>) {}
    override fun onDownloadProgress(progress: UpdateProgress) {}
    override fun onDownloadComplete(result: FirmwareDownloadResult) {}
    override fun onInstallProgress(progress: UpdateProgress) {}
    override fun onInstallComplete(result: FirmwareInstallResult) {}
}
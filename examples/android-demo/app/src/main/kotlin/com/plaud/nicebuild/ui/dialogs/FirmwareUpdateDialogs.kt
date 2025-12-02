package com.plaud.nicebuild.ui.dialogs

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import com.plaud.nicebuild.R
import sdk.firmware.FirmwareUpdateInfo
import sdk.firmware.UpdateProgress
import sdk.firmware.FirmwareTransferPhase

/**
 * 固件更新对话框工具类
 */
object FirmwareUpdateDialogs {
    
    /**
     * 显示更新确认对话框
     * @param context 上下文
     * @param updateInfo 更新信息
     * @param onConfirm 确认回调
     * @param onCancel 取消回调
     */
    fun showUpdateConfirmDialog(
        context: Context,
        updateInfo: FirmwareUpdateInfo,
        onConfirm: () -> Unit,
        onCancel: () -> Unit = {}
    ): AlertDialog {
        val title = if (updateInfo.hasUpdate) {
            context.getString(R.string.firmware_update_available_title)
        } else {
            context.getString(R.string.firmware_update_no_update_title)
        }
        
        val message = if (updateInfo.hasUpdate) {
            context.getString(
                R.string.firmware_update_available_message,
                updateInfo.currentVersion,
                updateInfo.versionResponse.versionCode,
                updateInfo.versionResponse.versionDescription
            )
        } else {
            context.getString(R.string.firmware_update_no_update_message, updateInfo.currentVersion)
        }
        
        val builder = AlertDialog.Builder(context)
            .setTitle(title)
            .setMessage(message)
            .setCancelable(!updateInfo.isForceUpdate)
        
        if (updateInfo.hasUpdate) {
            builder.setPositiveButton(context.getString(R.string.firmware_update_download)) { _, _ ->
                onConfirm()
            }
            
            if (!updateInfo.isForceUpdate) {
                builder.setNegativeButton(context.getString(R.string.common_cancel)) { _, _ ->
                    onCancel()
                }
            }
        } else {
            builder.setPositiveButton(context.getString(R.string.common_ok)) { _, _ ->
                onCancel()
            }
        }
        
        return builder.show()
    }
    
    /**
     * 显示安装确认对话框
     * @param context 上下文
     * @param updateInfo 更新信息
     * @param onConfirm 确认回调
     * @param onCancel 取消回调
     */
    fun showInstallConfirmDialog(
        context: Context,
        updateInfo: FirmwareUpdateInfo,
        onConfirm: () -> Unit,
        onCancel: () -> Unit = {}
    ): AlertDialog {
        val title = context.getString(R.string.firmware_update_install_ready_title)
        val message = context.getString(
            R.string.firmware_update_install_ready_message,
            updateInfo.versionResponse.versionCode
        )
        
        return AlertDialog.Builder(context)
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton(context.getString(R.string.firmware_update_install)) { _, _ ->
                onConfirm()
            }
            .setNegativeButton(context.getString(R.string.firmware_update_install_later)) { _, _ ->
                onCancel()
            }
            .setCancelable(false)
            .show()
    }
}

/**
 * 固件更新进度对话框
 */
class FirmwareUpdateProgressDialog(
    private val context: Context,
    private val title: String,
    private val cancellable: Boolean = true
) {
    
    private var dialog: Dialog? = null
    private var progressBar: ProgressBar? = null
    private var tvProgress: TextView? = null
    private var tvMessage: TextView? = null
    private var tvDetail: TextView? = null
    private var btnAction: Button? = null
    private var btnCancel: Button? = null
    
    var onCancel: (() -> Unit)? = null
    var onAction: (() -> Unit)? = null
    
    /**
     * 显示对话框
     */
    fun show() {
        if (dialog?.isShowing == true) return
        
        dialog = Dialog(context).apply {
            val view = LayoutInflater.from(context).inflate(R.layout.dialog_firmware_update_progress, null)
            setContentView(view)
            
            // 设置对话框宽度为屏幕宽度的85%，最大不超过400dp
            val displayMetrics = context.resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val maxWidthDp = 400
            val maxWidthPx = (maxWidthDp * displayMetrics.density).toInt()
            val dialogWidth = kotlin.math.min((screenWidth * 0.85).toInt(), maxWidthPx)
            
            window?.setLayout(dialogWidth, ViewGroup.LayoutParams.WRAP_CONTENT)
            window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setCancelable(cancellable)
            
            // 初始化视图
            val tvTitle = view.findViewById<TextView>(R.id.tv_title)
            val ivClose = view.findViewById<ImageView>(R.id.iv_close)
            progressBar = view.findViewById(R.id.progress_bar)
            tvProgress = view.findViewById(R.id.tv_progress)
            tvMessage = view.findViewById(R.id.tv_message)
            tvDetail = view.findViewById(R.id.tv_detail)
            btnAction = view.findViewById(R.id.btn_action)
            btnCancel = view.findViewById(R.id.btn_cancel)
            
            tvTitle.text = title
            
            // 初始状态下隐藏状态消息，避免与标题重复
            tvMessage?.visibility = android.view.View.GONE
            
            // 设置关闭图标点击事件
            ivClose?.setOnClickListener {
                onCancel?.invoke()
                dismiss()
            }
            
            // 根据cancellable属性控制关闭图标和取消按钮的可见性
            ivClose?.visibility = if (cancellable) android.view.View.VISIBLE else android.view.View.GONE
            btnCancel?.visibility = if (cancellable) android.view.View.VISIBLE else android.view.View.GONE
            
            // 设置按钮事件
            btnCancel?.setOnClickListener {
                onCancel?.invoke()
                dismiss()
            }
            
            btnAction?.setOnClickListener {
                onAction?.invoke()
            }
            
            // 初始状态下隐藏动作按钮
            btnAction?.visibility = android.view.View.GONE
            
            setOnCancelListener {
                onCancel?.invoke()
            }
        }
        
        dialog?.show()
    }
    
    /**
     * 更新进度
     */
    fun updateProgress(progress: UpdateProgress) {
        // 更新进度条和百分比
        progressBar?.progress = progress.progress
        tvProgress?.text = "${progress.progress}%"
        
        // 智能显示状态消息（只在需要额外说明时显示）
        when (progress.transferPhase) {
            FirmwareTransferPhase.DEVICE_RESTARTING,
            FirmwareTransferPhase.TRANSFER_COMPLETE_WAITING -> {
                // 这些阶段需要显示详细状态信息
                if (progress.message.isNotEmpty()) {
                    tvMessage?.text = progress.message
                    tvMessage?.visibility = android.view.View.VISIBLE
                }
            }
            else -> {
                // 其他阶段或null时隐藏状态消息，避免重复
                tvMessage?.visibility = android.view.View.GONE
            }
        }
        
        // 显示详细信息（如文件大小、传输速度等）
        if (progress.detail.isNotEmpty()) {
            tvDetail?.text = progress.detail
            tvDetail?.visibility = android.view.View.VISIBLE
        } else {
            tvDetail?.visibility = android.view.View.GONE
        }
        
        // 根据传输阶段调整按钮状态
        updateButtonsForPhase(progress.transferPhase)
    }
    
    /**
     * 根据传输阶段更新按钮状态
     */
    private fun updateButtonsForPhase(phase: FirmwareTransferPhase?) {
        when (phase) {
            FirmwareTransferPhase.UPGRADE_COMPLETE, 
            FirmwareTransferPhase.UPGRADE_FAILED -> {
                // 升级完成或失败时显示确定按钮
                btnAction?.apply {
                    text = context.getString(android.R.string.ok)
                    visibility = android.view.View.VISIBLE
                    setOnClickListener {
                        dialog?.dismiss()
                        dialog = null
                    }
                }
                btnCancel?.visibility = android.view.View.GONE
            }
            FirmwareTransferPhase.DEVICE_RESTARTING,
            FirmwareTransferPhase.TRANSFER_COMPLETE_WAITING -> {
                // 设备重启和等待结果阶段，不允许取消
                btnCancel?.visibility = android.view.View.GONE
                btnAction?.visibility = android.view.View.GONE
            }
            else -> {
                // 其他阶段或null时根据cancellable属性显示取消按钮
                btnAction?.visibility = android.view.View.GONE
                btnCancel?.visibility = if (cancellable) android.view.View.VISIBLE else android.view.View.GONE
            }
        }
    }
    
    /**
     * 设置为成功状态
     */
    fun setSuccess(message: String, actionText: String? = null) {
        progressBar?.progress = 100
        tvProgress?.text = "100%"
        tvMessage?.text = message
        tvDetail?.text = ""
        
        if (actionText != null) {
            btnAction?.apply {
                text = actionText
                visibility = android.view.View.VISIBLE
            }
        }
    }
    
    /**
     * 设置为失败状态
     */
    fun setError(message: String, detail: String = "") {
        progressBar?.progress = 0
        tvProgress?.text = "0%"
        tvMessage?.text = message
        tvDetail?.text = detail
        
        btnAction?.apply {
            text = context.getString(R.string.common_ok)
            visibility = android.view.View.VISIBLE
            setOnClickListener {
                dialog?.dismiss()
                dialog = null
            }
        }
    }
    
    /**
     * 关闭对话框
     */
    fun dismiss() {
        dialog?.dismiss()
        dialog = null
    }
    
    /**
     * 检查对话框是否显示中
     */
    fun isShowing(): Boolean {
        return dialog?.isShowing == true
    }
}
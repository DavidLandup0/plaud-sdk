package com.plaud.nicebuild.ui

import android.app.Dialog
import android.content.Context
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Button
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.plaud.nicebuild.R
import com.plaud.nicebuild.data.WifiTransferProgress
import com.plaud.nicebuild.data.WifiTransferType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * WiFi Transfer Progress Dialog - Shows transfer progress and status
 * Based on reference project's TransferDialog implementation
 */
class WifiTransferDialog private constructor(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner
) {
    companion object {
        private const val TAG = "WifiTransferDialog"
        private var currentDialog: WifiTransferDialog? = null
        
        /**
         * Show WiFi transfer dialog
         */
        fun show(
            context: Context,
            lifecycleOwner: LifecycleOwner,
            transferType: WifiTransferType = WifiTransferType.CHECK
        ): WifiTransferDialog {
            // Close existing dialog if any
            currentDialog?.dismiss()
            
            val dialog = WifiTransferDialog(context, lifecycleOwner)
            dialog.create()
            dialog.updateTransferType(transferType)
            currentDialog = dialog
            
            return dialog
        }
        
        /**
         * Get current active dialog
         */
        fun getCurrentDialog(): WifiTransferDialog? = currentDialog
        
        /**
         * Close current dialog
         */
        fun dismiss() {
            currentDialog?.dismiss()
            currentDialog = null
        }
    }
    
    private var dialog: Dialog? = null
    private var onCancelListener: (() -> Unit)? = null
    private var onCloseListener: (() -> Unit)? = null
    
    // UI Elements
    private lateinit var tvTitle: TextView
    private lateinit var tvStatus: TextView
    private lateinit var layoutProgressContainer: LinearLayout
    private lateinit var tvCurrentFile: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var tvProgressText: TextView
    private lateinit var tvProgressPercentage: TextView
    private lateinit var tvTransferSize: TextView
    private lateinit var tvTransferSpeed: TextView
    private lateinit var btnCancel: Button
    private lateinit var btnClose: Button
    
    /**
     * Create dialog
     */
    private fun create() {
        try {
            val inflater = LayoutInflater.from(context)
            val view = inflater.inflate(R.layout.dialog_wifi_transfer_progress, null)
            
            // Initialize UI elements
            initViews(view)
            
            // Create dialog
            dialog = Dialog(context).apply {
                setContentView(view)
                setCancelable(false)
                setCanceledOnTouchOutside(false)
                window?.setBackgroundDrawableResource(android.R.color.transparent)
            }
            
            // Setup button listeners
            setupButtonListeners()
            
            // Show dialog
            dialog?.show()
            Log.i(TAG, "WiFi transfer dialog created and shown")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error creating dialog: ${e.message}", e)
            // Mark dialog as failed to prevent further UI operations
            dialog = null
        }
    }
    
    /**
     * Initialize views
     */
    private fun initViews(view: View) {
        tvTitle = view.findViewById(R.id.tv_title)
        tvStatus = view.findViewById(R.id.tv_status)
        layoutProgressContainer = view.findViewById(R.id.layout_progress_container)
        tvCurrentFile = view.findViewById(R.id.tv_current_file)
        progressBar = view.findViewById(R.id.progress_bar)
        tvProgressText = view.findViewById(R.id.tv_progress_text)
        tvProgressPercentage = view.findViewById(R.id.tv_progress_percentage)
        tvTransferSize = view.findViewById(R.id.tv_transfer_size)
        tvTransferSpeed = view.findViewById(R.id.tv_transfer_speed)
        btnCancel = view.findViewById(R.id.btn_cancel)
        btnClose = view.findViewById(R.id.btn_close)
    }
    
    /**
     * Setup button listeners
     */
    private fun setupButtonListeners() {
        btnCancel.setOnClickListener {
            Log.i(TAG, "Cancel button clicked")
            onCancelListener?.invoke()
        }
        
        btnClose.setOnClickListener {
            Log.i(TAG, "Close button clicked")
            onCloseListener?.invoke()
            dismiss()
        }
    }
    
    /**
     * Update transfer type and UI state
     */
    fun updateTransferType(transferType: WifiTransferType) {
        // Check if dialog was created successfully
        if (!::tvStatus.isInitialized) {
            Log.w(TAG, "Dialog UI not initialized, skipping update")
            return
        }
        
        lifecycleOwner.lifecycleScope.launch {
            try {
                when (transferType) {
                    WifiTransferType.NONE -> {
                        tvStatus.text = context.getString(R.string.wifi_transfer_ready)
                        layoutProgressContainer.visibility = View.GONE
                        btnCancel.visibility = View.VISIBLE
                        btnClose.visibility = View.GONE
                    }
                    
                    WifiTransferType.CHECK -> {
                        tvStatus.text = context.getString(R.string.wifi_transfer_checking)
                        layoutProgressContainer.visibility = View.GONE
                        btnCancel.visibility = View.VISIBLE
                        btnClose.visibility = View.GONE
                    }
                    
                    WifiTransferType.CONNECT -> {
                        tvStatus.text = context.getString(R.string.wifi_transfer_device_wifi)
                        layoutProgressContainer.visibility = View.GONE
                        btnCancel.visibility = View.VISIBLE
                        btnClose.visibility = View.GONE
                    }
                    
                    WifiTransferType.RUNNING -> {
                        tvStatus.text = context.getString(R.string.wifi_transfer_transferring)
                        layoutProgressContainer.visibility = View.VISIBLE
                        btnCancel.visibility = View.VISIBLE
                        btnClose.visibility = View.GONE
                    }
                    
                    WifiTransferType.COMPLETED -> {
                        tvStatus.text = context.getString(R.string.wifi_transfer_completed)
                        layoutProgressContainer.visibility = View.VISIBLE
                        btnCancel.visibility = View.GONE
                        btnClose.visibility = View.VISIBLE
                        
                        // Auto-close dialog after 2 seconds
                        lifecycleOwner.lifecycleScope.launch {
                            delay(2000)
                            onCloseListener?.invoke()
                            dismiss()
                        }
                    }
                    
                    WifiTransferType.ERROR -> {
                        tvStatus.text = context.getString(R.string.wifi_transfer_failed)
                        layoutProgressContainer.visibility = View.GONE
                        btnCancel.visibility = View.GONE
                        btnClose.visibility = View.VISIBLE
                    }
                }
                
                Log.d(TAG, "Updated transfer type to: $transferType")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error updating transfer type: ${e.message}", e)
            }
        }
    }
    
    /**
     * Update transfer progress
     */
    fun updateProgress(progress: WifiTransferProgress) {
        // Check if dialog was created successfully
        if (!::tvStatus.isInitialized || !::layoutProgressContainer.isInitialized) {
            Log.w(TAG, "Dialog UI not initialized, skipping progress update")
            return
        }
        
        lifecycleOwner.lifecycleScope.launch {
            try {
                // Show progress container if hidden
                if (layoutProgressContainer.visibility != View.VISIBLE) {
                    layoutProgressContainer.visibility = View.VISIBLE
                }
                
                // Update current file name
                progress.currentFileName?.let { fileName ->
                    tvCurrentFile.text = fileName
                }
                
                // Update progress bar
                progressBar.progress = progress.overallProgress
                
                // Update progress text
                tvProgressText.text = progress.progressText
                tvProgressPercentage.text = "${progress.overallProgress}%"
                
                // Update transfer size
                val transferSizeText = if (progress.totalSize > 0) {
                    "${formatFileSize(progress.transferredSize)} / ${formatFileSize(progress.totalSize)}"
                } else {
                    "Calculating..."
                }
                tvTransferSize.text = transferSizeText
                
                // Update transfer speed
                progress.transferRate?.let { rate ->
                    tvTransferSpeed.text = rate
                }
                
                // Handle errors
                progress.error?.let { error ->
                    tvStatus.text = "Error: $error"
                    updateTransferType(WifiTransferType.ERROR)
                }
                
                // Handle completion
                if (progress.isCompleted) {
                    updateTransferType(WifiTransferType.COMPLETED)
                }
                
                Log.d(TAG, "Updated progress: ${progress.progressText} (${progress.overallProgress}%)")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error updating progress: ${e.message}", e)
            }
        }
    }
    
    /**
     * Set cancel listener
     */
    fun setOnCancelListener(listener: () -> Unit) {
        onCancelListener = listener
    }
    
    /**
     * Set close listener
     */
    fun setOnCloseListener(listener: () -> Unit) {
        onCloseListener = listener
    }
    
    /**
     * Show error message
     */
    fun showError(message: String) {
        // Check if dialog was created successfully
        if (!::tvStatus.isInitialized) {
            Log.w(TAG, "Dialog UI not initialized, skipping error display")
            return
        }
        
        lifecycleOwner.lifecycleScope.launch {
            tvStatus.text = "Error: $message"
            updateTransferType(WifiTransferType.ERROR)
        }
    }
    
    /**
     * Dismiss dialog
     */
    fun dismiss() {
        try {
            dialog?.dismiss()
            dialog = null
            if (currentDialog == this) {
                currentDialog = null
            }
            Log.i(TAG, "Dialog dismissed")
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing dialog: ${e.message}", e)
        }
    }
    
    /**
     * Check if dialog is showing
     */
    fun isShowing(): Boolean {
        return dialog?.isShowing == true
    }
    
    /**
     * Format file size for display
     */
    private fun formatFileSize(sizeInBytes: Long): String {
        if (sizeInBytes < 1024) return "${sizeInBytes} B"
        if (sizeInBytes < 1024 * 1024) return "${(sizeInBytes / 1024.0).roundToInt()} KB"
        if (sizeInBytes < 1024 * 1024 * 1024) return "${(sizeInBytes / (1024.0 * 1024.0)).roundToInt()} MB"
        return "${(sizeInBytes / (1024.0 * 1024.0 * 1024.0)).roundToInt()} GB"
    }
}
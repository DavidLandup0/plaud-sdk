package com.plaud.nicebuild.data

/**
 * WiFi transfer progress information
 */
data class WifiTransferProgress(
    val totalFiles: Int,
    val completedFiles: Int,
    val currentFileName: String? = null,
    val currentFileProgress: Int = 0,
    val totalSize: Long = 0L,
    val transferredSize: Long = 0L,
    val transferRate: String? = null,
    val isCompleted: Boolean = false,
    val error: String? = null
) {
    val overallProgress: Int
        get() = if (totalFiles > 0) (completedFiles * 100 / totalFiles) else 0

    val progressText: String
        get() = "$completedFiles/$totalFiles"
}
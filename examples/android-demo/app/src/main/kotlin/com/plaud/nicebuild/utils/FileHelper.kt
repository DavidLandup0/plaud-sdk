package com.plaud.nicebuild.utils

import android.os.Environment
import sdk.penblesdk.entity.BleFile
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object FileHelper {
    fun getOpusFile(file: BleFile): File {
        val outputDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
        val targetDir = File(outputDir, "PlaudOpus")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }
        
        // If sessionId < 100, it's a device log file (numbered 0-9, etc.)
        // Otherwise, it's a recording with timestamp-based naming
        val fileName = if (file.sessionId < 100) {
            "log${file.sessionId}"
        } else {
            val sdf = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
            val timestamp = sdf.format(Date(file.sessionId * 1000L))
            "${timestamp}.opus"
        }
        
        return File(targetDir, fileName)
    }
} 
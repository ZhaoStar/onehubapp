package com.example.onehubapp

import android.app.ActivityManager
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val SYSTEM_METRICS_CHANNEL = "onehubapp/system_metrics"
        private const val FILES_CHANNEL = "onehubapp/files"
    }

    private var lastCpuSnapshot: CpuSnapshot? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_METRICS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemMetrics" -> result.success(
                    mapOf(
                        "cpuUsage" to readCpuUsage(),
                        "memoryUsage" to readMemoryUsage()
                    )
                )
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILES_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPublicDownloadsPath" -> {
                    val downloadsDir = Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_DOWNLOADS
                    )
                    result.success(downloadsDir.absolutePath)
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "Path is required.", null)
                        return@setMethodCallHandler
                    }

                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(path),
                        null
                    ) { _, _ -> }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readMemoryUsage(): Double {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        if (memoryInfo.totalMem <= 0L) return 0.0
        val usedMemory = memoryInfo.totalMem - memoryInfo.availMem
        return (usedMemory * 100.0 / memoryInfo.totalMem).coerceIn(0.0, 100.0)
    }

    private fun readCpuUsage(): Double {
        val current = readCpuSnapshot() ?: return 0.0
        val previous = lastCpuSnapshot
        lastCpuSnapshot = current

        if (previous == null) return 0.0

        val totalDiff = current.total - previous.total
        val idleDiff = current.idle - previous.idle
        if (totalDiff <= 0L) return 0.0

        return ((totalDiff - idleDiff) * 100.0 / totalDiff).coerceIn(0.0, 100.0)
    }

    private fun readCpuSnapshot(): CpuSnapshot? {
        val parts = File("/proc/stat")
            .useLines { lines -> lines.firstOrNull() }
            ?.trim()
            ?.split(Regex("\\s+"))
            ?: return null

        if (parts.size < 8 || parts[0] != "cpu") return null

        val values = parts.drop(1).mapNotNull { it.toLongOrNull() }
        if (values.size < 7) return null

        val idle = values[3] + values.getOrElse(4) { 0L }
        val total = values.sum()
        return CpuSnapshot(total = total, idle = idle)
    }

    private data class CpuSnapshot(val total: Long, val idle: Long)
}

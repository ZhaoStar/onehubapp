package online.onehubai.app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    companion object {
        private const val SYSTEM_METRICS_CHANNEL = "onehubapp/system_metrics"
        private const val FILES_CHANNEL = "onehubapp/files"
        private const val INSTALLER_CHANNEL = "onehubapp/installer"
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
                "getVideoDurationMs" -> {
                    val path = call.argument<String>("path")
                    val identifier = call.argument<String>("identifier")
                    val durationMs = readVideoDurationMs(path, identifier)
                    if (durationMs == null) {
                        result.error("duration_unavailable", "Unable to resolve video duration.", null)
                    } else {
                        result.success(durationMs)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALLER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    // Android 8.0 起安装 APK 需要用户手动开启「安装未知应用」，否则安装器会被静默拦截
                    val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        packageManager.canRequestPackageInstalls()
                    result.success(allowed)
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        } catch (e: Exception) {
                            result.error("settings_unavailable", "无法打开安装权限设置页", e.message)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(true)
                }
                "isSignatureCompatible" -> {
                    // Android 不允许签名不同的安装包覆盖升级，撞上时系统只会提示
                    // 「安装失败 - 已安装了签名冲突的应用」。提前比较签名，
                    // 界面才能给出「先卸载旧版本」这类可执行的提示。
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank() || !File(path).exists()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(isSignatureCompatible(path))
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 比较本机已安装版本与待安装 APK 的签名，无法判断时返回 null */
    private fun isSignatureCompatible(apkPath: String): Boolean? {
        return try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                @Suppress("DEPRECATION")
                PackageManager.GET_SIGNATURES
            }
            val installed = packageManager.getPackageInfo(packageName, flags)
            val archive = packageManager.getPackageArchiveInfo(apkPath, flags) ?: return null
            val installedDigest = signatureDigest(collectSigners(installed)) ?: return null
            val archiveDigest = signatureDigest(collectSigners(archive)) ?: return null
            installedDigest == archiveDigest
        } catch (_: Exception) {
            null
        }
    }

    private fun collectSigners(info: PackageInfo): Array<Signature>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return null
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
    }

    private fun signatureDigest(signers: Array<Signature>?): String? {
        val signer = signers?.firstOrNull() ?: return null
        return MessageDigest.getInstance("SHA-256")
            .digest(signer.toByteArray())
            .joinToString("") { "%02x".format(it.toInt() and 0xFF) }
    }

    private fun readVideoDurationMs(path: String?, identifier: String?): Long? {
        val retriever = MediaMetadataRetriever()
        return try {
            when {
                !identifier.isNullOrBlank() -> retriever.setDataSource(applicationContext, Uri.parse(identifier))
                !path.isNullOrBlank() -> retriever.setDataSource(path)
                else -> return null
            }

            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
        } catch (_: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
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

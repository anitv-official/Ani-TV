package com.anitv.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.anitv.app/installer"
    private val DEEP_LINK_CHANNEL = "com.anitv.app/deeplink"
    private val DOWNLOAD_CHANNEL = "com.anitv.app/downloads"
    private val NOTIFICATION_ID = 7241
    private lateinit var deepLinkChannel: MethodChannel
    private lateinit var downloadChannel: MethodChannel
    private var initialLink: String? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialLink = intent?.data?.toString()

        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkChannel.setMethodCallHandler { call, result ->
            if (call.method == "getInitialLink") {
                result.success(initialLink)
                initialLink = null
            } else result.notImplemented()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("path")
                if (path != null) {
                    installApk(path, result)
                } else {
                    result.error("INVALID_ARGUMENT", "APK path is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
        downloadChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL)
        downloadChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                "sendToAdm" -> sendToAdm(call.argument<String>("url"), call.argument<String>("title"), result)
                "downloadNotification" -> {
                    showDownloadNotification(call.argument<String>("title") ?: "AniTV", call.argument<String>("body") ?: "", call.argument<Int>("progress") ?: 0, call.argument<Int>("total") ?: 0, call.argument<Boolean>("complete") ?: false, call.argument<Boolean>("failed") ?: false, call.argument<String>("taskId") ?: "", call.argument<Boolean>("paused") ?: false)
                    result.success(null)
                }
                else -> result.notImplemented()
                }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let { deepLinkChannel.invokeMethod("onLink", it) }
        val action = intent.getStringExtra("download_action")
        val taskId = intent.getStringExtra("taskId")
        if (!action.isNullOrBlank() && !taskId.isNullOrBlank()) {
            downloadChannel.invokeMethod(action, mapOf("taskId" to taskId))
        }
    }

    private fun installApk(apkPath: String, result: MethodChannel.Result) {
        try {
            val file = File(apkPath)
            if (!file.exists() || file.length() == 0L) {
                result.error("INVALID_APK", "Downloaded APK is missing or empty", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(settingsIntent)
                result.error("INSTALL_PERMISSION_REQUIRED", "Allow AniTV to install unknown apps", null)
                return
            }

            val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }
            
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            
            startActivity(intent)
            result.success("success")
        } catch (e: Exception) {
            result.error("INSTALLATION_ERROR", e.message, e)
        }
    }

    private fun sendToAdm(url: String?, title: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) { result.success(false); return }
        try {
            val intent = Intent("com.dv.adm.action.ADD_DOWNLOAD").apply {
                setPackage("com.dv.adm")
                putExtra(Intent.EXTRA_TEXT, url)
                putExtra("extra_download_url", url)
                putExtra("extra_title", title ?: "")
            }
            if (packageManager.resolveActivity(intent, 0) == null) { result.success(false); return }
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) { result.success(false) }
    }

    private fun showDownloadNotification(title: String, body: String, progress: Int, total: Int, complete: Boolean, failed: Boolean, taskId: String, paused: Boolean) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) manager.createNotificationChannel(NotificationChannel("downloads", "التنزيلات", NotificationManager.IMPORTANCE_LOW))
        val builder = NotificationCompat.Builder(this, "downloads").setSmallIcon(com.anitv.app.R.mipmap.launcher_icon).setContentTitle(title).setContentText(body).setOnlyAlertOnce(true).setAutoCancel(complete || failed).setOngoing(!complete && !failed)
        if (complete || failed) {
            manager.cancel(NOTIFICATION_ID)
            manager.notify(NOTIFICATION_ID + 1, builder.build())
        } else {
            if (taskId.isNotBlank()) {
                val toggle = if (paused) "resumeDownload" else "pauseDownload"
                val toggleLabel = if (paused) "استئناف" else "إيقاف مؤقت"
                builder.addAction(0, toggleLabel, actionPendingIntent(toggle, taskId))
                builder.addAction(0, "إلغاء", actionPendingIntent("cancelDownload", taskId))
            }
            val percent = if (total > 0) ((progress * 100L) / total).toInt().coerceIn(0, 100) else 0
            builder.setProgress(if (total > 0) 100 else 0, percent, total <= 0)
            manager.notify(NOTIFICATION_ID, builder.build())
        }
    }

    private fun actionPendingIntent(action: String, taskId: String): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra("download_action", action)
            putExtra("taskId", taskId)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(this, (action + taskId).hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

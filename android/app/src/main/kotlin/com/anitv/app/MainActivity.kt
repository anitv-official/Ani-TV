package com.anitv.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.anitv.app/installer"
    private val DEEP_LINK_CHANNEL = "com.anitv.app/deeplink"
    private val DOWNLOAD_CHANNEL = "com.anitv.app/downloads"
    private val NOTIFICATION_ID = 7241
    private lateinit var deepLinkChannel: MethodChannel
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkChannel.setMethodCallHandler { call, result ->
            if (call.method == "getInitialLink") result.success(intent?.data?.toString()) else result.notImplemented()
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendToAdm" -> sendToAdm(call.argument<String>("url"), call.argument<String>("title"), result)
                "downloadNotification" -> {
                    showDownloadNotification(call.argument<String>("title") ?: "AniTV", call.argument<String>("body") ?: "", call.argument<Int>("progress") ?: 0, call.argument<Int>("total") ?: 0, call.argument<Boolean>("complete") ?: false)
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
    }

    private fun installApk(apkPath: String, result: MethodChannel.Result) {
        try {
            val file = File(apkPath)
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

    private fun showDownloadNotification(title: String, body: String, progress: Int, total: Int, complete: Boolean) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) manager.createNotificationChannel(NotificationChannel("downloads", "التنزيلات", NotificationManager.IMPORTANCE_LOW))
        val builder = NotificationCompat.Builder(this, "downloads").setSmallIcon(com.anitv.app.R.mipmap.launcher_icon).setContentTitle(title).setContentText(body).setOnlyAlertOnce(true).setAutoCancel(complete)
        if (complete) {
            manager.cancel(NOTIFICATION_ID)
            manager.notify(NOTIFICATION_ID + 1, builder.build())
        } else {
            val percent = if (total > 0) ((progress * 100L) / total).toInt().coerceIn(0, 100) else 0
            builder.setProgress(if (total > 0) 100 else 0, percent, total <= 0)
            manager.notify(NOTIFICATION_ID, builder.build())
        }
    }
}

package com.anitv.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.anitv.app/installer"
    private val DEEP_LINK_CHANNEL = "com.anitv.app/deeplink"
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
}

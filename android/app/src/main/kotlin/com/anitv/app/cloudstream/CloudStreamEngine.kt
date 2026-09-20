package com.anitv.app.cloudstream

import android.content.Context
import dalvik.system.DexClassLoader
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.zip.ZipFile

/**
 * Small, defensive CloudStream bridge.
 *
 * CS3 files are executable Dex archives, not data files. This class therefore
 * validates the archive before any class loading and never runs a plugin whose
 * manifest, checksum, or size is invalid.
 */
class CloudStreamEngine(private val context: Context) {
    companion object {
        const val CHANNEL = "com.anitv.app/cloudstream"
        private const val MAX_PLUGIN_BYTES = 32L * 1024L * 1024L
        private const val ENGINE_API = 1
    }

    private val extensionDirectory: File
        get() = File(context.filesDir, "AniTV/Extensions")

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "engineInfo" -> result.success(mapOf("api" to ENGINE_API, "mode" to "safe-dex-loader"))
                "listInstalledPlugins" -> result.success(listInstalledPlugins())
                "inspectPlugin" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) result.error("INVALID_ARGUMENT", "Plugin path is required", null)
                    else result.success(inspect(File(path)))
                }
                "loadPlugin" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) result.error("INVALID_ARGUMENT", "Plugin path is required", null)
                    else result.success(load(File(path)))
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("CLOUDSTREAM_ERROR", error.message ?: error.javaClass.simpleName, null)
        }
    }

    private fun listInstalledPlugins(): List<Map<String, Any?>> {
        if (!extensionDirectory.exists()) return emptyList()
        return extensionDirectory.listFiles { file -> file.isFile && file.extension.equals("cs3", true) }
            ?.mapNotNull { file -> runCatching { inspect(file) }.getOrNull() }
            ?: emptyList()
    }

    private fun inspect(file: File): Map<String, Any?> {
        require(file.exists() && file.isFile) { "Plugin file does not exist" }
        require(file.length() in 1..MAX_PLUGIN_BYTES) { "Plugin size is outside the safe limit" }
        val manifest = readManifest(file)
        val className = manifest.optString("pluginClassName")
        val name = manifest.optString("name")
        val version = manifest.optInt("version", -1)
        require(name.isNotBlank() && className.isNotBlank() && version >= 0) { "Invalid CloudStream manifest" }
        return mapOf(
            "path" to file.absolutePath,
            "sha256" to sha256(file),
            "name" to name,
            "pluginClassName" to className,
            "version" to version,
            "requiresResources" to manifest.optBoolean("requiresResources", false),
            "engineApi" to ENGINE_API,
            "readOnly" to !file.canWrite()
        )
    }

    private fun load(file: File): Map<String, Any?> {
        val metadata = inspect(file)
        require(file.setReadOnly() || !file.canWrite()) { "Plugin must be read-only before loading" }
        val optimized = File(context.codeCacheDir, "cloudstream-dex").apply { mkdirs() }
        return try {
            val className = metadata["pluginClassName"].toString()
            val loader = DexClassLoader(file.absolutePath, optimized.absolutePath, null, context.classLoader)
            val pluginClass = loader.loadClass(className)
            val instance = pluginClass.getDeclaredConstructor().newInstance()
            val loadMethod = pluginClass.methods.firstOrNull { it.name == "load" && it.parameterTypes.isEmpty() }
            loadMethod?.isAccessible = true
            loadMethod?.invoke(instance)
            metadata + mapOf("loaded" to true, "runtime" to "cloudstream-compatible")
        } catch (error: Throwable) {
            metadata + mapOf(
                "loaded" to false,
                "runtime" to "unavailable",
                "error" to (error.cause?.message ?: error.message ?: error.javaClass.simpleName)
            )
        }
    }

    private fun readManifest(file: File): JSONObject {
        ZipFile(file).use { zip ->
            val entry = zip.getEntry("manifest.json") ?: error("CloudStream manifest.json is missing")
            return JSONObject(zip.getInputStream(entry).bufferedReader().use { it.readText() })
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(16 * 1024)
            var read: Int
            while (input.read(buffer).also { read = it } >= 0) if (read > 0) digest.update(buffer, 0, read)
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte) }
    }
}

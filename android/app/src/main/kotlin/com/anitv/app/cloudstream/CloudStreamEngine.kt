package com.anitv.app.cloudstream

import android.content.Context
import dalvik.system.DexClassLoader
import com.lagradost.cloudstream3.APIHolder
import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.SearchResponse
import com.lagradost.cloudstream3.EpisodeResponse
import com.lagradost.cloudstream3.utils.ExtractorLink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.zip.ZipFile

/**
 * CloudStream bridge used by AniTV. CS3 files are executable Dex archives,
 * therefore every archive is validated before it is loaded into the app.
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
                "engineInfo" -> result.success(mapOf("api" to ENGINE_API, "mode" to "cloudstream-library-4.8.0"))
                "listInstalledPlugins" -> result.success(listInstalledPlugins())
                "inspectPlugin" -> result.success(inspect(File(requirePath(call))))
                "loadPlugin" -> result.success(load(File(requirePath(call))))
                "providers" -> result.success(providers())
                "search" -> result.success(search(call.argument<String>("provider"), call.argument<String>("query") ?: ""))
                "load" -> result.success(loadDetails(call.argument<String>("provider"), call.argument<String>("url") ?: ""))
                "loadLinks" -> result.success(loadLinks(call.argument<String>("provider"), call.argument<String>("data") ?: ""))
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("CLOUDSTREAM_ERROR", error.cause?.message ?: error.message ?: error.javaClass.simpleName, null)
        }
    }

    private fun requirePath(call: MethodCall): String = call.argument<String>("path")?.takeIf { it.isNotBlank() }
        ?: error("Plugin path is required")

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
        return mapOf("path" to file.absolutePath, "sha256" to sha256(file), "name" to name, "pluginClassName" to className, "version" to version, "requiresResources" to manifest.optBoolean("requiresResources", false), "engineApi" to ENGINE_API, "readOnly" to !file.canWrite())
    }

    private fun load(file: File): Map<String, Any?> {
        val metadata = inspect(file)
        require(file.setReadOnly() || !file.canWrite()) { "Plugin must be read-only before loading" }
        val optimized = File(context.codeCacheDir, "cloudstream-dex").apply { mkdirs() }
        return try {
            val loader = DexClassLoader(file.absolutePath, optimized.absolutePath, null, context.classLoader)
            val pluginClass = loader.loadClass(metadata["pluginClassName"].toString())
            val instance = pluginClass.getDeclaredConstructor().newInstance()
            val loadMethod = pluginClass.methods.firstOrNull { it.name == "load" && it.parameterTypes.isEmpty() }
            loadMethod?.isAccessible = true
            loadMethod?.invoke(instance)
            APIHolder.initAll()
            metadata + mapOf("loaded" to true, "runtime" to "cloudstream-compatible", "providers" to providers())
        } catch (error: Throwable) {
            metadata + mapOf("loaded" to false, "runtime" to "unavailable", "error" to (error.cause?.message ?: error.message ?: error.javaClass.simpleName))
        }
    }

    private fun provider(name: String?): MainAPI? {
        if (name.isNullOrBlank()) return null
        return APIHolder.allProviders.withLock { APIHolder.allProviders.firstOrNull { it.name == name || it.mainUrl == name } }
    }

    private fun providers(): List<Map<String, Any?>> = APIHolder.allProviders.withLock {
        APIHolder.allProviders.map { mapOf("name" to it.name, "mainUrl" to it.mainUrl, "lang" to it.lang, "usesWebView" to it.usesWebView) }
    }

    private fun search(name: String?, query: String): List<Map<String, Any?>> {
        val api = provider(name) ?: error("CloudStream provider is not loaded")
        val results = runBlocking { api.search(query).orEmpty() }
        return results.map { response: SearchResponse -> mapOf("title" to response.name, "url" to response.url, "image_url" to response.posterUrl, "type" to response.type?.name, "provider" to response.apiName) }
    }

    private fun loadDetails(name: String?, url: String): Map<String, Any?> {
        val api = provider(name) ?: error("CloudStream provider is not loaded")
        val response = runBlocking { api.load(url) } ?: error("CloudStream returned no details")
        val episodes = if (response is EpisodeResponse) reflectEpisodes(response) else emptyList()
        return mapOf("title" to response.name, "url" to response.url, "image_url" to response.posterUrl, "plot" to response.plot, "type" to response.type.name, "provider" to response.apiName, "episodes" to episodes)
    }

    private fun loadLinks(name: String?, data: String): List<Map<String, Any?>> {
        val api = provider(name) ?: error("CloudStream provider is not loaded")
        val links = mutableListOf<Map<String, Any?>>()
        runBlocking {
            api.loadLinks(data, false, {}, { link: ExtractorLink ->
                links.add(mapOf("url" to link.url, "name" to link.name, "source" to link.source, "quality" to link.quality, "referer" to link.referer, "headers" to link.headers, "type" to link.type.name))
            })
        }
        return links
    }

    private fun reflectEpisodes(response: EpisodeResponse): List<Map<String, Any?>> {
        val getter = response.javaClass.methods.firstOrNull { it.name == "getEpisodes" && it.parameterTypes.isEmpty() } ?: return emptyList()
        val raw = getter.invoke(response) as? Iterable<*> ?: return emptyList()
        return raw.mapNotNull { episode ->
            val data = episode ?: return@mapNotNull null
            mapOf("data" to readProperty(data, "data"), "name" to readProperty(data, "name"), "season" to readProperty(data, "season"), "episode" to readProperty(data, "episode"), "poster_url" to readProperty(data, "posterUrl"))
        }
    }

    private fun readProperty(value: Any, name: String): Any? = runCatching { value.javaClass.methods.firstOrNull { it.name == "get${name.replaceFirstChar { it.uppercase() }}" }?.invoke(value) }.getOrNull()

    private fun readManifest(file: File): org.json.JSONObject = ZipFile(file).use { zip ->
        val entry = zip.getEntry("manifest.json") ?: error("CloudStream manifest.json is missing")
        org.json.JSONObject(zip.getInputStream(entry).bufferedReader().use { it.readText() })
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

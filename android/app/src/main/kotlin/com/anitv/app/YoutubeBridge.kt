package com.anitv.app

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors
import org.schabi.newpipe.extractor.Image
import org.schabi.newpipe.extractor.InfoItem
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import org.schabi.newpipe.extractor.stream.VideoStream

/** Android-only bridge that keeps YouTube extraction inside NewPipe Extractor. */
object YoutubeBridge {
    private const val CHANNEL = "com.anitv.app/youtube"
    private const val USER_AGENT =
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"

    private val executor = Executors.newFixedThreadPool(3)
    @Volatile private var initialized = false

    fun register(activity: Activity, flutterEngine: FlutterEngine) {
        initializeExtractor()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "search", "streams", "related" -> executor.execute {
                        try {
                            val payload = handle(call)
                            activity.runOnUiThread { result.success(payload) }
                        } catch (error: Throwable) {
                            val root = generateSequence(error) { it.cause }.last()
                            val message = root.message?.takeIf { it.isNotBlank() }
                                ?: "YouTube extraction failed"
                            activity.runOnUiThread {
                                result.error("YOUTUBE_EXTRACTION_FAILED", message, root.javaClass.name)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Synchronized
    private fun initializeExtractor() {
        if (initialized) return
        NewPipe.init(JavaNetDownloader(), Localization("ar", "SA"))
        initialized = true
    }

    private fun handle(call: MethodCall): Any {
        return when (call.method) {
            "search" -> search(requireArgument(call, "query"))
            "streams" -> streamInfo(requireArgument(call, "url"))
            "related" -> related(requireArgument(call, "url"))
            else -> emptyMap<String, Any>()
        }
    }

    private fun requireArgument(call: MethodCall, name: String): String {
        return call.argument<String>(name)?.trim()?.takeIf { it.isNotEmpty() }
            ?: throw IllegalArgumentException("Missing $name")
    }

    private fun search(query: String): Map<String, Any> {
        val service = ServiceList.YouTube
        val handler = service.searchQHFactory.fromQuery(query, listOf("videos"), "")
        val info = SearchInfo.getInfo(service, handler)
        val videos = info.relatedItems
            .filterIsInstance<StreamInfoItem>()
            .map(::mapStreamItem)
        return mapOf("items" to videos)
    }

    private fun streamInfo(url: String): Map<String, Any> {
        val info = StreamInfo.getInfo(ServiceList.YouTube, url)
        val progressive = info.videoStreams
            .asSequence()
            .filter { it.isUrl && !it.isVideoOnly && it.url.isNotBlank() }
            .sortedWith(
                compareByDescending<VideoStream> { resolutionHeight(it.resolution) }
                    .thenByDescending { it.bitrate },
            )
            .distinctBy { "${it.resolution}|${it.url}" }
            .map { stream ->
                val format = stream.format?.suffix.orEmpty()
                mapOf(
                    "url" to stream.url,
                    "quality" to stream.resolution.ifBlank { "تلقائي" },
                    "format" to format,
                )
            }
            .toList()

        if (progressive.isEmpty()) {
            throw IllegalStateException("No progressive YouTube stream is available")
        }

        return mapOf(
            "url" to info.url,
            "title" to info.name,
            "thumbnail" to bestThumbnail(info.thumbnails),
            "uploader" to info.uploaderName,
            "uploaded" to info.textualUploadDate,
            "description" to info.description.content,
            "duration" to info.duration,
            "views" to info.viewCount,
            "streams" to progressive,
            "related" to mapRelated(info.relatedItems),
            "headers" to mapOf("User-Agent" to USER_AGENT),
        )
    }

    private fun related(url: String): Map<String, Any> {
        val info = StreamInfo.getInfo(ServiceList.YouTube, url)
        return mapOf("items" to mapRelated(info.relatedItems))
    }

    private fun mapRelated(items: List<InfoItem>): List<Map<String, Any>> =
        items.filterIsInstance<StreamInfoItem>().map(::mapStreamItem)

    private fun mapStreamItem(item: StreamInfoItem): Map<String, Any> = mapOf(
        "url" to item.url,
        "title" to item.name,
        "thumbnail" to bestThumbnail(item.thumbnails),
        "uploader" to item.uploaderName,
        "uploaded" to item.textualUploadDate,
        "description" to item.shortDescription,
        "duration" to item.duration,
        "views" to item.viewCount,
    )

    private fun bestThumbnail(images: List<Image>): String = images
        .maxByOrNull { image ->
            val width = image.width.coerceAtLeast(0)
            val height = image.height.coerceAtLeast(0)
            width.toLong() * height.toLong()
        }
        ?.url
        .orEmpty()

    private fun resolutionHeight(resolution: String): Int =
        Regex("(\\d+)").find(resolution)?.groupValues?.get(1)?.toIntOrNull() ?: 0

    private class JavaNetDownloader : Downloader() {
        override fun execute(request: Request): Response {
            val connection = URL(request.url()).openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = true
                connection.connectTimeout = 20_000
                connection.readTimeout = 25_000
                connection.requestMethod = request.httpMethod()
                connection.useCaches = false
                connection.setRequestProperty("User-Agent", USER_AGENT)
                connection.setRequestProperty("Accept-Encoding", "identity")
                request.headers().forEach { (name, values) ->
                    values.forEachIndexed { index, value ->
                        if (index == 0) connection.setRequestProperty(name, value)
                        else connection.addRequestProperty(name, value)
                    }
                }

                request.dataToSend()?.let { body ->
                    connection.doOutput = true
                    connection.outputStream.use { it.write(body) }
                }

                val code = connection.responseCode
                if (code == HttpURLConnection.HTTP_TOO_MANY_REQUESTS) {
                    throw ReCaptchaException("YouTube requested CAPTCHA", request.url())
                }
                val bodyStream = if (code >= 400) connection.errorStream else connection.inputStream
                val body = bodyStream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
                val headers = connection.headerFields
                    .filterKeys { it != null }
                    .mapKeys { it.key!! }
                    .mapValues { it.value ?: emptyList() }
                return Response(
                    code,
                    connection.responseMessage.orEmpty(),
                    headers,
                    body,
                    connection.url.toString(),
                )
            } catch (error: ReCaptchaException) {
                throw error
            } catch (error: IOException) {
                throw error
            } finally {
                connection.disconnect()
            }
        }
    }
}

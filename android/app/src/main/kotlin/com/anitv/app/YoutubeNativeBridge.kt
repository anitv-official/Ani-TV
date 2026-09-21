package com.anitv.app

import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.services.youtube.extractors.YoutubeStreamExtractor
import org.schabi.newpipe.extractor.services.youtube.linkHandler.YoutubeStreamLinkHandlerFactory
import org.schabi.newpipe.extractor.stream.AudioStream
import org.schabi.newpipe.extractor.stream.Stream
import org.schabi.newpipe.extractor.stream.VideoStream
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.ServerSocket
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/** Native YouTube extraction based on NewPipeExtractor, without WebView/Piped. */
object YoutubeNativeBridge {
    private const val TAG = "YoutubeNativeBridge"
    private var initialized = false
    private var server: ServerSocket? = null
    private var serverPort = 0
    private val manifests = ConcurrentHashMap<String, String>()

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "extractStreams") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val url = call.argument<String>("url")?.trim()
            if (url.isNullOrBlank()) {
                result.error("INVALID_URL", "YouTube URL is required", null)
                return@setMethodCallHandler
            }
            thread(name = "youtube-extract") {
                try {
                    val payload = extract(url)
                    runOnMain { result.success(payload) }
                } catch (error: Throwable) {
                    Log.e(TAG, "YouTube extraction failed", error)
                    runOnMain { result.error("EXTRACTION_FAILED", error.message ?: "YouTube extraction failed", null) }
                }
            }
        }
    }

    private fun runOnMain(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }

    private fun initializeExtractor() {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            NewPipe.init(OkHttpLikeDownloader())
            initialized = true
        }
    }

    private fun extract(rawUrl: String): Map<String, Any> {
        initializeExtractor()
        val cleaned = rawUrl.replace(Regex("[\\n\\r\\t ]"), "")
        val handler = YoutubeStreamLinkHandlerFactory.getInstance().fromUrl(cleaned)
        val extractor = object : YoutubeStreamExtractor(ServiceList.YouTube, handler) {}
        extractor.fetchPage()
        val duration = if (extractor.length > 0) extractor.length else 3600L
        val streams = mutableListOf<Map<String, Any>>()
        val seen = mutableSetOf<String>()
        val videos = (extractor.videoOnlyStreams ?: emptyList()).mapNotNull { toVideo(it, seen) }.distinctBy { it.height }
        val audios = (extractor.audioStreams ?: emptyList()).mapNotNull { toAudio(it) }.distinctBy { it.url }
        startServerIfNeeded()

        val byLanguage = audios.groupBy { it.language }
        for (video in videos) {
            for ((language, candidates) in byLanguage) {
                val audio = candidates.sortedWith(
                    compareByDescending<AudioInfo> { if (video.mimeType.contains("webm")) it.mimeType.contains("webm") else it.mimeType.contains("mp4") }
                        .thenByDescending { it.bitrate }
                ).firstOrNull() ?: continue
                val manifest = buildManifest(video, audio, duration)
                val local = registerManifest(manifest) ?: continue
                streams.add(mapOf(
                    "url" to local,
                    "label" to "${video.label}p ($language)",
                    "quality" to video.height,
                    "type" to "dash",
                    "language" to language,
                    "referer" to "https://www.youtube.com/"
                ))
            }
        }
        for (muxed in (extractor.videoStreams ?: emptyList()).mapNotNull { toMuxed(it, seen) }) {
            streams.add(mapOf(
                "url" to muxed.url,
                "label" to "${muxed.label}p (Legacy)",
                "quality" to muxed.height,
                "type" to "progressive",
                "referer" to "https://www.youtube.com/"
            ))
        }
        val subtitles = extractor.subtitlesDefault?.mapNotNull { subtitle ->
            val language = subtitle.locale?.language ?: return@mapNotNull null
            val url = subtitle.content ?: runCatching { subtitle.getUrl() }.getOrNull() ?: return@mapNotNull null
            mapOf("language" to language, "url" to url)
        } ?: emptyList()
        return mapOf("source_id" to "youtube_native", "streams" to streams, "subtitles" to subtitles)
    }

    private data class VideoInfo(val url: String, val mimeType: String, val height: Int, val label: String, val initRange: String?, val indexRange: String?)
    private data class AudioInfo(val url: String, val mimeType: String, val bitrate: Int, val initRange: String?, val indexRange: String?, val language: String)
    private data class MuxedInfo(val url: String, val height: Int, val label: String)

    private fun toVideo(stream: VideoStream, seen: MutableSet<String>): VideoInfo? {
        val url = stream.content ?: return null
        if (!seen.add(url)) return null
        val mime = stream.format?.mimeType?.takeIf { it.isNotBlank() } ?: mimeFromUrl(url, false)
        val height = stream.height ?: 0
        return VideoInfo(url, mime, height, height.toString(), range(stream.initStart, stream.initEnd), range(stream.indexStart, stream.indexEnd))
    }

    private fun toAudio(stream: AudioStream): AudioInfo? {
        val url = stream.content ?: return null
        var language = stream.audioTrackId ?: "Default"
        if (language.contains('.')) language = language.substringBefore('.')
        val mime = stream.format?.mimeType?.takeIf { it.isNotBlank() } ?: mimeFromUrl(url, true)
        return AudioInfo(url, mime, stream.bitrate ?: 128000, range(stream.initStart, stream.initEnd), range(stream.indexStart, stream.indexEnd), language.uppercase())
    }

    private fun toMuxed(stream: VideoStream, seen: MutableSet<String>): MuxedInfo? {
        val url = stream.content ?: return null
        if (!seen.add(url)) return null
        return MuxedInfo(url, stream.height ?: 0, (stream.height ?: 0).toString())
    }

    private fun range(start: Long?, end: Long?): String? = if (start != null && end != null) "$start-$end" else null
    private fun mimeFromUrl(url: String, audio: Boolean): String {
        val decoded = runCatching { URLDecoder.decode(url, "UTF-8") }.getOrDefault(url)
        return if (decoded.contains("webm", true)) if (audio) "audio/webm" else "video/webm" else if (audio) "audio/mp4" else "video/mp4"
    }

    @Synchronized private fun startServerIfNeeded() {
        if (server?.isClosed == false) return
        server = ServerSocket(0)
        serverPort = server!!.localPort
        thread(name = "youtube-mpd-server") {
            try {
                while (server?.isClosed == false) {
                    val client = server!!.accept()
                    thread { serveManifest(client) }
                }
            } catch (_: Throwable) { }
        }
    }

    private fun registerManifest(xml: String): String? {
        if (serverPort == 0) return null
        val id = UUID.randomUUID().toString()
        manifests[id] = xml
        return "http://127.0.0.1:$serverPort/$id.mpd"
    }

    private fun serveManifest(socket: java.net.Socket) {
        try {
            socket.use { client ->
                val request = BufferedReader(InputStreamReader(client.getInputStream())).readLine() ?: return
                val path = request.split(' ').getOrNull(1)?.removePrefix("/")?.removeSuffix(".mpd") ?: return
                val xml = manifests[path]
                val writer = OutputStreamWriter(client.getOutputStream(), Charsets.UTF_8)
                if (xml == null) writer.write("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
                else writer.write("HTTP/1.1 200 OK\r\nContent-Type: application/dash+xml\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n$xml")
                writer.flush()
            }
        } catch (_: Throwable) { }
    }

    private fun buildManifest(video: VideoInfo, audio: AudioInfo, duration: Long): String {
        val vMime = escape(video.mimeType)
        val aMime = escape(audio.mimeType)
        val vCodec = if (video.mimeType.contains("webm")) "vp9" else "avc1.4d401f"
        val aCodec = if (audio.mimeType.contains("webm")) "opus" else "mp4a.40.2"
        val vSegment = segment(video.initRange, video.indexRange)
        val aSegment = segment(audio.initRange, audio.indexRange)
        return """<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" type="static" minBufferTime="PT5S" mediaPresentationDuration="PT${duration}S">
 <Period>
  <AdaptationSet mimeType="$vMime" subsegmentAlignment="true" subsegmentStartsWithSAP="1"><Representation id="video" bandwidth="4000000" width="0" height="${video.height}" codecs="$vCodec"><BaseURL>${escape(video.url)}</BaseURL>$vSegment</Representation></AdaptationSet>
  <AdaptationSet mimeType="$aMime" subsegmentAlignment="true" subsegmentStartsWithSAP="1"><Representation id="audio" bandwidth="${audio.bitrate.coerceAtLeast(128000)}" codecs="$aCodec"><BaseURL>${escape(audio.url)}</BaseURL>$aSegment</Representation></AdaptationSet>
 </Period>
</MPD>"""
    }

    private fun segment(init: String?, index: String?): String = if (init != null && index != null) "<SegmentBase indexRange=\"$index\"><Initialization range=\"$init\" /></SegmentBase>" else ""
    private fun escape(value: String): String = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
}

private class OkHttpLikeDownloader : Downloader() {
    override fun execute(request: Request): Response {
        val connection = (URL(request.url()).openConnection() as HttpURLConnection).apply {
            requestMethod = request.httpMethod()
            connectTimeout = 20000
            readTimeout = 20000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/122 Safari/537.36")
            request.headers().forEach { (name, values) -> if (values.isNotEmpty()) setRequestProperty(name, values.joinToString(",")) }
            request.dataToSend()?.let { data -> doOutput = true; outputStream.use { it.write(data) } }
        }
        val code = connection.responseCode
        val stream = if (code >= 400) connection.errorStream else connection.inputStream
        val body = stream?.bufferedReader()?.use { it.readText() } ?: ""
        val headers = connection.headerFields.filterKeys { it != null }.mapKeys { it.key!! }
        return Response(code, connection.responseMessage ?: "", headers, body, connection.url.toString())
    }
}

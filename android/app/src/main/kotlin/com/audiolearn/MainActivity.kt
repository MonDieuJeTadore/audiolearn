package com.audiolearn

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val ytDlpChannelName = "audiolearn/yt_dlp"
    private val batteryChannelName = "com.audiolearn/battery_optimization"
    private val logTag = "AudioLearnYtDlp"

    // SharedPreferences used to remember when yt-dlp was last updated.
    private val ytDlpPrefsName = "audiolearn_yt_dlp"
    private val lastUpdateCheckKey = "last_update_check_millis"
    private val updateCheckIntervalMillis = 24L * 60L * 60L * 1000L // 1 day

    // Same template as the Windows implementation so that Dart parses
    // progress lines identically on both platforms.
    private val progressTemplate =
        "download:PROGRESS|%(progress._percent_str)s|%(progress.downloaded_bytes)s|" +
            "%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s"

    // yt-dlp extractor arguments tried in sequence when a download fails.
    // null = yt-dlp default YouTube clients. The following entries are
    // fallbacks for videos where YouTube forces SABR streaming or returns
    // HTTP 403 for the default clients. android_vr does not require a
    // JavaScript runtime, which is not available inside the APK.
    private val youtubeExtractorArgsAttempts = listOf(
        null,
        "youtube:player_client=android_vr",
        "youtube:player_client=tv,ios",
    )

    // Single thread: yt-dlp calls are executed sequentially, never on the UI thread.
    private val ytDlpExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var ytDlpChannel: MethodChannel? = null

    @Volatile
    private var isYtDlpInitialized = false

    @Volatile
    private var wasYtDlpUpdateAttempted = false

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(flutterEngine)

        configureYtDlpChannel(flutterEngine)
        configureBatteryOptimizationChannel(flutterEngine)

        // Initializing and updating yt-dlp in background at startup so that
        // the first download uses an up to date yt-dlp version.
        ytDlpExecutor.execute {
            try {
                ensureYtDlpInitialized()
                updateYtDlpIfNeeded(force = false)
            } catch (e: Exception) {
                Log.e(logTag, "yt-dlp startup initialization failed.", e)
            }
        }
    }

    override fun onDestroy() {
        ytDlpChannel?.setMethodCallHandler(null)
        ytDlpChannel = null

        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // yt-dlp channel
    // ------------------------------------------------------------------

    private fun configureYtDlpChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ytDlpChannelName,
        )

        ytDlpChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPlaylistVideos" -> {
                    val playlistUrl = call.argument<String>("playlistUrl")

                    if (playlistUrl.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "playlistUrl is missing.",
                            null,
                        )
                    } else {
                        runInBackground(result, "PLAYLIST_ERROR") {
                            getPlaylistVideos(playlistUrl)
                        }
                    }
                }

                "downloadAudio" -> {
                    val videoUrl = call.argument<String>("videoUrl")
                    val targetDirectory = call.argument<String>("targetDirectory")
                    val temporaryBaseFileName =
                        call.argument<String>("temporaryBaseFileName")

                    if (
                        videoUrl.isNullOrBlank() ||
                        targetDirectory.isNullOrBlank() ||
                        temporaryBaseFileName.isNullOrBlank()
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Missing download arguments.",
                            null,
                        )
                    } else {
                        runInBackground(result, "YT_DLP_ERROR") {
                            downloadAudioWithFallbacks(
                                videoUrl = videoUrl,
                                targetDirectory = targetDirectory,
                                temporaryBaseFileName = temporaryBaseFileName,
                            )
                        }
                    }
                }

                "cancelDownload" -> {
                    val processId = call.argument<String>("processId")

                    if (processId.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        result.success(
                            YoutubeDL.getInstance().destroyProcessById(processId),
                        )
                    }
                }

                "updateYtDlp" -> {
                    runInBackground(result, "UPDATE_ERROR") {
                        ensureYtDlpInitialized()
                        updateYtDlpIfNeeded(force = true)
                    }
                }

                "getYtDlpVersion" -> {
                    runInBackground(result, "VERSION_ERROR") {
                        ensureYtDlpInitialized()
                        YoutubeDL.getInstance().versionName(applicationContext)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /// Initializes youtubedl-android lazily. The first call extracts the
    /// embedded Python interpreter and yt-dlp, which may take a few seconds,
    /// so it is always executed on the background executor.
    private fun ensureYtDlpInitialized() {
        if (!isYtDlpInitialized) {
            YoutubeDL.getInstance().init(applicationContext)
            isYtDlpInitialized = true
        }
    }

    /// The yt-dlp version embedded in the library quickly becomes too old
    /// for YouTube (HTTP 403, SABR streaming). This method downloads the
    /// latest stable yt-dlp, at most once a day unless [force] is true.
    ///
    /// Returns the update status name, or null if no update was attempted.
    /// An update failure (no network, GitHub unreachable) is logged and
    /// never prevents a download attempt with the current version.
    private fun updateYtDlpIfNeeded(force: Boolean): String? {
        val prefs = applicationContext.getSharedPreferences(
            ytDlpPrefsName,
            Context.MODE_PRIVATE,
        )
        val now = System.currentTimeMillis()
        val lastCheck = prefs.getLong(lastUpdateCheckKey, 0L)

        if (!force && now - lastCheck < updateCheckIntervalMillis) {
            return null
        }

        return try {
            val status = YoutubeDL.getInstance().updateYoutubeDL(
                applicationContext,
                YoutubeDL.UpdateChannel._STABLE,
            )

            prefs.edit().putLong(lastUpdateCheckKey, now).apply()
            wasYtDlpUpdateAttempted = true

            Log.i(
                logTag,
                "yt-dlp update status: ${status?.name}, version: " +
                    YoutubeDL.getInstance().versionName(applicationContext),
            )

            status?.name
        } catch (e: Exception) {
            Log.e(logTag, "yt-dlp update failed.", e)
            null
        }
    }

    private fun runInBackground(
        result: MethodChannel.Result,
        errorCode: String,
        task: () -> Any?,
    ) {
        ytDlpExecutor.execute {
            try {
                val value = task()

                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                Log.e(logTag, "yt-dlp call failed.", e)

                mainHandler.post {
                    result.error(
                        errorCode,
                        e.message ?: "Unknown yt-dlp error.",
                        e.stackTraceToString(),
                    )
                }
            }
        }
    }

    private fun getPlaylistVideos(playlistUrl: String): List<Map<String, String>> {
        ensureYtDlpInitialized()

        val request = YoutubeDLRequest(playlistUrl).apply {
            addOption("--flat-playlist")
            addOption("--dump-single-json")
            addOption("--no-warnings")
        }

        val response = YoutubeDL.getInstance().execute(request)
        val json = JSONObject(response.out)
        val entries = json.optJSONArray("entries") ?: return emptyList()
        val videos = mutableListOf<Map<String, String>>()

        for (i in 0 until entries.length()) {
            val entry = entries.optJSONObject(i) ?: continue
            val id = entry.optString("id", "")

            if (id.isEmpty()) {
                continue
            }

            videos.add(
                mapOf(
                    "id" to id,
                    "title" to entry.optString("title", ""),
                    "url" to "https://www.youtube.com/watch?v=$id",
                ),
            )
        }

        return videos
    }

    /// Tries the download with the default YouTube clients first, then with
    /// the fallback clients of youtubeExtractorArgsAttempts. If every attempt
    /// fails and yt-dlp was not yet updated during this app session, yt-dlp
    /// is updated and the attempts are executed once more.
    private fun downloadAudioWithFallbacks(
        videoUrl: String,
        targetDirectory: String,
        temporaryBaseFileName: String,
    ): Map<String, Any?> {
        ensureYtDlpInitialized()

        var result = tryAllExtractorArgs(
            videoUrl = videoUrl,
            targetDirectory = targetDirectory,
            temporaryBaseFileName = temporaryBaseFileName,
        )

        if (result["success"] != true &&
            result["cancelled"] != true &&
            !wasYtDlpUpdateAttempted
        ) {
            Log.i(logTag, "All attempts failed: updating yt-dlp and retrying.")

            updateYtDlpIfNeeded(force = true)

            result = tryAllExtractorArgs(
                videoUrl = videoUrl,
                targetDirectory = targetDirectory,
                temporaryBaseFileName = temporaryBaseFileName,
            )
        }

        return result
    }

    private fun tryAllExtractorArgs(
        videoUrl: String,
        targetDirectory: String,
        temporaryBaseFileName: String,
    ): Map<String, Any?> {
        val outputs = StringBuilder()
        var lastResult: Map<String, Any?> = emptyMap()

        for (extractorArgs in youtubeExtractorArgsAttempts) {
            deletePartialFiles(targetDirectory, temporaryBaseFileName)

            lastResult = downloadAudio(
                videoUrl = videoUrl,
                targetDirectory = targetDirectory,
                temporaryBaseFileName = temporaryBaseFileName,
                extractorArgs = extractorArgs,
            )

            if (lastResult["success"] == true || lastResult["cancelled"] == true) {
                return lastResult
            }

            outputs
                .append("--- Attempt with ")
                .append(extractorArgs ?: "default clients")
                .append(" ---\n")
                .append(lastResult["output"] ?: "")
                .append('\n')

            Log.w(logTag, "Download attempt failed with ${extractorArgs ?: "default clients"}.")
        }

        deletePartialFiles(targetDirectory, temporaryBaseFileName)

        return lastResult + mapOf("output" to outputs.toString())
    }

    /// Downloads the best audio-only stream without converting it. The MP3
    /// conversion is done afterwards on the Dart side by FFmpegKit.
    ///
    /// The temporaryBaseFileName is used as yt-dlp process id so that the
    /// download can be cancelled with the "cancelDownload" method.
    private fun downloadAudio(
        videoUrl: String,
        targetDirectory: String,
        temporaryBaseFileName: String,
        extractorArgs: String?,
    ): Map<String, Any?> {
        val outputTemplate =
            "$targetDirectory${File.separator}$temporaryBaseFileName.%(ext)s"

        val request = YoutubeDLRequest(videoUrl).apply {
            addOption("--newline")
            addOption("--no-playlist")
            addOption("--no-update")
            addOption("--progress-template", progressTemplate)
            // m4a first: single stream, no merge needed (no ffmpeg required
            // by yt-dlp itself)
            addOption("-f", "bestaudio[ext=m4a]/bestaudio/best")
            addOption("-o", outputTemplate)

            if (extractorArgs != null) {
                addOption("--extractor-args", extractorArgs)
            }
        }

        return try {
            val response = YoutubeDL.getInstance().execute(
                request,
                temporaryBaseFileName,
            ) { _: Float, _: Long, line: String ->
                // Forward the raw line: Dart parses it with the same code
                // as on Windows.
                mainHandler.post {
                    ytDlpChannel?.invokeMethod(
                        "onProgress",
                        mapOf("line" to line),
                    )
                }
            }

            val output = "${response.out}\n${response.err}"
            val downloadedFilePath = findDownloadedFile(
                targetDirectory = targetDirectory,
                temporaryBaseFileName = temporaryBaseFileName,
            )

            mapOf(
                "success" to (downloadedFilePath != null),
                "downloadedFilePath" to downloadedFilePath,
                "output" to if (downloadedFilePath == null) {
                    "yt-dlp completed but the downloaded file was not found.\n$output"
                } else {
                    output
                },
            )
        } catch (e: YoutubeDL.CanceledException) {
            mapOf(
                "success" to false,
                "cancelled" to true,
                "downloadedFilePath" to null,
                "output" to "Download cancelled.",
            )
        } catch (e: YoutubeDLException) {
            Log.e(logTag, "Audio download failed.", e)

            mapOf(
                "success" to false,
                "downloadedFilePath" to null,
                "output" to (e.message ?: e.toString()),
            )
        }
    }

    private fun findDownloadedFile(
        targetDirectory: String,
        temporaryBaseFileName: String,
    ): String? {
        val directory = File(targetDirectory)

        if (!directory.exists()) {
            return null
        }

        return directory
            .listFiles()
            ?.firstOrNull { file ->
                file.isFile &&
                    file.name.startsWith("$temporaryBaseFileName.") &&
                    !file.name.endsWith(".part") &&
                    !file.name.endsWith(".ytdl")
            }
            ?.absolutePath
    }

    /// Removes the .part / .ytdl files left by a failed attempt so that the
    /// next attempt starts from a clean state.
    private fun deletePartialFiles(
        targetDirectory: String,
        temporaryBaseFileName: String,
    ) {
        File(targetDirectory)
            .listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.name.startsWith("$temporaryBaseFileName.") &&
                    (file.name.endsWith(".part") || file.name.endsWith(".ytdl"))
            }
            ?.forEach { file -> file.delete() }
    }

    // ------------------------------------------------------------------
    // Battery optimization / foreground service channel (unchanged)
    // ------------------------------------------------------------------

    private fun configureBatteryOptimizationChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            batteryChannelName,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(
                            pm.isIgnoringBatteryOptimizations(packageName),
                        )
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }

                    "startForegroundService" -> {
                        val intent = Intent(
                            this,
                            AudioForegroundService::class.java,
                        ).setAction(AudioForegroundService.ACTION_START)
                        startForegroundService(intent)
                        result.success(null)
                    }

                    "stopForegroundService" -> {
                        stopService(
                            Intent(this, AudioForegroundService::class.java),
                        )
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e("AudioLearnBattery", "${call.method} failed.", e)
                result.error("BATTERY_SERVICE_ERROR", e.message, null)
            }
        }
    }
}
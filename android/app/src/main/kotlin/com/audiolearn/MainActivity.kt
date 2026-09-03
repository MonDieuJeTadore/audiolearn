package com.audiolearn

import android.util.Log
import dev.ffmpegkit_maintained.ytdlp.YtDlp
import dev.ffmpegkit_maintained.ytdlp.YtDlpException
import dev.ffmpegkit_maintained.ytdlp.YtDlpRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "audiolearn/yt_dlp"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        try {
            YtDlp.init(applicationContext)
        } catch (e: YtDlpException) {
            Log.e(
                "AudioLearnYtDlp",
                "Unable to initialize yt-dlp.",
                e
            )
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAudio" -> {
                    val videoUrl =
                        call.argument<String>("videoUrl")

                    val targetDirectory =
                        call.argument<String>("targetDirectory")

                    val temporaryBaseFileName =
                        call.argument<String>(
                            "temporaryBaseFileName"
                        )

                    if (
                        videoUrl == null ||
                        targetDirectory == null ||
                        temporaryBaseFileName == null
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Missing download arguments.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    downloadAudio(
                        videoUrl = videoUrl,
                        targetDirectory = targetDirectory,
                        temporaryBaseFileName =
                            temporaryBaseFileName,
                        result = result
                    )
                }

                "getPlaylistVideos" -> {
                    result.error(
                        "NOT_IMPLEMENTED",
                        "getPlaylistVideos is not implemented yet.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun downloadAudio(
        videoUrl: String,
        targetDirectory: String,
        temporaryBaseFileName: String,
        result: MethodChannel.Result
    ) {
        thread {
            try {
                val outputTemplate =
                    "$targetDirectory/$temporaryBaseFileName.%(ext)s"

                val request =
                    YtDlpRequest(videoUrl)
                        .setOutputTemplate(outputTemplate)
                        .addOption(
                            "-f",
                            "bestaudio[ext=m4a]/bestaudio/best"
                        )
                        .addOption("--no-playlist")
                        .addOption(
                            "--extractor-args",
                            "youtube:player_client=android_sdkless,ios"
                        )
                        .addOption("--verbose")

                val future = YtDlp.executeAsync(
                    request
                ) { progress, eta, line ->
                    Log.i(
                        "AudioLearnYtDlp",
                        "$progress% - ETA $eta - $line"
                    )
                }

                val response = future.get()

                val downloadedFilePath =
                    findDownloadedFile(
                        targetDirectory = targetDirectory,
                        temporaryBaseFileName =
                            temporaryBaseFileName
                    )

                runOnUiThread {
                    if (downloadedFilePath == null) {
                        result.error(
                            "FILE_NOT_FOUND",
                            "yt-dlp completed but the downloaded file was not found.",
                            response.toString()
                        )
                    } else {
                        result.success(
                            mapOf(
                                "success" to true,
                                "downloadedFilePath" to
                                    downloadedFilePath,
                                "output" to
                                    response.toString()
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e(
                    "AudioLearnYtDlp",
                    "Audio download failed.",
                    e
                )

                runOnUiThread {
                    result.error(
                        "YT_DLP_ERROR",
                        e.message
                            ?: "Unknown yt-dlp error.",
                        e.toString()
                    )
                }
            }
        }
    }

    private fun findDownloadedFile(
        targetDirectory: String,
        temporaryBaseFileName: String
    ): String? {
        val directory = File(targetDirectory)

        if (!directory.exists()) {
            return null
        }

        return directory
            .listFiles()
            ?.firstOrNull { file ->
                file.isFile &&
                    file.name.startsWith(
                        "$temporaryBaseFileName."
                    )
            }
            ?.absolutePath
    }
}
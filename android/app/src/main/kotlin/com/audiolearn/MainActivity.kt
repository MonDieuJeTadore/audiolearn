package com.audiolearn

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "audiolearn/yt_dlp"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAudio" -> {
                    // yt-dlp Android download
                }

                "getPlaylistVideos" -> {
                    // yt-dlp playlist extraction
                }

                else -> result.notImplemented()
            }
        }
    }
}
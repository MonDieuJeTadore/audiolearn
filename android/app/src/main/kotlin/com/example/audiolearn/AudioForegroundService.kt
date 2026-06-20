package com.audiolearn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder

class AudioForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "audiolearn_playback"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "START"
        const val ACTION_STOP = "STOP"
    }

    override fun onCreate() {
        super.onCreate()
        val channel = NotificationChannel(
            CHANNEL_ID,
            "AudioLearn Lecture",
            NotificationManager.IMPORTANCE_LOW // LOW = pas de son pour la notif
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val notification = Notification.Builder(this, CHANNEL_ID)
                    .setContentTitle("AudioLearn")
                    .setContentText("Lecture en cours...")
                    .setSmallIcon(android.R.drawable.ic_media_play)
                    .build()
                startForeground(NOTIFICATION_ID, notification)
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
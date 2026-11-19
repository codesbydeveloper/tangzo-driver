package com.tangzo.driver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that loops the order ringtone even when Flutter is paused/killed.
 */
class OrderRingtoneService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRingtone()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val url = intent?.getStringExtra(EXTRA_URL)
                    ?: readStoredRingtoneUrl(this)
                    ?: ""
                // Silent FGS notification only (Android requires one). Order alert UI stays on FCM/Flutter.
                startForegroundSilent()
                startRingtone(url)
            }
        }
        return START_STICKY
    }

    private fun startForegroundSilent() {
        ensureChannel()
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: Intent()
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tangzo")
            .setContentText("Playing order alert")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(pending)
            .setOngoing(true)
            .setSilent(true)
            .setSound(null)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tangzo:order_ringtone").apply {
            setReferenceCounted(false)
            acquire(10 * 60 * 1000L)
        }
    }

    private fun startRingtone(url: String) {
        stopPlayerOnly()
        if (url.isBlank()) {
            Log.w(TAG, "No ringtone URL — playing default alarm stream tone via silence skip")
            return
        }
        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setLegacyStreamType(AudioManager.STREAM_ALARM)
                        .build(),
                )
                isLooping = true
                setDataSource(url)
                setOnPreparedListener { it.start() }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    true
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start ringtone", e)
        }
    }

    private fun stopRingtone() {
        stopPlayerOnly()
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
        }
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun stopPlayerOnly() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java)
        // Low/silent channel so FGS does not create a second order alert notification.
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Tangzo Ringtone Service",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps order ringtone playing in background"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        mgr?.createNotificationChannel(channel)
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "OrderRingtoneService"
        const val ACTION_START = "com.tangzo.driver.action.START_ORDER_RINGTONE"
        const val ACTION_STOP = "com.tangzo.driver.action.STOP_ORDER_RINGTONE"
        const val EXTRA_URL = "ringtone_url"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        private const val CHANNEL_ID = "tangzo_ringtone_fg_silent"
        private const val NOTIFICATION_ID = 42001

        fun start(
            context: Context,
            url: String?,
            title: String? = null,
            body: String? = null,
        ) {
            val intent = Intent(context, OrderRingtoneService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, OrderRingtoneService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
                context.stopService(Intent(context, OrderRingtoneService::class.java))
            }
        }

        fun readStoredRingtoneUrl(context: Context): String? {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            return prefs.getString("flutter.audioSound", null)?.takeIf { it.isNotBlank() }
        }

        fun shouldRing(data: Map<String, String>, hasNotificationTitle: String?): Boolean {
            val type = (data["type"] ?: "").lowercase()
            if (type.contains("cancel") || type.contains("reject") || type.contains("complete")) {
                return false
            }
            if (data["play_ringtone"] == "true") return true
            if (type == "new_order") return true
            if (data["status"] == "Driver Pending") return true
            val title = (data["title"] ?: hasNotificationTitle ?: "").lowercase()
            return title.contains("new order") || title.contains("order received")
        }
    }
}

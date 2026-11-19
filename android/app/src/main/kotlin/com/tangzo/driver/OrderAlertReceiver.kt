package com.tangzo.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * High-priority C2DM receiver that starts the looping ringtone before Flutter wakes.
 * Parses FCM extras from the Bundle (no Firebase Messaging compile dependency).
 */
class OrderAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val extras = intent?.extras ?: return
            val data = bundleToStringMap(extras)
            val notifTitle = data["gcm.notification.title"]
                ?: data["google.notification.title"]
                ?: data["title"]
            if (!OrderRingtoneService.shouldRing(data, notifTitle)) return

            val url = data["ringtone_url"]
                ?: OrderRingtoneService.readStoredRingtoneUrl(context)
            val title = (data["title"] ?: notifTitle ?: "New order")
            val body = data["body"]
                ?: data["gcm.notification.body"]
                ?: data["google.notification.body"]
                ?: "Incoming Tangzo order"
            Log.d(TAG, "Starting order ringtone from FCM")
            OrderRingtoneService.start(context, url, title, body)
        } catch (e: Exception) {
            Log.e(TAG, "OrderAlertReceiver failed", e)
        }
    }

    private fun bundleToStringMap(extras: Bundle): Map<String, String> {
        val out = HashMap<String, String>()
        for (key in extras.keySet()) {
            val value = extras.get(key) ?: continue
            out[key] = value.toString()
        }
        return out
    }

    companion object {
        private const val TAG = "OrderAlertReceiver"
    }
}

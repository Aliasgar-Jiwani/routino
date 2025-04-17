package com.aliasgar.routino

import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager

class AppKillService : Service() {

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)

        val channelId = "app_kill_channel"
        val channelName = "App Termination Notifications"

        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = Notification.Builder(this, channelId)
            .setContentTitle("Routino Closed")
            .setContentText("You removed Routino from recent apps.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(1001, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

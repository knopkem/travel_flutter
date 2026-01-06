package com.locationpal.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Helper to ensure foreground service notification is non-dismissible
 */
object ForegroundServiceHelper {
    private const val CHANNEL_ID = "background_geofence_channel"
    private const val CHANNEL_NAME = "Shopping Reminders"
    private const val NOTIFICATION_ID = 888

    /**
     * Create notification channel for the foreground service
     */
    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW  // Low importance for persistent notification
            ).apply {
                description = "Monitors your shopping list locations in the background"
                setShowBadge(false)
                // Don't make sound or vibrate for this persistent notification
                enableVibration(false)
                enableLights(false)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create a non-dismissible notification for the foreground service
     */
    fun createForegroundNotification(context: Context): android.app.Notification {
        createNotificationChannel(context)
        
        // Intent to open app when notification is tapped
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Shopping Reminders")
            .setContentText("Monitoring your shopping locations")
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setOngoing(true)  // CRITICAL: Makes notification non-dismissible
            .setAutoCancel(false)  // Prevents dismissal on tap
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)  // Low priority for less intrusive
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    fun getNotificationId(): Int = NOTIFICATION_ID
}

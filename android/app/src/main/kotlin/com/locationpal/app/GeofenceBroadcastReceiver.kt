package com.locationpal.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "GeofenceReceiver"
        private const val CHANNEL_NAME = "com.app/geofence"
        private const val NOTIFICATION_CHANNEL_ID = "geofence_notifications"
        private const val NOTIFICATION_CHANNEL_NAME = "Location Reminders"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Geofence event received")

        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent == null) {
            Log.e(TAG, "GeofencingEvent is null")
            return
        }

        if (geofencingEvent.hasError()) {
            Log.e(TAG, "Geofencing error: ${geofencingEvent.errorCode}")
            return
        }

        val geofenceTransition = geofencingEvent.geofenceTransition
        val triggeringGeofences = geofencingEvent.triggeringGeofences

        if (triggeringGeofences == null || triggeringGeofences.isEmpty()) {
            Log.w(TAG, "No triggering geofences")
            return
        }

        for (geofence in triggeringGeofences) {
            val geofenceId = geofence.requestId
            
            when (geofenceTransition) {
                Geofence.GEOFENCE_TRANSITION_ENTER -> {
                    Log.d(TAG, "Entered geofence: $geofenceId")
                    invokeFlutterMethod(context, "onGeofenceEnter", geofenceId)
                }
                Geofence.GEOFENCE_TRANSITION_DWELL -> {
                    Log.d(TAG, "Dwelling at geofence: $geofenceId")
                    // For dwell events, show notification directly since this is the trigger
                    showReminderNotification(context, geofenceId)
                    invokeFlutterMethod(context, "onGeofenceDwell", geofenceId)
                }
                Geofence.GEOFENCE_TRANSITION_EXIT -> {
                    Log.d(TAG, "Exited geofence: $geofenceId")
                    invokeFlutterMethod(context, "onGeofenceExit", geofenceId)
                }
                else -> {
                    Log.w(TAG, "Unknown geofence transition: $geofenceTransition")
                }
            }
        }
    }

    /**
     * Invoke Flutter method via MethodChannel
     * This only works if the Flutter app is running
     */
    private fun invokeFlutterMethod(context: Context, method: String, geofenceId: String) {
        try {
            // Try to invoke method on active Flutter engine if app is running
            // Note: This won't work if app is killed - notifications handle that case
            val flutterEngine = FlutterEngine(context)
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.invokeMethod(method, mapOf("id" to geofenceId))
        } catch (e: Exception) {
            Log.d(TAG, "Could not invoke Flutter method (app may not be running): ${e.message}")
            // This is expected if app is not running - notification will handle it
        }
    }

    /**
     * Show notification for geofence dwell event
     */
    private fun showReminderNotification(context: Context, geofenceId: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for Android O+
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for location-based reminders"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent to open app when notification is tapped
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        launchIntent?.putExtra("geofenceId", geofenceId)
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            geofenceId.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Load reminder details from SharedPreferences
        val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val remindersJson = sharedPrefs.getString("flutter.shopping_reminders", null)
        
        var title = "Location Reminder"
        var message = "You're near a saved location"
        
        if (remindersJson != null) {
            try {
                // Parse JSON to find reminder details - simplified parsing
                val brandStart = remindersJson.indexOf("\"brandName\":\"")
                if (brandStart > 0) {
                    val brandEnd = remindersJson.indexOf("\"", brandStart + 13)
                    val brandName = remindersJson.substring(brandStart + 13, brandEnd)
                    title = brandName
                    message = "You've arrived at $brandName"
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing reminder details: ${e.message}")
            }
        }

        // Build notification
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(geofenceId.hashCode(), notification)
        Log.d(TAG, "Notification shown for geofence: $geofenceId")
    }
}

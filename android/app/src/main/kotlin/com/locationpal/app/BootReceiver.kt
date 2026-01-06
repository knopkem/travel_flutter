package com.locationpal.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import org.json.JSONArray

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED && 
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        Log.d(TAG, "Device boot completed (action: $action), re-registering geofences")

        try {
            // Load persisted geofence IDs and details from SharedPreferences
            val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val remindersJson = sharedPrefs.getString("flutter.shopping_reminders", null)
            val dwellTimeMinutes = sharedPrefs.getInt("flutter.dwell_time_minutes", 1)
            val proximityRadius = sharedPrefs.getInt("flutter.proximity_radius_meters", 150)

            if (remindersJson == null) {
                Log.d(TAG, "No reminders to re-register")
                return
            }

            // Parse reminders JSON
            val remindersArray = JSONArray(remindersJson)
            val geofenceManager = GeofenceManager(context)

            for (i in 0 until remindersArray.length()) {
                val reminder = remindersArray.getJSONObject(i)
                val id = reminder.getString("id")
                val latitude = reminder.getDouble("latitude")
                val longitude = reminder.getDouble("longitude")

                // Re-register geofence
                geofenceManager.registerGeofence(
                    id = id,
                    latitude = latitude,
                    longitude = longitude,
                    radius = proximityRadius.toFloat(),
                    dwellTimeMs = dwellTimeMinutes * 60 * 1000,
                    onSuccess = {
                        Log.d(TAG, "Re-registered geofence: $id")
                    },
                    onFailure = { error ->
                        Log.e(TAG, "Failed to re-register geofence $id: $error")
                    }
                )
            }

            Log.d(TAG, "Finished re-registering ${remindersArray.length()} geofences")
            
            // Restart the background service if monitoring was active
            val monitoringEnabled = sharedPrefs.getBoolean("flutter.monitoring_enabled", false)
            if (monitoringEnabled && remindersArray.length() > 0) {
                restartBackgroundService(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error re-registering geofences: ${e.message}", e)
        }
    }
    
    /**
     * Restart the location monitor service to show the persistent notification
     */
    private fun restartBackgroundService(context: Context) {
        try {
            // Create notification channel first to avoid "Bad notification" error
            createNotificationChannel(context)
            
            // Start our custom foreground service with non-dismissible notification
            LocationMonitorService.startService(context)
            Log.d(TAG, "Location monitor service restarted successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart location monitor service: ${e.message}", e)
        }
    }
    
    /**
     * Create notification channel for background service
     */
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "background_geofence_channel",
                "Shopping Reminders",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors your shopping list locations in the background"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }
}

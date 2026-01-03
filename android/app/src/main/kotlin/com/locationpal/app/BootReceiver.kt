package com.locationpal.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import org.json.JSONArray

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        Log.d(TAG, "Device boot completed, re-registering geofences")

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
        } catch (e: Exception) {
            Log.e(TAG, "Error re-registering geofences: ${e.message}", e)
        }
    }
}

package com.locationpal.app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

class GeofenceManager(private val context: Context) {
    private val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)
    private val geofencePendingIntent: PendingIntent by lazy {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }

    companion object {
        private const val TAG = "GeofenceManager"
    }

    /**
     * Register a geofence with the given parameters
     * @param id Unique identifier for the geofence
     * @param latitude Latitude of the geofence center
     * @param longitude Longitude of the geofence center
     * @param radius Radius in meters
     * @param dwellTimeMs Dwell time in milliseconds for DWELL transition
     */
    fun registerGeofence(
        id: String,
        latitude: Double,
        longitude: Double,
        radius: Float,
        dwellTimeMs: Int,
        onSuccess: () -> Unit,
        onFailure: (String) -> Unit
    ) {
        try {
            val geofence = Geofence.Builder()
                .setRequestId(id)
                .setCircularRegion(latitude, longitude, radius)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(
                    Geofence.GEOFENCE_TRANSITION_ENTER or
                    Geofence.GEOFENCE_TRANSITION_DWELL or
                    Geofence.GEOFENCE_TRANSITION_EXIT
                )
                .setLoiteringDelay(dwellTimeMs)
                .build()

            val geofencingRequest = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER or GeofencingRequest.INITIAL_TRIGGER_DWELL)
                .addGeofence(geofence)
                .build()

            geofencingClient.addGeofences(geofencingRequest, geofencePendingIntent).run {
                addOnSuccessListener {
                    Log.d(TAG, "Geofence registered: $id")
                    onSuccess()
                }
                addOnFailureListener { exception ->
                    val errorMsg = "Failed to register geofence: ${exception.message}"
                    Log.e(TAG, errorMsg, exception)
                    onFailure(errorMsg)
                }
            }
        } catch (e: SecurityException) {
            val errorMsg = "Location permission not granted: ${e.message}"
            Log.e(TAG, errorMsg, e)
            onFailure(errorMsg)
        }
    }

    /**
     * Unregister a geofence by its ID
     */
    fun unregisterGeofence(
        id: String,
        onSuccess: () -> Unit,
        onFailure: (String) -> Unit
    ) {
        geofencingClient.removeGeofences(listOf(id)).run {
            addOnSuccessListener {
                Log.d(TAG, "Geofence unregistered: $id")
                onSuccess()
            }
            addOnFailureListener { exception ->
                val errorMsg = "Failed to unregister geofence: ${exception.message}"
                Log.e(TAG, errorMsg, exception)
                onFailure(errorMsg)
            }
        }
    }

    /**
     * Unregister all geofences
     */
    fun unregisterAll(
        onSuccess: () -> Unit,
        onFailure: (String) -> Unit
    ) {
        geofencingClient.removeGeofences(geofencePendingIntent).run {
            addOnSuccessListener {
                Log.d(TAG, "All geofences unregistered")
                onSuccess()
            }
            addOnFailureListener { exception ->
                val errorMsg = "Failed to unregister all geofences: ${exception.message}"
                Log.e(TAG, errorMsg, exception)
                onFailure(errorMsg)
            }
        }
    }
}

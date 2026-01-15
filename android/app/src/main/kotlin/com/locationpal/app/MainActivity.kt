package com.locationpal.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val GEOFENCE_CHANNEL = "com.app/geofence"
    private val SERVICE_CHANNEL = "com.app/foreground_service"
    private lateinit var geofenceManager: GeofenceManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Create notification channel for background service BEFORE it tries to start
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        geofenceManager = GeofenceManager(applicationContext)
        
        // Setup foreground service control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        LocationMonitorService.startService(applicationContext)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        LocationMonitorService.stopService(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEOFENCE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPlayServicesAvailable" -> {
                        val availability = GoogleApiAvailability.getInstance()
                        val resultCode = availability.isGooglePlayServicesAvailable(applicationContext)
                        val isAvailable = resultCode == ConnectionResult.SUCCESS
                        result.success(isAvailable)
                    }
                    "registerGeofence" -> {
                        val id = call.argument<String>("id")
                        val latitude = call.argument<Double>("latitude")
                        val longitude = call.argument<Double>("longitude")
                        val radius = call.argument<Double>("radius")
                        val dwellTimeMs = call.argument<Int>("dwellTimeMs")

                        if (id == null || latitude == null || longitude == null || radius == null || dwellTimeMs == null) {
                            result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                            return@setMethodCallHandler
                        }

                        geofenceManager.registerGeofence(
                            id = id,
                            latitude = latitude,
                            longitude = longitude,
                            radius = radius.toFloat(),
                            dwellTimeMs = dwellTimeMs,
                            onSuccess = { result.success(true) },
                            onFailure = { error -> result.error("REGISTER_FAILED", error, null) }
                        )
                    }
                    "unregisterGeofence" -> {
                        val id = call.argument<String>("id")
                        if (id == null) {
                            result.error("INVALID_ARGUMENTS", "Missing geofence id", null)
                            return@setMethodCallHandler
                        }

                        geofenceManager.unregisterGeofence(
                            id = id,
                            onSuccess = { result.success(true) },
                            onFailure = { error -> result.error("UNREGISTER_FAILED", error, null) }
                        )
                    }
                    "unregisterAll" -> {
                        geofenceManager.unregisterAll(
                            onSuccess = { result.success(true) },
                            onFailure = { error -> result.error("UNREGISTER_ALL_FAILED", error, null) }
                        )
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    /**
     * Create notification channel for background geofence service
     * Must be called before the service starts to avoid "Bad notification" error
     */
    private fun createNotificationChannel() {
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

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}

package com.locationpal.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val GEOFENCE_CHANNEL = "com.app/geofence"
    private lateinit var geofenceManager: GeofenceManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        geofenceManager = GeofenceManager(applicationContext)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEOFENCE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
}

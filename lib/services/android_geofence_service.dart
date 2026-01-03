import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android geofence service using native GeofencingClient
/// Replaces the old polling-based background service
class AndroidGeofenceService {
  static const MethodChannel _channel = MethodChannel('com.app/geofence');

  /// Register a geofence with the native Android GeofencingClient
  static Future<bool> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
    required int dwellTimeMs,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('AndroidGeofenceService: Not on Android, skipping');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('registerGeofence', {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'dwellTimeMs': dwellTimeMs,
      });
      
      debugPrint('AndroidGeofenceService: Registered geofence $id');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('AndroidGeofenceService: Failed to register geofence: ${e.message}');
      return false;
    }
  }

  /// Unregister a geofence by ID
  static Future<bool> unregisterGeofence(String id) async {
    if (!Platform.isAndroid) {
      debugPrint('AndroidGeofenceService: Not on Android, skipping');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('unregisterGeofence', {
        'id': id,
      });
      
      debugPrint('AndroidGeofenceService: Unregistered geofence $id');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('AndroidGeofenceService: Failed to unregister geofence: ${e.message}');
      return false;
    }
  }

  /// Unregister all geofences
  static Future<bool> unregisterAll() async {
    if (!Platform.isAndroid) {
      debugPrint('AndroidGeofenceService: Not on Android, skipping');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('unregisterAll');
      debugPrint('AndroidGeofenceService: Unregistered all geofences');
      
      // Clear registered IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('registered_geofence_ids');
      
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('AndroidGeofenceService: Failed to unregister all geofences: ${e.message}');
      return false;
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'geofence_strategy_manager.dart';

/// Android geofence service using native GeofencingClient
/// Replaces the old polling-based background service
class AndroidGeofenceService {
  static const MethodChannel _channel = MethodChannel('com.app/geofence');

  /// Callback for when geofence registration fails (triggers fallback to polling)
  static Function(String reason)? onGeofenceError;

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
      debugPrint('AndroidGeofenceService: Failed to register geofence: ${e.code} - ${e.message}');
      
      // Trigger fallback to polling on error
      final strategyManager = GeofenceStrategyManager();
      final reason = 'Geofence registration failed: ${e.code}';
      await strategyManager.fallbackToPolling(reason);
      onGeofenceError?.call(reason);
      
      return false;
    } catch (e) {
      debugPrint('AndroidGeofenceService: Unexpected error registering geofence: $e');
      
      // Trigger fallback to polling on unexpected error
      final strategyManager = GeofenceStrategyManager();
      final reason = 'Geofence registration error: $e';
      await strategyManager.fallbackToPolling(reason);
      onGeofenceError?.call(reason);
      
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
      debugPrint('AndroidGeofenceService: Failed to unregister geofence: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AndroidGeofenceService: Unexpected error unregistering geofence: $e');
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
      debugPrint('AndroidGeofenceService: Failed to unregister all geofences: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AndroidGeofenceService: Unexpected error unregistering all geofences: $e');
      return false;
    }
  }
}

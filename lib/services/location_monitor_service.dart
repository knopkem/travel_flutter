import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/poi.dart';
import '../models/reminder.dart';
import 'background_service_manager.dart';

/// Service for monitoring location and triggering reminders
class LocationMonitorService {
  static final LocationMonitorService _instance =
      LocationMonitorService._internal();
  factory LocationMonitorService() => _instance;
  LocationMonitorService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.travel_flutter.geofencing');

  bool _isMonitoring = false;

  bool get isMonitoringEnabled => _isMonitoring;

  /// Update the list of discovered POIs for location checking
  /// Note: On Android, POIs are not needed as the background service checks directly against reminders
  void updateDiscoveredPois(List<POI> pois) {
    // No-op on Android, kept for iOS compatibility
  }

  /// Start location monitoring
  Future<void> startMonitoring(List<Reminder> reminders) async {
    if (_isMonitoring) return;

    if (Platform.isIOS) {
      await _startIOSMonitoring(reminders);
    } else if (Platform.isAndroid) {
      await _startAndroidMonitoring();
    }

    _isMonitoring = true;
  }

  /// Stop location monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    if (Platform.isIOS) {
      await _stopIOSMonitoring();
    } else if (Platform.isAndroid) {
      await _stopAndroidMonitoring();
    }

    _isMonitoring = false;
  }

  /// iOS: Register geofences via native platform channel
  Future<void> _startIOSMonitoring(List<Reminder> reminders) async {
    try {
      // Register geofences for all reminder locations
      for (final reminder in reminders) {
        await _channel.invokeMethod('registerGeofence', {
          'id': reminder.id,
          'latitude': reminder.latitude,
          'longitude': reminder.longitude,
          'radius': 150.0, // 150 meters
        });
      }
    } catch (e) {
      debugPrint('Error starting iOS monitoring: $e');
    }
  }

  /// iOS: Remove all geofences
  Future<void> _stopIOSMonitoring() async {
    try {
      await _channel.invokeMethod('removeAllGeofences');
    } catch (e) {
      debugPrint('Error stopping iOS monitoring: $e');
    }
  }

  /// Android: Start background location monitoring service
  Future<void> _startAndroidMonitoring() async {
    try {
      final started = await BackgroundServiceManager.startService();
      if (!started) {
        debugPrint('Failed to start background service');
      }
    } catch (e) {
      debugPrint('Error starting Android monitoring: $e');
    }
  }

  /// Android: Stop background location monitoring service
  Future<void> _stopAndroidMonitoring() async {
    try {
      await BackgroundServiceManager.stopService();
    } catch (e) {
      debugPrint('Error stopping Android monitoring: $e');
    }
  }

  /// Request foreground location permission
  Future<bool> requestForegroundPermission() async {
    // First check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      // Try to open location settings
      try {
        await Geolocator.openLocationSettings();
      } catch (e) {
        debugPrint('Could not open location settings: $e');
      }
      return false;
    }

    // Check current permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Accept both whileInUse and always for foreground permission
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Request background location permission
  Future<bool> requestBackgroundPermission() async {
    // First check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return false;
    }

    // On Android, use permission_handler for background location
    // On iOS, Geolocator handles it correctly
    if (Platform.isAndroid) {
      // Check if we have foreground permission first
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        debugPrint('Foreground location not granted yet');
        return false;
      }

      // Now request background location permission specifically
      final backgroundStatus = await Permission.locationAlways.request();

      debugPrint('Background location status: $backgroundStatus');
      return backgroundStatus.isGranted;
    } else {
      // iOS: Use Geolocator
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.always;
    }
  }
}

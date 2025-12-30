import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi.dart';
import '../models/reminder.dart';
import '../utils/brand_matcher.dart';
import 'dwell_time_tracker.dart';
import 'notification_service.dart';
import 'reminder_service.dart';

/// Service for monitoring location and triggering reminders
class LocationMonitorService {
  static final LocationMonitorService _instance =
      LocationMonitorService._internal();
  factory LocationMonitorService() => _instance;
  LocationMonitorService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.travel_flutter.geofencing');

  bool _isMonitoring = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationCheckTimer;
  List<POI> _discoveredPois = [];

  bool get isMonitoringEnabled => _isMonitoring;

  /// Update the list of discovered POIs for location checking
  void updateDiscoveredPois(List<POI> pois) {
    _discoveredPois = pois;
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

  /// Android: Start periodic location checks using Timer and location stream
  /// Note: Location stream works when app is in foreground or recently backgrounded
  Future<void> _startAndroidMonitoring() async {
    try {
      // Check location every 5 minutes when app is active
      _locationCheckTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _checkLocationOnAndroid(),
      );
      
      // Also listen to significant location changes
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100, // Update every 100 meters
      );
      
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((position) {
        _handleLocationUpdate(position);
      });
    } catch (e) {
      debugPrint('Error starting Android monitoring: $e');
    }
  }

  /// Android: Stop location monitoring
  Future<void> _stopAndroidMonitoring() async {
    _locationCheckTimer?.cancel();
    _locationCheckTimer = null;
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Manually check current location on Android
  Future<void> _checkLocationOnAndroid() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await _handleLocationUpdate(position);
    } catch (e) {
      debugPrint('Error checking location: $e');
    }
  }

  /// Handle location update and check against reminders
  Future<void> _handleLocationUpdate(Position position) async {
    await checkLocationAgainstReminders(position, _discoveredPois);
  }

  /// Check location against all reminders and trigger notifications if needed
  static Future<void> checkLocationAgainstReminders(
    Position position,
    List<POI> discoveredPois,
  ) async {
    try {
      final reminderService = ReminderService();
      final dwellTracker = DwellTimeTracker();
      final notificationService = NotificationService();

      final reminders = await reminderService.loadReminders();

      for (final reminder in reminders) {
        // Find all POIs matching this reminder's brand
        final matchingPois = discoveredPois.where((poi) {
          return BrandMatcher.doesPoiMatchBrand(poi, reminder.brandName) &&
              poi.type == reminder.poiType;
        }).toList();

        for (final poi in matchingPois) {
          // Calculate distance
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            poi.latitude,
            poi.longitude,
          );

          if (distance <= 150) {
            // Within range
            final entryTime = await dwellTracker.getEntryTime(poi.id);

            if (entryTime == null) {
              // First time entering range - record entry
              await dwellTracker.recordEntry(poi.id);
            } else {
              // Check if dwelled long enough
              if (await dwellTracker.hasDwelledLongEnough(poi.id)) {
                // Trigger notification
                final uncheckedItems = reminder.items
                    .where((item) => !item.isChecked)
                    .map((item) => item.text)
                    .toList();

                if (uncheckedItems.isNotEmpty) {
                  await notificationService.showReminderNotification(
                    poiId: poi.id,
                    poiName: poi.name,
                    brandName: reminder.brandName,
                    items: uncheckedItems,
                  );
                }

                // Clear entry to avoid repeated notifications
                await dwellTracker.clearEntry(poi.id);
              }
            }
          } else {
            // Outside range - clear entry if exists
            await dwellTracker.clearEntry(poi.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking location: $e');
    }
  }

  /// Request background location permission
  Future<bool> requestBackgroundPermission() async {
    // First check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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

    return true;
  }
}

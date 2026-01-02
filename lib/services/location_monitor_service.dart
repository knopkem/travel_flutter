import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/poi.dart';
import '../models/reminder.dart';
import 'background_service_manager.dart';
import 'dwell_time_tracker.dart';
import 'notification_service.dart';
import 'reminder_service.dart';

/// Service for monitoring location and triggering reminders
class LocationMonitorService {
  static final LocationMonitorService _instance =
      LocationMonitorService._internal();
  factory LocationMonitorService() => _instance;
  LocationMonitorService._internal() {
    _setupIOSMethodCallHandler();
  }

  static const MethodChannel _channel =
      MethodChannel('com.travel_flutter.geofencing');

  bool _isMonitoring = false;
  bool _isHandlerSetup = false;

  // Track active dwell timers to prevent duplicates
  final Map<String, Timer> _activeDwellTimers = {};
  // Track reminders that have been notified to prevent duplicates
  final Set<String> _notifiedReminders = {};

  bool get isMonitoringEnabled => _isMonitoring;

  /// Set up method call handler for iOS geofence events
  void _setupIOSMethodCallHandler() {
    if (_isHandlerSetup) return;
    _isHandlerSetup = true;

    _channel.setMethodCallHandler((call) async {
      debugPrint(
          'iOS Geofence event received: ${call.method} with args: ${call.arguments}');

      switch (call.method) {
        case 'onGeofenceEnter':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          await _handleGeofenceEnter(id);
          break;
        case 'onGeofenceExit':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          await _handleGeofenceExit(id);
          break;
        case 'onGeofenceError':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          final error = args['error'] as String;
          debugPrint('Geofence error for $id: $error');
          break;
      }
    });

    debugPrint('iOS Geofence method call handler set up');
  }

  /// Handle entering a geofence
  Future<void> _handleGeofenceEnter(String reminderId) async {
    debugPrint('Entered geofence: $reminderId');

    // Check if we already have an active timer for this reminder
    if (_activeDwellTimers.containsKey(reminderId)) {
      debugPrint(
          'Timer already active for $reminderId, ignoring duplicate enter event');
      return;
    }

    // Check if already notified
    if (_notifiedReminders.contains(reminderId)) {
      debugPrint('Already notified for $reminderId, ignoring');
      return;
    }

    final dwellTracker = DwellTimeTracker();

    // Record entry time
    await dwellTracker.recordEntry(reminderId);

    // Check if we've already dwelled long enough (in case of re-entry)
    final hasDwelled = await dwellTracker.hasDwelledLongEnough(reminderId);

    if (hasDwelled) {
      // Already notified for this, skip
      debugPrint('Already dwelled at $reminderId, skipping notification');
      return;
    }

    // Start a timer to check dwell time
    _startDwellTimer(reminderId);
  }

  /// Handle exiting a geofence
  Future<void> _handleGeofenceExit(String reminderId) async {
    debugPrint('Exited geofence: $reminderId');

    // Cancel any active timer
    _activeDwellTimers[reminderId]?.cancel();
    _activeDwellTimers.remove(reminderId);

    // Clear notified state so user can be notified again on re-entry
    _notifiedReminders.remove(reminderId);

    final dwellTracker = DwellTimeTracker();
    await dwellTracker.clearEntry(reminderId);
  }

  /// Start a timer to check dwell time and send notification
  void _startDwellTimer(String reminderId) {
    debugPrint('Starting dwell timer for $reminderId');

    // Check dwell time periodically
    final timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final dwellTracker = DwellTimeTracker();
      final hasDwelled = await dwellTracker.hasDwelledLongEnough(reminderId);

      if (hasDwelled) {
        timer.cancel();
        _activeDwellTimers.remove(reminderId);
        await _sendReminderNotification(reminderId);
      }

      // Also check if we're still in the geofence (entry time still exists)
      final entryTime = await dwellTracker.getEntryTime(reminderId);
      if (entryTime == null) {
        // User left the geofence, stop timer
        timer.cancel();
        _activeDwellTimers.remove(reminderId);
        debugPrint('User left geofence $reminderId, stopping dwell timer');
      }
    });

    _activeDwellTimers[reminderId] = timer;
  }

  /// Send notification for a reminder
  Future<void> _sendReminderNotification(String reminderId) async {
    // Mark as notified to prevent duplicates
    if (_notifiedReminders.contains(reminderId)) {
      debugPrint('Already notified for $reminderId, skipping');
      return;
    }
    _notifiedReminders.add(reminderId);

    try {
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();

      final reminder = reminders.where((r) => r.id == reminderId).firstOrNull;
      if (reminder == null) {
        debugPrint('Reminder not found for id: $reminderId');
        return;
      }

      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.showReminderNotification(
        poiId: reminder.id,
        poiName: reminder.originalPoiName,
        brandName: reminder.brandName,
        items: reminder.items.map((item) => item.text).toList(),
      );

      debugPrint('Sent notification for reminder: ${reminder.brandName}');
    } catch (e) {
      debugPrint('Error sending reminder notification: $e');
    }
  }

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
      debugPrint('Starting iOS monitoring with ${reminders.length} reminders');
      // Register geofences for all reminder locations
      for (final reminder in reminders) {
        debugPrint(
            'Registering geofence for ${reminder.brandName} at ${reminder.latitude}, ${reminder.longitude}');
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

  /// Check if has foreground location permission
  Future<bool> hasPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if has background location permission
  Future<bool> hasBackgroundPermission() async {
    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.status;
      return backgroundStatus.isGranted;
    } else {
      // iOS
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always;
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

    // Check if we have foreground permission first using Geolocator
    // (This is important because Geolocator was used to request initial permission,
    // and permission_handler may not be in sync on iOS)
    final geolocatorPermission = await Geolocator.checkPermission();
    debugPrint('Geolocator permission status: $geolocatorPermission');

    final hasForegroundPermission =
        geolocatorPermission == LocationPermission.whileInUse ||
            geolocatorPermission == LocationPermission.always;

    if (!hasForegroundPermission) {
      debugPrint(
          'Foreground location not granted yet (Geolocator: $geolocatorPermission)');
      return false;
    }

    // If already have "always" permission via Geolocator, we're done
    if (geolocatorPermission == LocationPermission.always) {
      debugPrint('Already have always permission (via Geolocator)');
      return true;
    }

    // On iOS 13+, when user has "When In Use" permission, we cannot programmatically
    // request an upgrade to "Always". We must direct the user to Settings.
    if (Platform.isIOS) {
      debugPrint(
          'iOS: User has whileInUse, must open Settings for Always permission');
      // Open the app's settings page directly - user needs to tap Location and change to Always
      await openAppSettings();

      // Wait a moment for user to potentially change settings, then re-check
      await Future.delayed(const Duration(milliseconds: 500));

      // Re-check permission after returning from settings
      final newPermission = await Geolocator.checkPermission();
      debugPrint('iOS: Permission after settings: $newPermission');
      return newPermission == LocationPermission.always;
    }

    // Android: Use permission_handler to request background location
    final currentAlwaysStatus = await Permission.locationAlways.status;
    debugPrint('Android locationAlways status: $currentAlwaysStatus');

    if (currentAlwaysStatus.isGranted) {
      debugPrint('Already have always permission (via permission_handler)');
      return true;
    }

    if (currentAlwaysStatus.isPermanentlyDenied) {
      debugPrint('Always permission permanently denied, opening settings');
      await openAppSettings();
      return false;
    }

    // Request background/always location permission on Android
    debugPrint('Android: Requesting locationAlways permission...');
    final backgroundStatus = await Permission.locationAlways.request();
    debugPrint(
        'Android: Background location status after request: $backgroundStatus');

    return backgroundStatus.isGranted;
  }
}

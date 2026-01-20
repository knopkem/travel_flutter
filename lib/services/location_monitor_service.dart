import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi.dart';
import '../models/reminder.dart';
import 'android_geofence_service.dart';
import 'dynamic_geofence_manager.dart';
import 'dwell_time_tracker.dart';
import 'notification_service.dart';
import 'reminder_service.dart';
import 'foreground_notification_service.dart';
import 'geofence_strategy_manager.dart';
import 'debug_log_service.dart';

/// Unified service for monitoring location and triggering reminders on both platforms
/// Uses native geofencing for both iOS and Android
class LocationMonitorService {
  static final LocationMonitorService _instance =
      LocationMonitorService._internal();
  factory LocationMonitorService() => _instance;
  LocationMonitorService._internal() {
    _setupMethodCallHandler();
    _setupPermissionListener();
  }

  static const MethodChannel _channel = MethodChannel('com.app/geofence');

  bool _isMonitoring = false;
  bool _isHandlerSetup = false;

  // Track active dwell timers for iOS (Android handles natively)
  final Map<String, Timer> _activeDwellTimers = {};
  // Track reminders that have been notified to prevent duplicates
  final Set<String> _notifiedReminders = {};
  // Track registered iOS geofences for stats
  int _iosRegisteredGeofenceCount = 0;
  int _iosTotalReminderCount = 0;

  // Dynamic geofence manager for Android only
  DynamicGeofenceManager? _dynamicGeofenceManager;

  // Permission monitoring
  StreamSubscription<ServiceStatus>? _locationServiceSubscription;
  Timer? _permissionCheckTimer;

  bool get isMonitoringEnabled => _isMonitoring;

  /// Set up method call handler for geofence events (both platforms)
  void _setupMethodCallHandler() {
    if (_isHandlerSetup) return;
    _isHandlerSetup = true;

    _channel.setMethodCallHandler((call) async {
      debugPrint(
          'Geofence event received: ${call.method} with args: ${call.arguments}');

      switch (call.method) {
        case 'onGeofenceEnter':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          DebugLogService()
              .log('Entered geofence: $id', type: DebugLogType.event);
          await _handleGeofenceEnter(id);
          break;
        case 'onGeofenceDwell':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          // On Android, dwell event means notification already sent by native receiver
          // Just mark as notified to prevent duplicates
          _notifiedReminders.add(id);
          DebugLogService().log('Dwell event for $id (notification sent)',
              type: DebugLogType.event);
          debugPrint(
              'Geofence dwell event for $id (notification sent by native)');
          break;
        case 'onGeofenceExit':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          DebugLogService()
              .log('Exited geofence: $id', type: DebugLogType.event);
          await _handleGeofenceExit(id);
          break;
        case 'onGeofenceError':
          final args = call.arguments as Map<dynamic, dynamic>;
          final id = args['id'] as String;
          final error = args['error'] as String;
          DebugLogService()
              .log('Geofence error: $id - $error', type: DebugLogType.error);
          debugPrint('Geofence error for $id: $error');
          break;
      }
    });

    debugPrint('Geofence method call handler set up');
  }

  /// Handle entering a geofence
  Future<void> _handleGeofenceEnter(String reminderId) async {
    debugPrint('Entered geofence: $reminderId');

    // Check if already notified
    if (_notifiedReminders.contains(reminderId)) {
      debugPrint('Already notified for $reminderId, ignoring');
      DebugLogService()
          .log('Already notified, ignoring entry', type: DebugLogType.info);
      return;
    }

    if (Platform.isAndroid) {
      // Android handles dwell natively via setLoiteringDelay, no timer needed
      debugPrint('Android: Waiting for native dwell event');
      return;
    }

    // iOS: Manual dwell tracking needed
    // Check if we already have an active timer
    if (_activeDwellTimers.containsKey(reminderId)) {
      debugPrint('Timer already active for $reminderId, ignoring duplicate');
      DebugLogService()
          .log('iOS: Timer already active, ignoring', type: DebugLogType.info);
      return;
    }

    // Get reminder info for logging
    final reminderService = ReminderService();
    final reminders = await reminderService.loadReminders();
    final reminder = reminders.where((r) => r.id == reminderId).firstOrNull;
    final brandName = reminder?.brandName ?? reminderId;

    final dwellTracker = DwellTimeTracker();
    await dwellTracker.recordEntry(reminderId);

    // Check if we've already dwelled long enough
    final hasDwelled = await dwellTracker.hasDwelledLongEnough(reminderId);
    if (hasDwelled) {
      debugPrint('Already dwelled at $reminderId, sending notification');
      DebugLogService().log('iOS: Already dwelled at $brandName',
          type: DebugLogType.geofenceDwell);
      await _sendReminderNotification(reminderId);
      return;
    }

    // Get dwell time from settings for logging
    final prefs = await SharedPreferences.getInstance();
    final dwellTimeMinutes = prefs.getInt('dwell_time_minutes') ?? 1;

    DebugLogService().log(
      'iOS: Waiting ${dwellTimeMinutes}min dwell time for $brandName',
      type: DebugLogType.info,
    );

    // Start iOS dwell timer
    _startDwellTimer(reminderId);
  }

  /// Handle exiting a geofence
  Future<void> _handleGeofenceExit(String reminderId) async {
    debugPrint('Exited geofence: $reminderId');

    // Cancel any active timer (iOS only)
    _activeDwellTimers[reminderId]?.cancel();
    _activeDwellTimers.remove(reminderId);

    // Clear notified state so user can be notified again on re-entry
    _notifiedReminders.remove(reminderId);

    // Clear iOS dwell tracking
    if (Platform.isIOS) {
      final dwellTracker = DwellTimeTracker();
      await dwellTracker.clearEntry(reminderId);
    }
  }

  /// Start a timer to check dwell time (iOS only)
  void _startDwellTimer(String reminderId) {
    debugPrint('Starting iOS dwell timer for $reminderId');

    final timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final dwellTracker = DwellTimeTracker();
      final hasDwelled = await dwellTracker.hasDwelledLongEnough(reminderId);

      if (hasDwelled) {
        timer.cancel();
        _activeDwellTimers.remove(reminderId);

        // Get reminder info for logging
        final reminderService = ReminderService();
        final reminders = await reminderService.loadReminders();
        final reminder = reminders.where((r) => r.id == reminderId).firstOrNull;
        final brandName = reminder?.brandName ?? reminderId;

        DebugLogService().log(
          'iOS: Dwell complete for $brandName (sending notification)',
          type: DebugLogType.geofenceDwell,
        );

        await _sendReminderNotification(reminderId);
        return;
      }

      // Check if we're still in the geofence
      final entryTime = await dwellTracker.getEntryTime(reminderId);
      if (entryTime == null) {
        timer.cancel();
        _activeDwellTimers.remove(reminderId);
        debugPrint('User left geofence $reminderId, stopping timer');
        DebugLogService()
            .log('iOS: User left during dwell wait', type: DebugLogType.info);
      }
    });

    _activeDwellTimers[reminderId] = timer;
  }

  /// Send notification for a reminder (iOS dwell completion)
  Future<void> _sendReminderNotification(String reminderId) async {
    if (_notifiedReminders.contains(reminderId)) {
      debugPrint('Already notified for $reminderId, skipping');
      return;
    }

    try {
      // Check cooldown period (24 hours) - same as Android
      final prefs = await SharedPreferences.getInstance();
      final lastNotificationKey = 'last_notification_$reminderId';
      final lastNotificationTime = prefs.getInt(lastNotificationKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      const cooldownMs = 24 * 60 * 60 * 1000;
      if (now - lastNotificationTime < cooldownMs) {
        debugPrint(
            'iOS: Skipping notification for $reminderId (cooldown period)');
        DebugLogService().log(
          'Skipped notification (cooldown)',
          type: DebugLogType.info,
        );
        return;
      }

      _notifiedReminders.add(reminderId);

      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();
      final reminder = reminders.where((r) => r.id == reminderId).firstOrNull;

      if (reminder == null) {
        debugPrint('Reminder not found for id: $reminderId');
        return;
      }

      // Save notification time
      await prefs.setInt(lastNotificationKey, now);

      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.showReminderNotification(
        poiId: reminder.id,
        poiName: reminder.originalPoiName,
        brandName: reminder.brandName,
        items: reminder.items.map((item) => item.text).toList(),
      );

      debugPrint('Sent notification for reminder: ${reminder.brandName}');
      DebugLogService().log(
        'iOS: Notification sent for ${reminder.brandName}',
        type: DebugLogType.geofenceDwell,
      );
    } catch (e) {
      debugPrint('Error sending reminder notification: $e');
      DebugLogService()
          .log('iOS: Error sending notification: $e', type: DebugLogType.error);
    }
  }

  /// Update the list of discovered POIs (kept for compatibility)
  void updateDiscoveredPois(List<POI> pois) {
    // No longer needed with geofencing approach
  }

  /// Start location monitoring with geofences
  Future<void> startMonitoring(List<Reminder> reminders) async {
    if (_isMonitoring) return;

    debugPrint('Starting monitoring with ${reminders.length} reminders');
    DebugLogService().log(
        'Starting monitoring with ${reminders.length} reminders',
        type: DebugLogType.info);

    if (Platform.isAndroid) {
      // Start foreground service first for persistent notification
      await ForegroundNotificationService.start();
      await _startAndroidGeofencing(reminders);
    } else if (Platform.isIOS) {
      await _startIOSGeofencing(reminders);
    }

    _isMonitoring = true;

    // Persist monitoring state for boot receiver
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monitoring_enabled', true);
  }

  /// Stop location monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      debugPrint('LocationMonitorService: Already stopped, ignoring');
      return;
    }

    debugPrint('LocationMonitorService: Stopping location monitoring');
    DebugLogService()
        .log('Stopped location monitoring', type: DebugLogType.info);

    if (Platform.isAndroid) {
      debugPrint('LocationMonitorService: Stopping Android geofencing');
      await _stopAndroidGeofencing();
      debugPrint('LocationMonitorService: Stopping foreground service');
      // Stop foreground service and remove notification
      await ForegroundNotificationService.stop();
      debugPrint('LocationMonitorService: Foreground service stopped');
    } else if (Platform.isIOS) {
      debugPrint('LocationMonitorService: Stopping iOS geofencing');
      await _stopIOSGeofencing();
    }

    _isMonitoring = false;

    // Persist monitoring state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monitoring_enabled', false);
    debugPrint('LocationMonitorService: Monitoring completely stopped');
  }

  /// Android: Start dynamic geofence management
  Future<void> _startAndroidGeofencing(List<Reminder> reminders) async {
    try {
      DebugLogService()
          .log('Initializing Android geofencing', type: DebugLogType.info);
      _dynamicGeofenceManager = DynamicGeofenceManager(
        registerGeofenceCallback: (id, lat, lng, radius, dwellTimeMs) async {
          await AndroidGeofenceService.registerGeofence(
            id: id,
            latitude: lat,
            longitude: lng,
            radius: radius,
            dwellTimeMs: dwellTimeMs,
          );
        },
        unregisterGeofenceCallback: (id) async {
          await AndroidGeofenceService.unregisterGeofence(id);
        },
      );

      await _dynamicGeofenceManager!.initialize(reminders);
      debugPrint('Android geofencing initialized');
    } catch (e) {
      debugPrint('Error starting Android geofencing: $e');
      DebugLogService().log('Error starting Android geofencing: $e',
          type: DebugLogType.error);
    }
  }

  /// Android: Stop dynamic geofence management
  Future<void> _stopAndroidGeofencing() async {
    try {
      _dynamicGeofenceManager?.dispose();
      _dynamicGeofenceManager = null;
      await AndroidGeofenceService.unregisterAll();
      debugPrint('Android geofencing stopped');
    } catch (e) {
      debugPrint('Error stopping Android geofencing: $e');
    }
  }

  /// iOS: Register geofences via native platform channel
  Future<void> _startIOSGeofencing(List<Reminder> reminders) async {
    try {
      DebugLogService()
          .log('Initializing iOS geofencing', type: DebugLogType.info);
      final prefs = await SharedPreferences.getInstance();
      final proximityRadius = prefs.getInt('proximity_radius_meters') ?? 150;

      _iosRegisteredGeofenceCount = 0;
      _iosTotalReminderCount = reminders.length;

      // Register geofences for all locations of each reminder
      for (final reminder in reminders) {
        // If reminder has multiple locations, register each one
        if (reminder.locations.isNotEmpty) {
          for (final location in reminder.locations) {
            try {
              debugPrint(
                  'Registering iOS geofence for ${location.poiName} (${reminder.brandName})');
              DebugLogService().log('Registered geofence: ${location.poiName}',
                  type: DebugLogType.register);
              await _channel.invokeMethod('registerGeofence', {
                'id': '${reminder.id}_${location.poiId}',
                'latitude': location.latitude,
                'longitude': location.longitude,
                'radius': proximityRadius.toDouble(),
              });
              _iosRegisteredGeofenceCount++;
            } catch (e) {
              debugPrint(
                  'Error registering geofence for ${location.poiName}: $e');
              DebugLogService().log(
                  'Error registering geofence for ${location.poiName}: $e',
                  type: DebugLogType.error);
            }
          }
        } else {
          // Fallback for old format (single location)
          try {
            debugPrint('Registering iOS geofence for ${reminder.brandName}');
            DebugLogService().log('Registered geofence: ${reminder.brandName}',
                type: DebugLogType.register);
            await _channel.invokeMethod('registerGeofence', {
              'id': reminder.id,
              'latitude': reminder.latitude,
              'longitude': reminder.longitude,
              'radius': proximityRadius.toDouble(),
            });
            _iosRegisteredGeofenceCount++;
          } catch (e) {
            debugPrint(
                'Error registering geofence for ${reminder.brandName}: $e');
            DebugLogService().log(
                'Error registering geofence for ${reminder.brandName}: $e',
                type: DebugLogType.error);
          }
        }
      }

      debugPrint(
          'iOS geofencing started: $_iosRegisteredGeofenceCount geofences for $_iosTotalReminderCount reminders');
      DebugLogService().log(
          'iOS geofencing started with $_iosRegisteredGeofenceCount geofences',
          type: DebugLogType.info);
      DebugLogService().log(
          'Active geofences: $_iosRegisteredGeofenceCount for $_iosTotalReminderCount reminders',
          type: DebugLogType.info);
    } catch (e) {
      debugPrint('Error starting iOS geofencing: $e');
      DebugLogService()
          .log('Error starting iOS geofencing: $e', type: DebugLogType.error);
    }
  }

  /// iOS: Remove all geofences
  Future<void> _stopIOSGeofencing() async {
    try {
      await _channel.invokeMethod('removeAllGeofences');

      // Cancel all iOS dwell timers
      for (final timer in _activeDwellTimers.values) {
        timer.cancel();
      }
      _activeDwellTimers.clear();

      // Reset iOS stats
      _iosRegisteredGeofenceCount = 0;
      _iosTotalReminderCount = 0;

      debugPrint('iOS geofencing stopped');
    } catch (e) {
      debugPrint('Error stopping iOS geofencing: $e');
    }
  }

  /// Notify dynamic geofence manager of reminder addition (Android only)
  Future<void> onReminderAdded(Reminder reminder) async {
    if (Platform.isAndroid && _dynamicGeofenceManager != null) {
      await _dynamicGeofenceManager!.onReminderAdded(reminder);
    } else if (Platform.isIOS && _isMonitoring) {
      // Re-register all iOS geofences
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();
      await _startIOSGeofencing(reminders);
    }
  }

  /// Notify dynamic geofence manager of reminder removal (Android only)
  Future<void> onReminderRemoved(String reminderId) async {
    if (Platform.isAndroid && _dynamicGeofenceManager != null) {
      await _dynamicGeofenceManager!.onReminderRemoved(reminderId);
    } else if (Platform.isIOS && _isMonitoring) {
      // Unregister specific iOS geofence
      try {
        await _channel.invokeMethod('removeGeofence', {'id': reminderId});
      } catch (e) {
        debugPrint('Error removing iOS geofence: $e');
      }
    }
  }

  /// Get dynamic geofence stats (Android and iOS)
  Map<String, int>? getGeofenceStats() {
    if (Platform.isAndroid && _dynamicGeofenceManager != null) {
      return {
        'active': _dynamicGeofenceManager!.getActiveCount(),
        'total': _dynamicGeofenceManager!.getTotalCount(),
      };
    } else if (Platform.isIOS && _isMonitoring) {
      return {
        'active': _iosRegisteredGeofenceCount,
        'total': _iosTotalReminderCount,
      };
    }
    return null;
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
      final backgroundStatus =
          await permission_handler.Permission.locationAlways.status;
      return backgroundStatus.isGranted;
    } else {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always;
    }
  }

  /// Request foreground location permission
  Future<bool> requestForegroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      try {
        await Geolocator.openLocationSettings();
      } catch (e) {
        debugPrint('Could not open location settings: $e');
      }
      return false;
    }

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

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Request background location permission
  Future<bool> requestBackgroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return false;
    }

    final geolocatorPermission = await Geolocator.checkPermission();
    debugPrint('Geolocator permission status: $geolocatorPermission');

    final hasForegroundPermission =
        geolocatorPermission == LocationPermission.whileInUse ||
            geolocatorPermission == LocationPermission.always;

    if (!hasForegroundPermission) {
      debugPrint('Foreground location not granted yet');
      return false;
    }

    if (geolocatorPermission == LocationPermission.always) {
      debugPrint('Already have always permission');
      return true;
    }

    if (Platform.isIOS) {
      debugPrint('iOS: Opening settings for Always permission');
      await permission_handler.openAppSettings();
      await Future.delayed(const Duration(milliseconds: 500));
      final newPermission = await Geolocator.checkPermission();
      debugPrint('iOS: Permission after settings: $newPermission');
      return newPermission == LocationPermission.always;
    }

    // Android
    final currentAlwaysStatus =
        await permission_handler.Permission.locationAlways.status;
    debugPrint('Android locationAlways status: $currentAlwaysStatus');

    if (currentAlwaysStatus.isGranted) {
      debugPrint('Already have always permission');
      return true;
    }

    if (currentAlwaysStatus.isPermanentlyDenied) {
      debugPrint('Always permission permanently denied, opening settings');
      await permission_handler.openAppSettings();
      return false;
    }

    debugPrint('Android: Requesting locationAlways permission...');
    final backgroundStatus =
        await permission_handler.Permission.locationAlways.request();
    debugPrint('Android: Background location status: $backgroundStatus');

    return backgroundStatus.isGranted;
  }

  /// Check if Google Play Services is available (Android only)
  Future<bool> isPlayServicesAvailable() async {
    if (!Platform.isAndroid) {
      return true; // iOS always uses native Core Location
    }

    try {
      final result =
          await _channel.invokeMethod<bool>('checkPlayServicesAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking Play Services availability: $e');
      return false;
    }
  }

  /// Set up permission revocation listener
  void _setupPermissionListener() {
    // Listen to location service status changes
    _locationServiceSubscription =
        Geolocator.getServiceStatusStream().listen((status) {
      debugPrint('Location service status changed: $status');
      if (status == ServiceStatus.disabled) {
        _handlePermissionRevocation('Location services disabled');
      }
    });

    // Periodically check background permission (every 30 seconds when monitoring)
    _permissionCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isMonitoring) return;

      final hasBackgroundPerm = await hasBackgroundPermission();
      if (!hasBackgroundPerm) {
        debugPrint('Background location permission revoked');
        await _handlePermissionRevocation(
            'Background location permission revoked');
      }
    });
  }

  /// Handle permission revocation by falling back to polling
  Future<void> _handlePermissionRevocation(String reason) async {
    if (!_isMonitoring) return;

    final strategyManager = GeofenceStrategyManager();
    if (!strategyManager.isUsingNativeGeofencing) {
      return; // Already using polling, nothing to do
    }

    debugPrint('Permission revoked: $reason. Falling back to polling.');

    // Fall back to polling
    await strategyManager.fallbackToPolling(reason);

    // Stop native monitoring
    await stopMonitoring();

    // The ReminderProvider will handle starting polling on next app launch
    // For now, just log the situation
    debugPrint(
        'Native monitoring stopped. Polling will start on next app launch.');
  }

  /// Dispose resources
  void dispose() {
    _locationServiceSubscription?.cancel();
    _permissionCheckTimer?.cancel();
  }
}

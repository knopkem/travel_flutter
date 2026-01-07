import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../utils/settings_service.dart';

/// Background geofence monitoring that survives app termination
/// 
/// Android: Uses FlutterBackgroundService with periodic location checks
/// iOS: Uses background fetch and significant location change (limited but works)
class BackgroundGeofenceService {
  static final BackgroundGeofenceService _instance = BackgroundGeofenceService._internal();
  factory BackgroundGeofenceService() => _instance;
  BackgroundGeofenceService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;
  bool _isMonitoring = false;
  
  static const Duration _notificationCooldown = Duration(hours: 1);

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('BackgroundGeofence: Already initialized');
      return;
    }

    debugPrint('BackgroundGeofence: Initializing for ${Platform.isIOS ? "iOS" : "Android"}');

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'background_geofence_channel',
        initialNotificationTitle: 'Shopping Reminders',
        initialNotificationContent: 'Monitoring your shopping locations',
        foregroundServiceNotificationId: 888,
        // The notification is automatically made non-dismissible (ongoing) by flutter_background_service
        // when isForegroundMode is true. If it's still dismissible, it's a bug in the package version.
      ),
    );

    _isInitialized = true;
    debugPrint('BackgroundGeofence: Initialization complete');
  }

  /// Start monitoring reminders
  Future<void> startMonitoring(List<Reminder> reminders) async {
    if (reminders.isEmpty) {
      debugPrint('BackgroundGeofence: No reminders to monitor');
      return;
    }

    await initialize();

    debugPrint('BackgroundGeofence: Setting up monitoring for ${reminders.length} reminders');

    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService();
    final searchDistanceKm = await settingsService.loadPoiDistance();
    final reminderIds = <String>[];

    for (final reminder in reminders) {
      final reminderData = '${reminder.id}|${reminder.originalPoiId}|${reminder.originalPoiName}|${reminder.brandName}|${reminder.latitude}|${reminder.longitude}|$searchDistanceKm|${reminder.items.map((i) => i.text).join(',')}';
      await prefs.setString('reminder_${reminder.id}', reminderData);
      reminderIds.add(reminder.id);
    }

    await prefs.setStringList('active_reminder_ids', reminderIds);
    await _service.startService();

    _isMonitoring = true;
    debugPrint('BackgroundGeofence: Started monitoring ${reminders.length} reminders');
  }

  /// Update monitored reminders
  Future<void> updateReminders(List<Reminder> reminders) async {
    debugPrint('BackgroundGeofence: Updating reminders (${reminders.length})');
    await stopMonitoring();
    if (reminders.isNotEmpty) {
      await startMonitoring(reminders);
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    debugPrint('BackgroundGeofence: Stopping monitoring');
    _service.invoke('stopService');
    _isMonitoring = false;
    debugPrint('BackgroundGeofence: Monitoring stopped');
  }

  /// Update check interval when dwell time setting changes
  Future<void> updateCheckInterval() async {
    if (!_isMonitoring) return;
    
    debugPrint('BackgroundGeofence: Notifying service to update interval');
    _service.invoke('updateInterval');
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Load dwell time setting for check interval
    final prefs = await SharedPreferences.getInstance();
    int dwellTimeMinutes = prefs.getInt('flutter.dwell_time_minutes') ?? SettingsService.defaultDwellTimeMinutes;
    
    // Check interval: Use dwell time setting for Android, iOS uses background fetch minimum
    Duration checkInterval = Platform.isIOS 
        ? const Duration(minutes: 15)  // iOS background fetch minimum
        : Duration(minutes: dwellTimeMinutes);

    debugPrint('BackgroundGeofence: Service started with ${checkInterval.inMinutes} min interval (dwell time: $dwellTimeMinutes)');

    // Initial check
    await _checkReminders();

    // Create a cancelable timer that can be updated
    Timer? periodicTimer;
    
    // Listen for setting changes to update interval dynamically
    service.on('updateInterval').listen((event) async {
      periodicTimer?.cancel();
      final newPrefs = await SharedPreferences.getInstance();
      dwellTimeMinutes = newPrefs.getInt('flutter.dwell_time_minutes') ?? SettingsService.defaultDwellTimeMinutes;
      checkInterval = Platform.isIOS 
          ? const Duration(minutes: 15)
          : Duration(minutes: dwellTimeMinutes);
      debugPrint('BackgroundGeofence: Interval updated to ${checkInterval.inMinutes} min');
      
      // Restart periodic checks with new interval
      periodicTimer = Timer.periodic(checkInterval, (timer) async {
        debugPrint('BackgroundGeofence: Periodic check triggered');
        await _checkReminders();
      });
    });

    // Run periodic checks
    periodicTimer = Timer.periodic(checkInterval, (timer) async {
      debugPrint('BackgroundGeofence: Periodic check triggered');
      await _checkReminders();
    });
  }

  /// Check reminders in background
  static Future<void> _checkReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderIds = prefs.getStringList('active_reminder_ids') ?? [];
      
      if (reminderIds.isEmpty) {
        debugPrint('BackgroundGeofence: No active reminders');
        return;
      }

      // Get current position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          ),
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('BackgroundGeofence: Failed to get position, trying last known: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint('BackgroundGeofence: No position available');
        return;
      }

      debugPrint('BackgroundGeofence: Checking ${reminderIds.length} reminders at ${position.latitude}, ${position.longitude}');

      final notificationService = NotificationService();
      await notificationService.initialize();
      final now = DateTime.now();

      // Check each reminder
      for (final reminderId in reminderIds) {
        final reminderJson = prefs.getString('reminder_$reminderId');
        if (reminderJson == null) continue;

        final parts = reminderJson.split('|');
        if (parts.length < 8) continue;

        final latitude = double.tryParse(parts[4]);
        final longitude = double.tryParse(parts[5]);
        final radiusKm = double.tryParse(parts[6]) ?? 5.0;

        if (latitude == null || longitude == null) continue;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );

        final distanceKm = distance / 1000;

        if (distanceKm <= radiusKm) {
          debugPrint('BackgroundGeofence: Inside radius for ${parts[3]} (${distanceKm.toStringAsFixed(2)} km)');

          // Check cooldown
          final lastNotificationTime = prefs.getInt('last_notification_$reminderId');
          if (lastNotificationTime != null) {
            final lastTime = DateTime.fromMillisecondsSinceEpoch(lastNotificationTime);
            if (now.difference(lastTime) < _notificationCooldown) {
              debugPrint('BackgroundGeofence: Cooldown active for ${parts[3]}');
              continue;
            }
          }

          // Send notification
          await notificationService.showReminderNotification(
            poiId: parts[1],
            poiName: parts[2],
            brandName: parts[3],
            items: parts[7].split(',').where((s) => s.isNotEmpty).toList(),
          );

          // Update cooldown
          await prefs.setInt('last_notification_$reminderId', now.millisecondsSinceEpoch);
          
          debugPrint('BackgroundGeofence: Notification sent for ${parts[3]}');
        }
      }

      debugPrint('BackgroundGeofence: Check complete');
    } catch (e, stackTrace) {
      debugPrint('BackgroundGeofence: Error checking reminders: $e');
      debugPrint('BackgroundGeofence: Stack trace: $stackTrace');
    }
  }

  /// iOS background handler
  /// Note: iOS significantly restricts background execution
  /// This will run opportunistically when iOS decides to wake the app
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    debugPrint('BackgroundGeofence: iOS background wakeup');
    await _checkReminders();
    
    return true;
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../utils/settings_service.dart';
import 'dwell_time_tracker.dart';
import 'notification_service.dart';
import 'reminder_service.dart';

/// Manager for the background location monitoring service on Android
/// iOS uses native geofencing and doesn't need this
class BackgroundServiceManager {
  static const String _notificationChannelId = 'background_service_foreground';
  static const int _foregroundNotificationId = 888;
  static const double _proximityThresholdMeters = 300.0;

  /// Initialize the background service (call before runApp)
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final service = FlutterBackgroundService();

    // Create notification channel for foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Background Location Service',
      description: 'Shows when location monitoring is active for reminders',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'LocationPal',
        initialNotificationContent: 'Initializing location monitoring...',
        foregroundServiceNotificationId: _foregroundNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        // iOS doesn't use this service, but we need to provide a config
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background service
  static Future<bool> startService() async {
    if (!Platform.isAndroid) return false;

    final service = FlutterBackgroundService();

    // Check if already running
    final isRunning = await service.isRunning();
    debugPrint('BackgroundServiceManager.startService: isRunning=$isRunning');
    if (isRunning) {
      // Update reminder count if already running
      await updateReminderCount();
      return true;
    }

    final started = await service.startService();
    debugPrint('BackgroundServiceManager.startService: started=$started');

    // Give the service a moment to initialize, then update count
    if (started) {
      await Future.delayed(const Duration(milliseconds: 1500));
      await updateReminderCount();
    }

    return started;
  }

  /// Stop the background service
  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stop');
      // Give the service time to stop properly
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Cancel the foreground notification directly
    await _cancelNotification();
  }

  /// Cancel the foreground notification
  static Future<void> _cancelNotification() async {
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.cancel(_foregroundNotificationId);
      debugPrint('Cancelled foreground notification');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  /// Update the reminder count (updates foreground notification)
  static Future<void> updateReminderCount() async {
    if (!Platform.isAndroid) return;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    debugPrint(
        'BackgroundServiceManager.updateReminderCount: isRunning=$isRunning');

    if (isRunning) {
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();
      final count = reminders.length;
      debugPrint('BackgroundServiceManager.updateReminderCount: count=$count');

      // Send to background isolate
      service.invoke('updateReminderCount', {'count': count});

      // Also directly update the notification from main isolate
      // This is more reliable than inter-isolate communication
      await _updateNotificationDirect(count);
    }
  }

  /// Directly update the foreground notification from main isolate
  static Future<void> _updateNotificationDirect(int reminderCount) async {
    try {
      final notifications = FlutterLocalNotificationsPlugin();

      String content;
      if (reminderCount == 0) {
        content = 'Location monitoring active';
      } else if (reminderCount == 1) {
        content = 'Monitoring 1 reminder';
      } else {
        content = 'Monitoring $reminderCount reminders';
      }

      debugPrint('Directly updating notification: $content');

      const androidDetails = AndroidNotificationDetails(
        _notificationChannelId,
        'Background Location Service',
        channelDescription:
            'Shows when location monitoring is active for reminders',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
      );

      await notifications.show(
        _foregroundNotificationId,
        'LocationPal',
        content,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Error updating notification directly: $e');
    }
  }

  /// Entry point for the background service (Android only)
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    debugPrint('Background service onStart called');

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Timer for periodic location checks
    Timer? locationCheckTimer;

    // Initialize services
    await NotificationService().initialize();

    // Load initial reminder count (with a small delay to ensure data is ready)
    await Future.delayed(const Duration(milliseconds: 500));
    int reminderCount = await _getReminderCount();
    debugPrint('Background service initial reminder count: $reminderCount');

    // Update foreground notification
    await _updateForegroundNotification(service, reminderCount);

    // Listen for reminder count updates from main app
    service.on('updateReminderCount').listen((event) async {
      debugPrint('Background service received updateReminderCount: $event');
      if (event != null && event['count'] != null) {
        reminderCount = event['count'] as int;
        await _updateForegroundNotification(service, reminderCount);

        // Stop service if no reminders
        if (reminderCount == 0) {
          locationCheckTimer?.cancel();
          service.stopSelf();
        }
      }
    });

    // Listen for stop command
    service.on('stop').listen((event) {
      debugPrint('Background service received stop command');
      locationCheckTimer?.cancel();
      if (service is AndroidServiceInstance) {
        service.stopSelf();
      }
    });

    // Calculate check interval based on dwell time setting
    final prefs = await SharedPreferences.getInstance();
    final dwellTimeMinutes = prefs.getInt('dwell_time_minutes') ??
        SettingsService.defaultDwellTimeMinutes;
    
    // Use dwell time as check interval, but cap at 5 minutes for battery efficiency
    // and ensure minimum of 30 seconds for responsiveness
    final checkIntervalMinutes = dwellTimeMinutes.clamp(1, 5);
    final checkInterval = Duration(minutes: checkIntervalMinutes);
    
    debugPrint('Background service check interval: ${checkIntervalMinutes}m (dwell time: ${dwellTimeMinutes}m)');

    // Start periodic location checks
    locationCheckTimer = Timer.periodic(checkInterval, (timer) async {
      await _checkLocationAndNotify();
    });

    // Do an immediate check on start
    await _checkLocationAndNotify();
  }

  /// iOS background handler (not used, but required)
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Get the current reminder count
  static Future<int> _getReminderCount() async {
    try {
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();
      return reminders.length;
    } catch (e) {
      debugPrint('Error getting reminder count: $e');
      return 0;
    }
  }

  /// Update the foreground notification with current reminder count
  static Future<void> _updateForegroundNotification(
    ServiceInstance service,
    int reminderCount,
  ) async {
    if (service is! AndroidServiceInstance) return;

    final notification = _buildForegroundNotification(reminderCount);
    debugPrint('Updating foreground notification: ${notification['content']}');
    await service.setForegroundNotificationInfo(
      title: notification['title']!,
      content: notification['content']!,
    );
  }

  /// Build foreground notification content
  static Map<String, String> _buildForegroundNotification(int reminderCount) {
    if (reminderCount == 0) {
      return {
        'title': 'LocationPal',
        'content': 'Location monitoring active',
      };
    } else if (reminderCount == 1) {
      return {
        'title': 'LocationPal',
        'content': 'Monitoring 1 reminder',
      };
    } else {
      return {
        'title': 'LocationPal',
        'content': 'Monitoring $reminderCount reminders',
      };
    }
  }

  /// Check current location and send notifications if needed
  static Future<void> _checkLocationAndNotify() async {
    try {
      // Check if location permission is still granted
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission not granted, stopping checks');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );

      // Load all reminders
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();

      // Send debug notification showing monitoring is active
      await _sendDebugNotification(reminders.length, position);

      if (reminders.isEmpty) {
        debugPrint('No reminders to check');
        return;
      }

      // Get dwell time setting
      final prefs = await SharedPreferences.getInstance();
      final dwellTimeMinutes = prefs.getInt('dwell_time_minutes') ??
          SettingsService.defaultDwellTimeMinutes;
      final requiredDwellTime = Duration(minutes: dwellTimeMinutes);
      debugPrint('Using dwell time: $dwellTimeMinutes minutes');

      // Check proximity to each reminder location
      for (final reminder in reminders) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          reminder.latitude,
          reminder.longitude,
        );

        debugPrint(
            'Distance to ${reminder.brandName}: ${distance.toStringAsFixed(0)}m');

        if (distance <= _proximityThresholdMeters) {
          // Within range - check dwell time
          final dwellTracker = DwellTimeTracker();

          // Check if we've already dwelled long enough
          final hasDwelled =
              await dwellTracker.hasDwelledLongEnough(reminder.id);

          if (hasDwelled) {
            // Already notified, skip
            debugPrint('Already dwelled at ${reminder.brandName}');
            continue;
          }

          // Check if we have an entry time
          final entryTime = await dwellTracker.getEntryTime(reminder.id);

          if (entryTime == null) {
            // First time entering range - record entry
            await dwellTracker.recordEntry(reminder.id);
            debugPrint('Recorded entry to ${reminder.brandName}');
          } else {
            // Check if we've been here long enough
            final elapsed = DateTime.now().difference(entryTime);
            if (elapsed >= requiredDwellTime) {
              // Dwelled long enough - send notification
              debugPrint('Sending notification for ${reminder.brandName}');
              await _sendReminderNotification(reminder);
              // Mark as notified by not clearing entry time
            } else {
              debugPrint(
                  'Dwelling at ${reminder.brandName} for ${elapsed.inMinutes}m (need ${dwellTimeMinutes}m)');
            }
          }
        } else {
          // Out of range - clear entry time if exists
          final dwellTracker = DwellTimeTracker();
          await dwellTracker.clearEntry(reminder.id);
        }
      }
    } catch (e) {
      debugPrint('Error checking location: $e');
    }
  }

  /// Send a reminder notification
  static Future<void> _sendReminderNotification(Reminder reminder) async {
    try {
      final notificationService = NotificationService();
      await notificationService.showReminderNotification(
        poiId: reminder.id,
        poiName: reminder.originalPoiName,
        brandName: reminder.brandName,
        items: reminder.items.map((item) => item.text).toList(),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Send a debug notification to show background service is running
  static const int _debugNotificationId = 889;

  static Future<void> _sendDebugNotification(
      int reminderCount, Position position) async {
    try {
      final notifications = FlutterLocalNotificationsPlugin();

      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      const androidDetails = AndroidNotificationDetails(
        'debug_channel',
        'Debug Notifications',
        channelDescription: 'Debug notifications for background monitoring',
        importance: Importance.low,
        priority: Priority.low,
        autoCancel: true,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );

      await notifications.show(
        _debugNotificationId,
        '🔍 Background Check',
        'Time: $timeStr | POIs: $reminderCount | Loc: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );

      debugPrint('Sent debug notification at $timeStr');
    } catch (e) {
      debugPrint('Error sending debug notification: $e');
    }
  }
}

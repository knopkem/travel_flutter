import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import '../models/reminder.dart';
import 'dwell_time_tracker.dart';
import 'notification_service.dart';
import 'reminder_service.dart';

/// Manager for the background location monitoring service on Android
/// iOS uses native geofencing and doesn't need this
class BackgroundServiceManager {
  static const String _notificationChannelId = 'background_service_foreground';
  static const int _foregroundNotificationId = 888;
  static const Duration _checkInterval = Duration(minutes: 5);
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
    if (isRunning) {
      // Update reminder count if already running
      await updateReminderCount();
      return true;
    }

    return await service.startService();
  }

  /// Stop the background service
  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;

    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  /// Update the reminder count (updates foreground notification)
  static Future<void> updateReminderCount() async {
    if (!Platform.isAndroid) return;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();
      service.invoke('updateReminderCount', {'count': reminders.length});
    }
  }

  /// Entry point for the background service (Android only)
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

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

    // Load initial reminder count
    int reminderCount = await _getReminderCount();

    // Update foreground notification
    await _updateForegroundNotification(service, reminderCount);

    // Listen for reminder count updates from main app
    service.on('updateReminderCount').listen((event) async {
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
      locationCheckTimer?.cancel();
      service.stopSelf();
    });

    // Start periodic location checks
    locationCheckTimer = Timer.periodic(_checkInterval, (timer) async {
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
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Location fetch timeout');
        },
      );

      // Load all reminders
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();

      if (reminders.isEmpty) {
        debugPrint('No reminders to check');
        return;
      }

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
            if (elapsed >= const Duration(minutes: 5)) {
              // Dwelled long enough - send notification
              debugPrint('Sending notification for ${reminder.brandName}');
              await _sendReminderNotification(reminder);
              // Mark as notified by not clearing entry time
            } else {
              debugPrint(
                  'Dwelling at ${reminder.brandName} for ${elapsed.inMinutes}m');
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
}

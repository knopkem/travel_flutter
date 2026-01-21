import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(String)? _onNotificationTapped;

  /// Initialize the notification service
  /// Note: This does NOT request permissions - call requestPermission() when needed
  Future<void> initialize({Function(String)? onNotificationTapped}) async {
    if (_initialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    debugPrint('NotificationService initializing...');

    _onNotificationTapped = onNotificationTapped;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // Do NOT request permissions during initialization
    // Permissions will be requested explicitly when user creates first reminder
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [],
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initResult = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
        if (details.payload != null && _onNotificationTapped != null) {
          _onNotificationTapped!(details.payload!);
        }
      },
    );
    debugPrint('Notification plugin initialized: $initResult');

    _initialized = true;
    debugPrint('NotificationService initialization complete');
  }

  /// Check if notification permission is permanently denied (user must go to Settings)
  /// On iOS, this returns true only if the user has previously been asked and denied.
  /// It returns false if the permission was never asked (not determined state).
  Future<bool> isPermissionPermanentlyDenied() async {
    final status = await permission_handler.Permission.notification.status;
    debugPrint('Notification permission status: $status');
    
    if (Platform.isIOS) {
      // On iOS, isPermanentlyDenied means user actively denied
      // isDenied can mean "not determined" (never asked) OR "denied"
      // We only want to show "go to settings" if PERMANENTLY denied
      return status.isPermanentlyDenied;
    }
    if (Platform.isAndroid) {
      return status.isPermanentlyDenied;
    }
    return false;
  }

  /// Check current notification permission status
  Future<bool> hasPermission() async {
    final status = await permission_handler.Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permissions (call on first reminder creation)
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermission() async {
    // First check if we already have permission
    if (await hasPermission()) {
      debugPrint('Notification permission already granted');
      return true;
    }

    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Check if permanently denied first
      final status = await permission_handler.Permission.notification.status;
      if (status.isPermanentlyDenied) {
        debugPrint('Android notification permission permanently denied');
        return false;
      }
      
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('Android notification permission result: $granted');
      if (granted != true) return false;
    }

    // iOS requires permission
    if (Platform.isIOS) {
      final status = await permission_handler.Permission.notification.status;
      debugPrint('iOS notification status before request: $status');
      
      // Only skip if PERMANENTLY denied (user explicitly denied before)
      // isDenied on iOS can mean "not determined" (never asked yet)
      if (status.isPermanentlyDenied) {
        debugPrint('iOS notification permission permanently denied, need to open Settings');
        return false;
      }
      
      // Request permission - this will show dialog if never asked,
      // or return current status if already decided
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('iOS notification permission result: $granted');
        if (granted != true) return false;
      }
    }

    return true;
  }

  /// Open app settings so user can manually enable notifications
  Future<void> openSettings() async {
    await permission_handler.openAppSettings();
  }

  /// Show a reminder notification
  Future<void> showReminderNotification({
    required String poiId,
    required String poiName,
    required String brandName,
    required List<String> items,
  }) async {
    debugPrint(
        'NotificationService.showReminderNotification called for $brandName');

    if (!_initialized) {
      debugPrint('NotificationService not initialized, initializing now...');
      await initialize();
    }

    // Build notification content
    final itemsPreview = items.take(3).join(', ');
    final moreItems = items.length > 3 ? ' and ${items.length - 3} more' : '';

    const androidDetails = AndroidNotificationDetails(
      'shopping_reminders',
      'Shopping Reminders',
      channelDescription: 'Notifications when you\'re near tagged stores',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Shopping Reminder',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Use timestamp-based ID to prevent iOS from deduplicating repeat notifications
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      debugPrint(
          'Showing notification with ID: $notificationId for POI: $poiId');

      await _notifications.show(
        notificationId,
        'You\'re near $brandName!',
        'Shopping list: $itemsPreview$moreItems',
        notificationDetails,
        payload: poiId,
      );

      debugPrint('Notification shown successfully for $brandName');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(String poiId) async {
    await _notifications.cancel(poiId.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

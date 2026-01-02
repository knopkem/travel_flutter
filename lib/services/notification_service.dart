import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  Future<void> initialize({Function(String)? onNotificationTapped}) async {
    if (_initialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    debugPrint('NotificationService initializing...');

    _onNotificationTapped = onNotificationTapped;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // Enable foreground notification presentation on iOS
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      debugPrint('Requesting iOS notification permissions...');
      final permResult = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('iOS notification permission result: $permResult');
    } else {
      debugPrint('iOS plugin not available (not on iOS?)');
    }

    _initialized = true;
    debugPrint('NotificationService initialization complete');
  }

  /// Request notification permissions (call on first reminder creation)
  Future<bool> requestPermission() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      if (granted != true) return false;
    }

    // iOS requires permission
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted != true) return false;
    }

    return true;
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

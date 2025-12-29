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
    if (_initialized) return;

    _onNotificationTapped = onNotificationTapped;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && _onNotificationTapped != null) {
          _onNotificationTapped!(details.payload!);
        }
      },
    );

    _initialized = true;
  }

  /// Request notification permissions (call on first reminder creation)
  Future<bool> requestPermission() async {
    // Android 13+ requires runtime permission
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      if (granted != true) return false;
    }

    // iOS requires permission
    final iosPlugin =
        _notifications.resolvePlatformSpecificImplementation<
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
    if (!_initialized) {
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
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      poiId.hashCode, // Use POI ID hash as notification ID
      'You\'re near $brandName!',
      'Shopping list: $itemsPreview$moreItems',
      notificationDetails,
      payload: poiId, // Pass POI ID for deep linking
    );
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

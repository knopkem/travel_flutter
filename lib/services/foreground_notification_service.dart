import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for managing the foreground notification on Android
/// This ensures the notification is truly non-dismissible
class ForegroundNotificationService {
  static const MethodChannel _channel = MethodChannel('com.app/foreground_service');
  
  static bool _isRunning = false;
  
  /// Check if foreground service is running
  static bool get isRunning => _isRunning;
  
  /// Start the foreground service with persistent notification
  static Future<void> start() async {
    if (!Platform.isAndroid) {
      debugPrint('ForegroundNotificationService: Not on Android, skipping');
      return;
    }
    
    if (_isRunning) {
      debugPrint('ForegroundNotificationService: Already running');
      return;
    }
    
    try {
      await _channel.invokeMethod('startForegroundService');
      _isRunning = true;
      debugPrint('ForegroundNotificationService: Started successfully');
    } catch (e) {
      debugPrint('ForegroundNotificationService: Failed to start: $e');
      rethrow;
    }
  }
  
  /// Stop the foreground service and remove notification
  static Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }
    
    if (!_isRunning) {
      debugPrint('ForegroundNotificationService: Not running');
      return;
    }
    
    try {
      await _channel.invokeMethod('stopForegroundService');
      _isRunning = false;
      debugPrint('ForegroundNotificationService: Stopped successfully');
    } catch (e) {
      debugPrint('ForegroundNotificationService: Failed to stop: $e');
      rethrow;
    }
  }
}

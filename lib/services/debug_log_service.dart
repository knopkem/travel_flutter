import 'package:flutter/foundation.dart';

/// In-memory debug log service for geofence events
/// Captures events from app start for debug overlay display
class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final List<DebugLogEntry> _logs = [];
  static const int _maxLogs = 100;

  /// Add a log entry
  void log(String message, {DebugLogType type = DebugLogType.info}) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      message: message,
      type: type,
    );
    
    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    
    // Also print to console
    debugPrint('[GeofenceDebug] $message');
  }

  /// Get all log entries
  List<DebugLogEntry> getLogs() => List.unmodifiable(_logs);

  /// Clear all logs
  void clear() => _logs.clear();

  /// Get logs count
  int get count => _logs.length;
}

enum DebugLogType {
  info,
  register,
  unregister,
  event,
  error,
  strategy,
}

class DebugLogEntry {
  final DateTime timestamp;
  final String message;
  final DebugLogType type;

  DebugLogEntry({
    required this.timestamp,
    required this.message,
    required this.type,
  });

  String get formattedTime => timestamp.toString().substring(11, 19);
  
  String get typeIcon {
    switch (type) {
      case DebugLogType.register:
        return '➕';
      case DebugLogType.unregister:
        return '➖';
      case DebugLogType.event:
        return '🔔';
      case DebugLogType.error:
        return '❌';
      case DebugLogType.strategy:
        return '⚙️';
      case DebugLogType.info:
        return 'ℹ️';
    }
  }
}

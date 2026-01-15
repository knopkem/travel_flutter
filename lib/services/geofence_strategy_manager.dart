import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/settings_service.dart';

/// Strategy for location monitoring
enum GeofenceStrategy {
  /// Native geofencing using Google Play Services (Android) or Core Location (iOS)
  native,
  
  /// Polling-based monitoring using periodic location checks
  polling,
}

/// Manages the active geofence monitoring strategy and handles fallback scenarios
class GeofenceStrategyManager {
  static final GeofenceStrategyManager _instance = GeofenceStrategyManager._internal();
  factory GeofenceStrategyManager() => _instance;
  GeofenceStrategyManager._internal();

  final SettingsService _settingsService = SettingsService();
  
  GeofenceStrategy _currentStrategy = GeofenceStrategy.native;
  String? _fallbackReason;
  
  final _strategyController = StreamController<GeofenceStrategy>.broadcast();
  
  /// Stream of strategy changes for UI reactivity
  Stream<GeofenceStrategy> get strategyStream => _strategyController.stream;
  
  /// Current active monitoring strategy
  GeofenceStrategy get currentStrategy => _currentStrategy;
  
  /// Reason for falling back to polling (null if using native strategy)
  String? get fallbackReason => _fallbackReason;
  
  /// Whether native geofencing is currently active
  bool get isUsingNativeGeofencing => _currentStrategy == GeofenceStrategy.native;
  
  /// Whether polling fallback is currently active
  bool get isUsingPolling => _currentStrategy == GeofenceStrategy.polling;
  
  /// Initialize by loading persisted strategy
  Future<void> initialize() async {
    _currentStrategy = await _settingsService.loadGeofenceStrategy();
    _fallbackReason = await _settingsService.loadGeofenceFallbackReason();
    debugPrint('GeofenceStrategyManager: Loaded strategy: $_currentStrategy, reason: $_fallbackReason');
  }
  
  /// Switch to native geofencing strategy and clear any fallback reason
  Future<void> useNativeGeofencing() async {
    if (_currentStrategy == GeofenceStrategy.native && _fallbackReason == null) {
      return; // Already using native with no fallback reason
    }
    
    debugPrint('GeofenceStrategyManager: Switching to native geofencing');
    _currentStrategy = GeofenceStrategy.native;
    _fallbackReason = null;
    
    await _settingsService.saveGeofenceStrategy(_currentStrategy);
    await _settingsService.saveGeofenceFallbackReason(null);
    
    _strategyController.add(_currentStrategy);
  }
  
  /// Fall back to polling strategy with a reason
  Future<void> fallbackToPolling(String reason) async {
    if (_currentStrategy == GeofenceStrategy.polling && _fallbackReason == reason) {
      return; // Already using polling with same reason
    }
    
    debugPrint('GeofenceStrategyManager: Falling back to polling. Reason: $reason');
    _currentStrategy = GeofenceStrategy.polling;
    _fallbackReason = reason;
    
    await _settingsService.saveGeofenceStrategy(_currentStrategy);
    await _settingsService.saveGeofenceFallbackReason(reason);
    
    _strategyController.add(_currentStrategy);
  }
  
  /// Get a human-readable description of the current strategy
  String getStrategyDescription() {
    switch (_currentStrategy) {
      case GeofenceStrategy.native:
        return 'Native Geofencing';
      case GeofenceStrategy.polling:
        return 'Basic Polling';
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _strategyController.close();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

/// Manages dynamic geofence registration to handle the 100 geofence limit
/// Only registers the nearest 95 geofences (buffer below limit)
class DynamicGeofenceManager {
  static const int _maxGeofences = 95; // Buffer below Android's 100 limit
  static const double _significantMoveDistanceMeters = 500.0;

  StreamSubscription<Position>? _locationSubscription;
  Position? _lastUpdatePosition;
  List<Reminder> _allReminders = [];
  Set<String> _registeredGeofenceIds = {};

  final Function(String id, double lat, double lng, double radius, int dwellTimeMs) registerGeofenceCallback;
  final Function(String id) unregisterGeofenceCallback;

  DynamicGeofenceManager({
    required this.registerGeofenceCallback,
    required this.unregisterGeofenceCallback,
  });

  /// Initialize and start monitoring location for dynamic geofence updates
  Future<void> initialize(List<Reminder> reminders) async {
    _allReminders = List.from(reminders);
    
    // Load previously registered IDs from SharedPreferences
    await _loadRegisteredIds();

    // Register initial geofences based on current location
    await _updateGeofences();

    // Only start location monitoring on Android (iOS handles this natively)
    if (Platform.isAndroid) {
      _startLocationMonitoring();
    }
  }

  /// Add a new reminder and re-evaluate geofences
  Future<void> onReminderAdded(Reminder reminder) async {
    _allReminders.add(reminder);
    await _updateGeofences();
  }

  /// Remove a reminder and re-evaluate geofences
  Future<void> onReminderRemoved(String reminderId) async {
    _allReminders.removeWhere((r) => r.id == reminderId);
    
    // If it was registered, unregister it
    if (_registeredGeofenceIds.contains(reminderId)) {
      await unregisterGeofenceCallback(reminderId);
      _registeredGeofenceIds.remove(reminderId);
      await _saveRegisteredIds();
    }
    
    await _updateGeofences();
  }

  /// Update all reminders and re-evaluate geofences
  Future<void> updateAll(List<Reminder> reminders) async {
    _allReminders = List.from(reminders);
    await _updateGeofences();
  }

  /// Stop location monitoring
  void dispose() {
    _locationSubscription?.cancel();
  }

  /// Start monitoring significant location changes
  void _startLocationMonitoring() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: _significantMoveDistanceMeters.toInt(),
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        debugPrint('DynamicGeofenceManager: Significant location change detected');
        _onLocationChanged(position);
      },
      onError: (error) {
        debugPrint('DynamicGeofenceManager: Location stream error: $error');
      },
    );
  }

  /// Handle location changes and update geofences if needed
  Future<void> _onLocationChanged(Position position) async {
    // Check if we've moved significantly since last update
    if (_lastUpdatePosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastUpdatePosition!.latitude,
        _lastUpdatePosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < _significantMoveDistanceMeters) {
        return; // Not moved enough to warrant update
      }
    }

    _lastUpdatePosition = position;
    await _updateGeofences();
  }

  /// Re-evaluate and update registered geofences based on current location
  Future<void> _updateGeofences() async {
    try {
      // Get current position
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('DynamicGeofenceManager: Could not get current position: $e');
        // Use last known position if available
        currentPosition = _lastUpdatePosition;
      }

      if (currentPosition == null) {
        debugPrint('DynamicGeofenceManager: No position available, skipping update');
        return;
      }

      // Calculate distances to all reminders
      final remindersWithDistance = _allReminders.map((reminder) {
        final distance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition.longitude,
          reminder.latitude,
          reminder.longitude,
        );
        return MapEntry(reminder, distance);
      }).toList();

      // Sort by distance (nearest first)
      remindersWithDistance.sort((a, b) => a.value.compareTo(b.value));

      // Take the nearest N reminders
      final nearestReminders = remindersWithDistance
          .take(_maxGeofences)
          .map((entry) => entry.key)
          .toList();

      final nearestIds = nearestReminders.map((r) => r.id).toSet();

      // Unregister geofences that are no longer in the nearest set
      final toUnregister = _registeredGeofenceIds.difference(nearestIds);
      for (final id in toUnregister) {
        debugPrint('DynamicGeofenceManager: Unregistering far geofence: $id');
        await unregisterGeofenceCallback(id);
        _registeredGeofenceIds.remove(id);
      }

      // Register new geofences that are now in the nearest set
      final toRegister = nearestIds.difference(_registeredGeofenceIds);
      
      // Get settings for registration
      final prefs = await SharedPreferences.getInstance();
      final dwellTimeMinutes = prefs.getInt('dwell_time_minutes') ?? 1;
      final proximityRadius = prefs.getInt('proximity_radius_meters') ?? 150;

      for (final id in toRegister) {
        final reminder = nearestReminders.firstWhere((r) => r.id == id);
        debugPrint('DynamicGeofenceManager: Registering near geofence: $id');
        
        await registerGeofenceCallback(
          id,
          reminder.latitude,
          reminder.longitude,
          proximityRadius.toDouble(),
          dwellTimeMinutes * 60 * 1000, // Convert to milliseconds
        );
        _registeredGeofenceIds.add(id);
      }

      // Save updated registered IDs
      await _saveRegisteredIds();

      debugPrint('DynamicGeofenceManager: Active geofences: ${_registeredGeofenceIds.length}/${_allReminders.length}');
    } catch (e) {
      debugPrint('DynamicGeofenceManager: Error updating geofences: $e');
    }
  }

  /// Load registered geofence IDs from SharedPreferences
  Future<void> _loadRegisteredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('registered_geofence_ids') ?? [];
      _registeredGeofenceIds = ids.toSet();
      debugPrint('DynamicGeofenceManager: Loaded ${_registeredGeofenceIds.length} registered IDs');
    } catch (e) {
      debugPrint('DynamicGeofenceManager: Error loading registered IDs: $e');
    }
  }

  /// Save registered geofence IDs to SharedPreferences
  Future<void> _saveRegisteredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('registered_geofence_ids', _registeredGeofenceIds.toList());
    } catch (e) {
      debugPrint('DynamicGeofenceManager: Error saving registered IDs: $e');
    }
  }

  /// Get list of currently registered geofence IDs
  Set<String> getRegisteredIds() => Set.from(_registeredGeofenceIds);

  /// Get count of active geofences
  int getActiveCount() => _registeredGeofenceIds.length;

  /// Get total count of reminders
  int getTotalCount() => _allReminders.length;

  /// Get geofence statistics for debug display
  Map<String, int> getGeofenceStats() {
    return {
      'active': _registeredGeofenceIds.length,
      'total': _allReminders.length,
    };
  }
}

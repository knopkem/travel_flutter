import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import 'debug_log_service.dart';
import 'notification_service.dart';

/// Helper class to represent a geofence entry with reminder metadata
class _GeofenceEntry {
  final String reminderId;
  final String locationId;
  final double latitude;
  final double longitude;
  final double distance;

  _GeofenceEntry({
    required this.reminderId,
    required this.locationId,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });
}

/// Manages dynamic geofence registration to handle the 100 geofence limit
/// Only registers the nearest 95 geofences (buffer below limit)
class DynamicGeofenceManager {
  static const int _maxGeofences = 95; // Buffer below Android's 100 limit
  static const double _significantMoveDistanceMeters = 500.0;

  StreamSubscription<Position>? _locationSubscription;
  Position? _lastUpdatePosition;
  List<Reminder> _allReminders = [];
  Set<String> _registeredGeofenceIds = {};

  // Track reminders that have pending initial state checks to prevent duplicates
  final Set<String> _pendingInitialChecks = {};

  final Function(
          String id, double lat, double lng, double radius, int dwellTimeMs)
      registerGeofenceCallback;
  final Function(String id) unregisterGeofenceCallback;

  DynamicGeofenceManager({
    required this.registerGeofenceCallback,
    required this.unregisterGeofenceCallback,
  });

  /// Initialize and start monitoring location for dynamic geofence updates
  Future<void> initialize(List<Reminder> reminders) async {
    _allReminders = List.from(reminders);
    DebugLogService().log(
      'Initializing dynamic geofence manager with ${reminders.length} reminders',
      type: DebugLogType.info,
    );

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

    // Clear any pending initial check for this reminder
    _pendingInitialChecks.remove(reminderId);

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
    _pendingInitialChecks.clear();
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
        debugPrint(
            'DynamicGeofenceManager: Significant location change detected');
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
    DebugLogService().log('Location changed significantly, updating geofences',
        type: DebugLogType.info);
    await _updateGeofences();
  }

  /// Re-evaluate and update registered geofences based on current location
  Future<void> _updateGeofences() async {
    DebugLogService().log('Evaluating geofences...', type: DebugLogType.info);
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
        debugPrint(
            'DynamicGeofenceManager: Could not get current position: $e');
        // Use last known position if available
        currentPosition = _lastUpdatePosition;
      }

      if (currentPosition == null) {
        debugPrint(
            'DynamicGeofenceManager: No position available, skipping update');
        return;
      }

      // Flatten reminders into individual location entries
      final List<MapEntry<String, _GeofenceEntry>> locationEntries = [];
      for (final reminder in _allReminders) {
        if (reminder.locations.isNotEmpty) {
          // New format: multiple locations per reminder
          for (final location in reminder.locations) {
            final distance = Geolocator.distanceBetween(
              currentPosition.latitude,
              currentPosition.longitude,
              location.latitude,
              location.longitude,
            );
            final geofenceId = '${reminder.id}_${location.poiId}';
            locationEntries.add(MapEntry(
                geofenceId,
                _GeofenceEntry(
                  reminderId: reminder.id,
                  locationId: location.poiId,
                  latitude: location.latitude,
                  longitude: location.longitude,
                  distance: distance,
                )));
          }
        } else {
          // Fallback for old format: single location
          final distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            reminder.latitude,
            reminder.longitude,
          );
          locationEntries.add(MapEntry(
              reminder.id,
              _GeofenceEntry(
                reminderId: reminder.id,
                locationId: reminder.id,
                latitude: reminder.latitude,
                longitude: reminder.longitude,
                distance: distance,
              )));
        }
      }

      // Sort by distance (nearest first)
      locationEntries
          .sort((a, b) => a.value.distance.compareTo(b.value.distance));

      // Take the nearest N locations
      final nearestEntries = locationEntries.take(_maxGeofences).toList();

      final nearestIds = nearestEntries.map((e) => e.key).toSet();

      // Get settings for registration
      final prefs = await SharedPreferences.getInstance();
      final dwellTimeMinutes = prefs.getInt('dwell_time_minutes') ?? 1;
      final proximityRadius = prefs.getInt('proximity_radius_meters') ?? 150;

      // Unregister geofences that are no longer in the nearest set
      final toUnregister = _registeredGeofenceIds.difference(nearestIds);
      for (final id in toUnregister) {
        debugPrint('DynamicGeofenceManager: Unregistering far geofence: $id');
        DebugLogService().log('Unregistered far geofence: $id',
            type: DebugLogType.unregister);
        await unregisterGeofenceCallback(id);
        _registeredGeofenceIds.remove(id);
        // Clear any pending initial check
        _pendingInitialChecks.remove(id);
      }

      // Register new geofences that are now in the nearest set
      final toRegister = nearestIds.difference(_registeredGeofenceIds);

      if (toRegister.isEmpty && toUnregister.isEmpty) {
        DebugLogService()
            .log('No geofence changes needed', type: DebugLogType.info);

        // Check if already inside any existing geofences
        for (final entry in nearestEntries) {
          final geofenceId = entry.key;
          final geofenceEntry = entry.value;

          if (_registeredGeofenceIds.contains(geofenceId)) {
            if (geofenceEntry.distance <= proximityRadius) {
              // Skip if already pending to prevent duplicates
              if (_pendingInitialChecks.contains(geofenceId)) {
                continue;
              }

              // Find the reminder to get brand name
              final reminder = _allReminders
                  .firstWhere((r) => r.id == geofenceEntry.reminderId);

              debugPrint(
                  'DynamicGeofenceManager: Already inside existing geofence: ${reminder.brandName} (${geofenceEntry.distance.toStringAsFixed(0)}m)');
              DebugLogService().log(
                'Already inside: ${reminder.brandName} (${geofenceEntry.distance.toStringAsFixed(0)}m)',
                type: DebugLogType.geofenceEnter,
              );

              // Check if we should trigger initial state notification
              _handleInitialGeofenceState(
                  geofenceId, reminder, dwellTimeMinutes, proximityRadius);
            }
          }
        }
      }

      for (final id in toRegister) {
        final entry = nearestEntries.firstWhere((e) => e.key == id);
        final geofenceEntry = entry.value;
        final reminder =
            _allReminders.firstWhere((r) => r.id == geofenceEntry.reminderId);

        debugPrint(
            'DynamicGeofenceManager: Registering near geofence: $id (distance: ${geofenceEntry.distance.toStringAsFixed(0)}m)');
        DebugLogService().log('Registered near geofence: ${reminder.brandName}',
            type: DebugLogType.register);

        await registerGeofenceCallback(
          id,
          geofenceEntry.latitude,
          geofenceEntry.longitude,
          proximityRadius.toDouble(),
          dwellTimeMinutes * 60 * 1000, // Convert to milliseconds
        );
        _registeredGeofenceIds.add(id);
      }

      // After all registrations, check if we're already inside any of the newly registered geofences
      for (final id in toRegister) {
        final entry = nearestEntries.firstWhere((e) => e.key == id);
        final geofenceEntry = entry.value;
        final reminder =
            _allReminders.firstWhere((r) => r.id == geofenceEntry.reminderId);

        if (geofenceEntry.distance <= proximityRadius) {
          // Skip if already pending to prevent duplicates
          if (_pendingInitialChecks.contains(id)) {
            continue;
          }

          debugPrint(
              'DynamicGeofenceManager: Already inside newly registered geofence: ${reminder.brandName}');
          DebugLogService().log(
            'Already inside: ${reminder.brandName} (${geofenceEntry.distance.toStringAsFixed(0)}m)',
            type: DebugLogType.geofenceEnter,
          );

          // Trigger immediate notification for initial state
          _handleInitialGeofenceState(
              id, reminder, dwellTimeMinutes, proximityRadius);
        }
      }

      // Save updated registered IDs
      await _saveRegisteredIds();

      debugPrint(
          'DynamicGeofenceManager: Active geofences: ${_registeredGeofenceIds.length} locations');
      DebugLogService().log(
        'Active geofences: ${_registeredGeofenceIds.length} locations',
        type: DebugLogType.info,
      );
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
      debugPrint(
          'DynamicGeofenceManager: Loaded ${_registeredGeofenceIds.length} registered IDs from storage');

      if (_registeredGeofenceIds.isNotEmpty) {
        DebugLogService().log(
          'Found ${_registeredGeofenceIds.length} previously registered geofences',
          type: DebugLogType.info,
        );

        // Log existing registrations with brand names
        for (final id in _registeredGeofenceIds) {
          try {
            final reminder = _allReminders.firstWhere((r) => r.id == id);
            DebugLogService().log(
              'Already registered: ${reminder.brandName}',
              type: DebugLogType.info,
            );
          } catch (e) {
            // ID might be stale if reminder was deleted
            DebugLogService().log(
              'Found stale geofence ID in storage: $id',
              type: DebugLogType.info,
            );
          }
        }
      } else {
        DebugLogService().log(
          'No previously registered geofences found',
          type: DebugLogType.info,
        );
      }
    } catch (e) {
      debugPrint('DynamicGeofenceManager: Error loading registered IDs: $e');
      DebugLogService().log(
        'Error loading registered IDs: $e',
        type: DebugLogType.error,
      );
    }
  }

  /// Save registered geofence IDs to SharedPreferences
  Future<void> _saveRegisteredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'registered_geofence_ids', _registeredGeofenceIds.toList());
    } catch (e) {
      debugPrint('DynamicGeofenceManager: Error saving registered IDs: $e');
    }
  }

  /// Handle initial geofence state when user is already inside a POI
  void _handleInitialGeofenceState(String geofenceId, Reminder reminder,
      int dwellTimeMinutes, int proximityRadius) {
    // Prevent duplicate checks for the same geofence
    if (_pendingInitialChecks.contains(geofenceId)) {
      debugPrint(
          'DynamicGeofenceManager: Initial check already pending for ${reminder.brandName}');
      return;
    }

    // Mark as pending
    _pendingInitialChecks.add(geofenceId);

    // Run asynchronously without blocking
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastNotificationKey = 'last_notification_${reminder.id}';
        final lastNotificationTime = prefs.getInt(lastNotificationKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Check cooldown period (24 hours)
        const cooldownMs = 24 * 60 * 60 * 1000;
        if (now - lastNotificationTime < cooldownMs) {
          debugPrint(
              'DynamicGeofenceManager: Skipping initial notification for ${reminder.brandName} (cooldown period)');
          DebugLogService().log(
            'Skipped notification for ${reminder.brandName} (cooldown)',
            type: DebugLogType.info,
          );
          return;
        }

        // Wait for dwell time before sending notification
        debugPrint(
            'DynamicGeofenceManager: Waiting ${dwellTimeMinutes}min dwell time for ${reminder.brandName}');
        DebugLogService().log(
          'Waiting ${dwellTimeMinutes}min dwell time for ${reminder.brandName}',
          type: DebugLogType.info,
        );

        await Future.delayed(Duration(minutes: dwellTimeMinutes));

        // Verify still inside after dwell time
        final currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ).timeout(const Duration(seconds: 10));

        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          reminder.latitude,
          reminder.longitude,
        );

        if (distance <= proximityRadius) {
          // Still inside - send notification
          debugPrint(
              'DynamicGeofenceManager: Sending initial notification for ${reminder.brandName}');
          DebugLogService().log(
            'Dwell event for ${reminder.brandName} (notification sent)',
            type: DebugLogType.geofenceDwell,
          );

          // Save notification time
          await prefs.setInt(lastNotificationKey, now);

          // Send actual notification
          await NotificationService().showReminderNotification(
            poiId: reminder.id,
            poiName: reminder.originalPoiName,
            brandName: reminder.brandName,
            items: reminder.items.map((item) => item.text).toList(),
          );
        } else {
          debugPrint(
              'DynamicGeofenceManager: User left ${reminder.brandName} during dwell wait');
          DebugLogService().log(
            'User left ${reminder.brandName} during dwell wait',
            type: DebugLogType.info,
          );
        }
      } catch (e) {
        debugPrint('DynamicGeofenceManager: Error handling initial state: $e');
        DebugLogService().log(
          'Error handling initial state: $e',
          type: DebugLogType.error,
        );
      } finally {
        // Remove from pending set when complete
        _pendingInitialChecks.remove(reminder.id);
      }
    });
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

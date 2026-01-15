import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/poi.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import '../services/location_monitor_service.dart';
import '../services/background_geofence_service.dart';
import '../services/geofence_strategy_manager.dart';
import '../utils/brand_matcher.dart';

/// Provider for managing shopping reminders
class ReminderProvider extends ChangeNotifier {
  final ReminderService _reminderService = ReminderService();
  final LocationMonitorService _locationService = LocationMonitorService();
  final BackgroundGeofenceService _backgroundGeofence = BackgroundGeofenceService();
  final GeofenceStrategyManager _strategyManager = GeofenceStrategyManager();

  List<Reminder> _reminders = [];
  bool _isLoading = false;
  String? _error;

  List<Reminder> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReminders => _reminders.isNotEmpty;

  /// Initialize and load reminders
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Initialize strategy manager and background service
      await _strategyManager.initialize();
      await _backgroundGeofence.initialize();
      
      _reminders = await _reminderService.loadReminders();

      // Start monitoring if reminders exist
      if (_reminders.isNotEmpty) {
        await _startMonitoringWithStrategy();
      }
    } catch (e) {
      _error = 'Failed to load reminders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start monitoring using the appropriate strategy based on availability
  Future<void> _startMonitoringWithStrategy() async {
    if (_reminders.isEmpty) return;

    // Always re-evaluate strategy on app launch to allow recovery
    bool canUseNative = true;
    String? fallbackReason;

    // Check 1: Platform support (iOS always uses native, Android needs Play Services)
    if (Platform.isAndroid) {
      final hasPlayServices = await _locationService.isPlayServicesAvailable();
      if (!hasPlayServices) {
        canUseNative = false;
        fallbackReason = 'Google Play Services unavailable';
      }
    }

    // Check 2: Background location permission
    if (canUseNative) {
      final hasBackgroundPermission = await _locationService.hasBackgroundPermission();
      if (!hasBackgroundPermission) {
        canUseNative = false;
        fallbackReason = 'Background location permission denied';
      }
    }

    // Apply the appropriate strategy
    if (canUseNative) {
      debugPrint('Starting native geofencing monitoring');
      await _strategyManager.useNativeGeofencing();
      await _locationService.startMonitoring(_reminders);
      // Stop polling if it was running
      await _backgroundGeofence.stopMonitoring();
    } else {
      debugPrint('Falling back to polling monitoring: $fallbackReason');
      await _strategyManager.fallbackToPolling(fallbackReason!);
      // Stop native monitoring if it was running
      await _locationService.stopMonitoring();
      // Start polling
      await _backgroundGeofence.startMonitoring(_reminders);
    }
  }

  /// Check if a brand has a reminder
  bool hasReminderForBrand(String? brandName) {
    if (brandName == null) return false;
    return _reminders.any(
      (r) => r.brandName.toLowerCase() == brandName.toLowerCase(),
    );
  }

  /// Get reminder for a specific brand
  Reminder? getReminderForBrand(String brandName) {
    try {
      return _reminders.firstWhere(
        (r) => r.brandName.toLowerCase() == brandName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get reminder for a specific POI
  Reminder? getReminderForPOI(POI poi) {
    final brandName = BrandMatcher.extractBrand(poi.name);
    if (brandName == null) return null;
    return getReminderForBrand(brandName);
  }

  /// Add a new reminder
  Future<bool> addReminder(POI poi, List<String> shoppingItems) async {
    try {
      final brandName = BrandMatcher.extractBrand(poi.name);
      if (brandName == null) {
        _error = 'Could not extract brand name from POI';
        notifyListeners();
        return false;
      }

      // Check if reminder already exists for this brand
      if (hasReminderForBrand(brandName)) {
        _error = 'Reminder already exists for $brandName';
        notifyListeners();
        return false;
      }

      final items =
          shoppingItems.map((text) => ShoppingItem(text: text)).toList();

      final reminder = Reminder(
        brandName: brandName,
        originalPoiId: poi.id,
        originalPoiName: poi.name,
        poiType: poi.type,
        latitude: poi.latitude,
        longitude: poi.longitude,
        items: items,
      );

      final success = await _reminderService.saveReminder(reminder);
      if (success) {
        _reminders.add(reminder);

        // Restart monitoring with updated reminders using current strategy
        if (_strategyManager.isUsingNativeGeofencing) {
          await _locationService.stopMonitoring();
          await _locationService.startMonitoring(_reminders);
          // Notify location service of new reminder for dynamic geofence management
          await _locationService.onReminderAdded(reminder);
        } else {
          await _backgroundGeofence.updateReminders(_reminders);
        }

        notifyListeners();
        return true;
      } else {
        _error = 'Failed to save reminder';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error adding reminder: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add a test reminder for debugging (bypasses brand extraction)
  Future<bool> addReminderForTestPoi(
      POI poi, List<String> shoppingItems) async {
    try {
      // Use the POI name directly as the brand name for test POIs
      final brandName = poi.name;

      // Check if reminder already exists for this brand
      if (hasReminderForBrand(brandName)) {
        _error = 'Test reminder already exists';
        notifyListeners();
        return false;
      }

      final items =
          shoppingItems.map((text) => ShoppingItem(text: text)).toList();

      final reminder = Reminder(
        brandName: brandName,
        originalPoiId: poi.id,
        originalPoiName: poi.name,
        poiType: poi.type,
        latitude: poi.latitude,
        longitude: poi.longitude,
        items: items,
      );

      final success = await _reminderService.saveReminder(reminder);
      if (success) {
        _reminders.add(reminder);

        // Restart monitoring with updated reminders using current strategy
        if (_strategyManager.isUsingNativeGeofencing) {
          await _locationService.stopMonitoring();
          await _locationService.startMonitoring(_reminders);
          // Notify location service of new reminder for dynamic geofence management
          await _locationService.onReminderAdded(reminder);
        } else {
          await _backgroundGeofence.updateReminders(_reminders);
        }

        notifyListeners();
        return true;
      } else {
        _error = 'Failed to save test reminder';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error adding test reminder: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove a reminder
  Future<bool> removeReminder(String id) async {
    try {
      final success = await _reminderService.deleteReminder(id);
      if (success) {
        _reminders.removeWhere((r) => r.id == id);

        // Restart monitoring or stop if no reminders left using current strategy
        if (_strategyManager.isUsingNativeGeofencing) {
          // Notify location service of reminder removal
          await _locationService.onReminderRemoved(id);
          await _locationService.stopMonitoring();
          if (_reminders.isNotEmpty) {
            await _locationService.startMonitoring(_reminders);
          }
        } else {
          if (_reminders.isNotEmpty) {
            await _backgroundGeofence.updateReminders(_reminders);
          } else {
            await _backgroundGeofence.stopMonitoring();
          }
        }

        notifyListeners();
        return true;
      } else {
        _error = 'Failed to delete reminder';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error removing reminder: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle a shopping item (check/uncheck)
  Future<bool> toggleItem(String reminderId, String itemId) async {
    try {
      final reminderIndex = _reminders.indexWhere((r) => r.id == reminderId);
      if (reminderIndex < 0) return false;

      final reminder = _reminders[reminderIndex];
      final itemIndex = reminder.items.indexWhere((item) => item.id == itemId);
      if (itemIndex < 0) return false;

      final item = reminder.items[itemIndex];
      final updatedItem = item.copyWith(isChecked: !item.isChecked);

      final updatedItems = List<ShoppingItem>.from(reminder.items);
      updatedItems[itemIndex] = updatedItem;

      final updatedReminder = reminder.copyWith(items: updatedItems);

      // Check if all items are now checked -> auto-remove reminder
      if (updatedReminder.allItemsChecked) {
        return await removeReminder(reminderId);
      }

      final success = await _reminderService.updateReminder(updatedReminder);
      if (success) {
        _reminders[reminderIndex] = updatedReminder;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = 'Error toggling item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add a new shopping item to a reminder
  Future<bool> addItem(String reminderId, String itemText) async {
    try {
      final reminderIndex = _reminders.indexWhere((r) => r.id == reminderId);
      if (reminderIndex < 0) return false;

      final reminder = _reminders[reminderIndex];
      final newItem = ShoppingItem(text: itemText);

      final updatedItems = List<ShoppingItem>.from(reminder.items)
        ..add(newItem);

      final updatedReminder = reminder.copyWith(items: updatedItems);

      final success = await _reminderService.updateReminder(updatedReminder);
      if (success) {
        _reminders[reminderIndex] = updatedReminder;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = 'Error adding item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove a shopping item from a reminder
  Future<bool> removeItem(String reminderId, String itemId) async {
    try {
      final reminderIndex = _reminders.indexWhere((r) => r.id == reminderId);
      if (reminderIndex < 0) return false;

      final reminder = _reminders[reminderIndex];
      final updatedItems =
          reminder.items.where((item) => item.id != itemId).toList();

      // If no items left, remove the reminder entirely
      if (updatedItems.isEmpty) {
        return await removeReminder(reminderId);
      }

      final updatedReminder = reminder.copyWith(items: updatedItems);

      final success = await _reminderService.updateReminder(updatedReminder);
      if (success) {
        _reminders[reminderIndex] = updatedReminder;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = 'Error removing item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear all reminders
  Future<void> clearAll() async {
    try {
      await _reminderService.clearAllReminders();
      await _locationService.stopMonitoring();
      _reminders = [];

      notifyListeners();
    } catch (e) {
      _error = 'Error clearing reminders: $e';
      notifyListeners();
    }
  }
}

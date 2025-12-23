import 'package:flutter/material.dart';
import '../models/poi_type.dart';
import '../utils/settings_service.dart';

/// Provider for managing user settings
///
/// Handles loading, saving, and updating user preferences including
/// POI type ordering for personalized results.
class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  List<POIType> _poiTypeOrder = [];
  int _poiSearchDistance = SettingsService.defaultPoiDistance;
  bool _isLoading = true;

  SettingsProvider({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  /// Current POI type order (user's preference)
  List<POIType> get poiTypeOrder => List.unmodifiable(_poiTypeOrder);

  /// Current POI search distance in meters
  int get poiSearchDistance => _poiSearchDistance;

  /// Whether settings are currently being loaded
  bool get isLoading => _isLoading;

  /// Initialize and load settings from storage
  Future<void> initialize() async {
    _poiSearchDistance = await _settingsService.loadPoiDistance();
    _isLoading = true;
    notifyListeners();

    _poiTypeOrder = await _settingsService.loadPoiOrder();

    _isLoading = false;
    notifyListeners();
  }

  /// Update POI type order and persist to storage
  Future<void> updatePoiOrder(List<POIType> newOrder) async {
    _poiTypeOrder = List.from(newOrder);
    notifyListeners();

    await _settingsService.savePoiOrder(newOrder);
  }

  /// Reset POI order to default
  Future<void> resetPoiOrder() async {
    await _settingsService.resetPoiOrder();
    _poiTypeOrder = List.from(SettingsService.defaultPoiOrder);
    notifyListeners();
  }

  /// Update POI search distance and persist to storage
  Future<void> updatePoiDistance(int distance) async {
    _poiSearchDistance = distance;
    notifyListeners();

    await _settingsService.savePoiDistance(distance);
  }

  /// Get priority index for a POI type (lower = higher priority)
  /// Returns the position in the user's ordered list
  int getPriorityIndex(POIType type) {
    final index = _poiTypeOrder.indexOf(type);
    return index >= 0 ? index : _poiTypeOrder.length;
  }
}

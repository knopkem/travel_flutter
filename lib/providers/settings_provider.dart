import 'package:flutter/material.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';
import '../utils/settings_service.dart';

/// Provider for managing user settings
///
/// Handles loading, saving, and updating user preferences including
/// POI type ordering for personalized results.
class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  List<POIType> _poiTypeOrder = [];
  int _poiSearchDistance = SettingsService.defaultPoiDistance;
  Map<POISource, bool> _poiProvidersEnabled = {};
  bool _isLoading = true;

  SettingsProvider({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  /// Current POI type order (user's preference)
  List<POIType> get poiTypeOrder => List.unmodifiable(_poiTypeOrder);

  /// Current POI search distance in meters
  int get poiSearchDistance => _poiSearchDistance;

  /// Current POI providers enabled state
  Map<POISource, bool> get poiProvidersEnabled =>
      Map.unmodifiable(_poiProvidersEnabled);

  /// Get list of enabled POI sources
  List<POISource> get enabledPoiSources => _poiProvidersEnabled.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList();

  /// Check if a specific POI source is enabled
  bool isProviderEnabled(POISource source) =>
      _poiProvidersEnabled[source] ?? true;

  /// Check if all providers are disabled
  bool get allProvidersDisabled =>
      _poiProvidersEnabled.values.every((enabled) => !enabled);

  /// Whether settings are currently being loaded
  bool get isLoading => _isLoading;

  /// Initialize and load settings from storage
  Future<void> initialize() async {
    _poiSearchDistance = await _settingsService.loadPoiDistance();
    _poiProvidersEnabled = await _settingsService.loadPoiProvidersEnabled();
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

  /// Update POI provider enabled state and persist to storage
  Future<void> updateProviderEnabled(POISource source, bool enabled) async {
    _poiProvidersEnabled[source] = enabled;
    notifyListeners();

    await _settingsService.savePoiProvidersEnabled(_poiProvidersEnabled);
  }

  /// Update multiple POI providers at once
  Future<void> updateProvidersEnabled(Map<POISource, bool> enabled) async {
    _poiProvidersEnabled = Map.from(enabled);
    notifyListeners();

    await _settingsService.savePoiProvidersEnabled(_poiProvidersEnabled);
  }

  /// Reset POI providers to default (all enabled)
  Future<void> resetPoiProviders() async {
    await _settingsService.resetPoiProvidersEnabled();
    _poiProvidersEnabled = Map.from(SettingsService.defaultPoiProvidersEnabled);
    notifyListeners();
  }
}

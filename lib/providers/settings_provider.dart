import 'package:flutter/material.dart';
import '../models/poi_category.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';
import '../utils/settings_service.dart';
import '../services/openai_service.dart';
import '../services/background_service_manager.dart';
import '../services/reminder_service.dart';
import '../repositories/google_places_repository.dart';

/// Provider for managing user settings
///
/// Handles loading, saving, and updating user preferences including
/// POI type ordering and enabled state for personalized results.
class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  final OpenAIService _openAIService;
  List<(POIType, bool)> _poiTypeOrder = [];
  List<(POIType, bool)> _attractionPoiOrder = [];
  List<(POIType, bool)> _commercialPoiOrder = [];
  int _poiSearchDistance = SettingsService.defaultPoiDistance;
  Map<POISource, bool> _poiProvidersEnabled = {};
  String? _openaiApiKey;
  bool _isLoading = true;
  String _openaiModel = SettingsService.defaultOpenAIModel;
  int _aiBatchSize = SettingsService.defaultAIBatchSize;
  bool _useLocalContent = SettingsService.defaultUseLocalContent;
  String? _googlePlacesApiKey;
  int _googlePlacesRequestCount = 0;
  POICategory _defaultPoiCategory = POICategory.attraction;
  bool _backgroundLocationEnabled = true;

  SettingsProvider({
    SettingsService? settingsService,
    OpenAIService? openAIService,
  })  : _settingsService = settingsService ?? SettingsService(),
        _openAIService = openAIService ?? OpenAIService();

  /// Current POI type order with enabled state (user's preference)
  List<(POIType, bool)> get poiTypeOrder => List.unmodifiable(_poiTypeOrder);

  /// Attraction POI type order with enabled state
  List<(POIType, bool)> get attractionPoiOrder =>
      List.unmodifiable(_attractionPoiOrder);

  /// Commercial POI type order with enabled state
  List<(POIType, bool)> get commercialPoiOrder =>
      List.unmodifiable(_commercialPoiOrder);

  /// Get list of enabled POI types in priority order (combines both categories)
  List<POIType> get enabledPoiTypes {
    final enabledAttractions =
        _attractionPoiOrder.where((entry) => entry.$2).map((entry) => entry.$1);
    final enabledCommercial =
        _commercialPoiOrder.where((entry) => entry.$2).map((entry) => entry.$1);
    return [...enabledAttractions, ...enabledCommercial];
  }

  /// Get list of enabled attraction POI types in priority order
  List<POIType> get enabledAttractionPoiTypes => _attractionPoiOrder
      .where((entry) => entry.$2)
      .map((entry) => entry.$1)
      .toList();

  /// Get list of enabled commercial POI types in priority order
  List<POIType> get enabledCommercialPoiTypes => _commercialPoiOrder
      .where((entry) => entry.$2)
      .map((entry) => entry.$1)
      .toList();

  /// Check if a specific POI type is enabled
  bool isPoiTypeEnabled(POIType type) {
    // Check in the appropriate category list
    if (type.category == POICategory.attraction) {
      final entry = _attractionPoiOrder.firstWhere(
        (e) => e.$1 == type,
        orElse: () => (type, true),
      );
      return entry.$2;
    } else {
      final entry = _commercialPoiOrder.firstWhere(
        (e) => e.$1 == type,
        orElse: () => (type, true),
      );
      return entry.$2;
    }
  }

  /// Check if all POI types are disabled (both categories)
  bool get allPoiTypesDisabled =>
      allAttractionPoiTypesDisabled && allCommercialPoiTypesDisabled;

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

  /// Check if OpenAI API key is configured
  bool get hasValidOpenAIKey =>
      _openaiApiKey != null && _openaiApiKey!.isNotEmpty;

  /// Get the OpenAI API key (for use by other providers)
  String? get openaiApiKey => _openaiApiKey;

  /// Get the selected OpenAI model
  String get openaiModel => _openaiModel;

  /// Get the AI batch size
  int get aiBatchSize => _aiBatchSize;

  /// Check if Google Places API key is configured
  bool get hasValidGooglePlacesKey =>
      _googlePlacesApiKey != null && _googlePlacesApiKey!.isNotEmpty;

  /// Get the Google Places API key
  String? get googlePlacesApiKey => _googlePlacesApiKey;

  /// Get the Google Places monthly request count
  int get googlePlacesRequestCount => _googlePlacesRequestCount;

  /// Whether to use local content based on location country
  bool get useLocalContent => _useLocalContent;

  /// Default POI category to display on startup
  POICategory get defaultPoiCategory => _defaultPoiCategory;

  /// Whether background location monitoring is enabled for reminders
  bool get backgroundLocationEnabled => _backgroundLocationEnabled;

  /// Whether settings are currently being loaded
  bool get isLoading => _isLoading;

  /// Initialize and load settings from storage
  Future<void> initialize() async {
    _poiSearchDistance = await _settingsService.loadPoiDistance();
    _poiProvidersEnabled = await _settingsService.loadPoiProvidersEnabled();
    _openaiApiKey = await _settingsService.loadOpenAIApiKey();
    _openaiModel = await _settingsService.loadOpenAIModel();
    _aiBatchSize = await _settingsService.loadAIBatchSize();
    _useLocalContent = await _settingsService.loadUseLocalContent();
    _googlePlacesApiKey = await _settingsService.loadGooglePlacesApiKey();
    final gpCount = await _settingsService.loadGooglePlacesRequestCount();
    _googlePlacesRequestCount = gpCount.$1;
    _defaultPoiCategory = await _settingsService.loadDefaultPoiCategory();
    _backgroundLocationEnabled =
        await _settingsService.loadBackgroundLocationEnabled();
    _isLoading = true;
    notifyListeners();

    _poiTypeOrder = await _settingsService.loadPoiOrder();
    _attractionPoiOrder = await _settingsService.loadAttractionPoiOrder();
    _commercialPoiOrder = await _settingsService.loadCommercialPoiOrder();

    _isLoading = false;
    notifyListeners();
  }

  /// Update POI type order and persist to storage
  Future<void> updatePoiOrder(List<(POIType, bool)> newOrder) async {
    _poiTypeOrder = List.from(newOrder);
    notifyListeners();

    await _settingsService.savePoiOrder(newOrder);
  }

  /// Update POI type enabled state and persist to storage
  Future<void> updatePoiTypeEnabled(POIType type, bool enabled) async {
    final index = _poiTypeOrder.indexWhere((entry) => entry.$1 == type);
    if (index >= 0) {
      _poiTypeOrder[index] = (type, enabled);
      notifyListeners();
      await _settingsService.savePoiOrder(_poiTypeOrder);
    }
  }

  /// Reset POI order to default (all types enabled)
  Future<void> resetPoiOrder() async {
    await _settingsService.resetPoiOrder();
    _poiTypeOrder =
        SettingsService.defaultPoiOrder.map((type) => (type, true)).toList();
    notifyListeners();
  }

  /// Update attraction POI type order and persist to storage
  Future<void> updateAttractionPoiOrder(List<(POIType, bool)> newOrder) async {
    _attractionPoiOrder = List.from(newOrder);
    notifyListeners();
    await _settingsService.saveAttractionPoiOrder(newOrder);
  }

  /// Update attraction POI type enabled state
  Future<void> updateAttractionPoiTypeEnabled(
      POIType type, bool enabled) async {
    final index = _attractionPoiOrder.indexWhere((entry) => entry.$1 == type);
    if (index >= 0) {
      _attractionPoiOrder[index] = (type, enabled);
      notifyListeners();
      await _settingsService.saveAttractionPoiOrder(_attractionPoiOrder);
    }
  }

  /// Reset attraction POI order to default (all types enabled)
  Future<void> resetAttractionPoiOrder() async {
    await _settingsService.resetAttractionPoiOrder();
    _attractionPoiOrder = SettingsService.defaultAttractionPoiOrder
        .map((type) => (type, true))
        .toList();
    notifyListeners();
  }

  /// Update commercial POI type order and persist to storage
  Future<void> updateCommercialPoiOrder(List<(POIType, bool)> newOrder) async {
    _commercialPoiOrder = List.from(newOrder);
    notifyListeners();
    await _settingsService.saveCommercialPoiOrder(newOrder);
  }

  /// Update commercial POI type enabled state
  Future<void> updateCommercialPoiTypeEnabled(
      POIType type, bool enabled) async {
    final index = _commercialPoiOrder.indexWhere((entry) => entry.$1 == type);
    if (index >= 0) {
      _commercialPoiOrder[index] = (type, enabled);
      notifyListeners();
      await _settingsService.saveCommercialPoiOrder(_commercialPoiOrder);
    }
  }

  /// Reset commercial POI order to default (all types enabled)
  Future<void> resetCommercialPoiOrder() async {
    await _settingsService.resetCommercialPoiOrder();
    _commercialPoiOrder = SettingsService.defaultCommercialPoiOrder
        .map((type) => (type, true))
        .toList();
    notifyListeners();
  }

  /// Check if all attraction POI types are disabled
  bool get allAttractionPoiTypesDisabled =>
      _attractionPoiOrder.every((entry) => !entry.$2);

  /// Check if all commercial POI types are disabled
  bool get allCommercialPoiTypesDisabled =>
      _commercialPoiOrder.every((entry) => !entry.$2);

  /// Update POI search distance and persist to storage
  Future<void> updatePoiDistance(int distance) async {
    _poiSearchDistance = distance;
    notifyListeners();

    await _settingsService.savePoiDistance(distance);
  }

  /// Get priority index for a POI type (lower = higher priority)
  /// Returns the position in the user's ordered list (only considering enabled types)
  int getPriorityIndex(POIType type) {
    // Check in the appropriate category list
    if (type.category == POICategory.attraction) {
      final index = _attractionPoiOrder.indexWhere((entry) => entry.$1 == type);
      return index >= 0 ? index : _attractionPoiOrder.length;
    } else {
      final index = _commercialPoiOrder.indexWhere((entry) => entry.$1 == type);
      return index >= 0 ? index : _commercialPoiOrder.length;
    }
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

  /// Update OpenAI API key after validation
  Future<bool> updateOpenAIApiKey(String apiKey) async {
    try {
      // Validate the API key first
      final isValid = await _openAIService.validateApiKey(apiKey);
      if (!isValid) {
        return false;
      }

      // Save the valid key
      final saved = await _settingsService.saveOpenAIApiKey(apiKey);
      if (saved) {
        _openaiApiKey = apiKey;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // Validation failed (network error, etc.)
      return false;
    }
  }

  /// Remove OpenAI API key
  Future<bool> removeOpenAIApiKey() async {
    final deleted = await _settingsService.deleteOpenAIApiKey();
    if (deleted) {
      _openaiApiKey = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update OpenAI model selection
  Future<void> updateOpenAIModel(String model) async {
    await _settingsService.saveOpenAIModel(model);
    _openaiModel = model;
    notifyListeners();
  }

  /// Update AI batch size
  Future<void> updateAIBatchSize(int batchSize) async {
    await _settingsService.saveAIBatchSize(batchSize);
    _aiBatchSize = batchSize;
    notifyListeners();
  }

  /// Update use local content setting
  Future<void> updateUseLocalContent(bool useLocal) async {
    await _settingsService.saveUseLocalContent(useLocal);
    _useLocalContent = useLocal;
    notifyListeners();
  }

  /// Update default POI category setting
  Future<void> updateDefaultPoiCategory(POICategory category) async {
    await _settingsService.saveDefaultPoiCategory(category);
    _defaultPoiCategory = category;
    notifyListeners();
  }

  /// Update Google Places API key after validation
  Future<bool> updateGooglePlacesApiKey(String apiKey) async {
    try {
      // Validate the API key first
      final isValid = await GooglePlacesRepository.validateApiKey(apiKey);
      if (!isValid) {
        return false;
      }

      // Save the valid key
      final saved = await _settingsService.saveGooglePlacesApiKey(apiKey);
      if (saved) {
        _googlePlacesApiKey = apiKey;

        // Auto-disable other providers when Google Places is enabled
        // (users can still re-enable them if desired)
        _poiProvidersEnabled[POISource.wikipediaGeosearch] = false;
        _poiProvidersEnabled[POISource.overpass] = false;
        _poiProvidersEnabled[POISource.wikidata] = false;
        _poiProvidersEnabled[POISource.googlePlaces] = true;

        await _settingsService.savePoiProvidersEnabled(_poiProvidersEnabled);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Remove Google Places API key
  Future<bool> removeGooglePlacesApiKey() async {
    final deleted = await _settingsService.deleteGooglePlacesApiKey();
    if (deleted) {
      _googlePlacesApiKey = null;
      // Disable Google Places when key is removed
      await updateProviderEnabled(POISource.googlePlaces, false);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Increment Google Places request count
  Future<void> incrementGooglePlacesRequestCount() async {
    _googlePlacesRequestCount++;
    await _settingsService.saveGooglePlacesRequestCount(
        _googlePlacesRequestCount, DateTime.now());
    notifyListeners();
  }

  /// Update background location enabled setting
  Future<void> updateBackgroundLocationEnabled(bool enabled) async {
    await _settingsService.saveBackgroundLocationEnabled(enabled);
    _backgroundLocationEnabled = enabled;

    // Control the background service based on setting
    if (enabled) {
      // Start the service if there are reminders
      await _restartBackgroundServiceIfNeeded();
    } else {
      // Stop the service
      await _stopBackgroundService();
    }

    notifyListeners();
  }

  /// Restart background service if reminders exist
  Future<void> _restartBackgroundServiceIfNeeded() async {
    try {
      final reminderService = ReminderService();
      final reminders = await reminderService.loadReminders();
      if (reminders.isNotEmpty) {
        await BackgroundServiceManager.startService();
        await BackgroundServiceManager.updateReminderCount();
      }
    } catch (e) {
      debugPrint('Error restarting background service: $e');
    }
  }

  /// Stop background service
  Future<void> _stopBackgroundService() async {
    try {
      await BackgroundServiceManager.stopService();
    } catch (e) {
      debugPrint('Error stopping background service: $e');
    }
  }
}

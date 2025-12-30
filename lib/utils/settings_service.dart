import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/poi_category.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';

/// Service for persisting user settings using SharedPreferences
class SettingsService {
  static const String _poiOrderKey = 'poi_type_order';
  static const String _attractionPoiOrderKey = 'attraction_poi_type_order';
  static const String _commercialPoiOrderKey = 'commercial_poi_type_order';
  static const String _poiDistanceKey = 'poi_search_distance';
  static const String _poiProvidersEnabledKey = 'poi_providers_enabled';
  static const String _defaultPoiCategoryKey = 'default_poi_category';
  static const String _backgroundLocationEnabledKey = 'background_location_enabled';

  // Secure storage keys for OpenAI API
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _aiRequestCountKey = 'ai_request_count';
  static const String _aiRequestDateKey = 'ai_request_date';
  static const String _openaiModelKey = 'openai_model';
  static const String _aiBatchSizeKey = 'ai_batch_size';
  static const String _useLocalContentKey = 'use_local_content';
  static const String defaultOpenAIModel = 'gpt-4o-mini';
  static const int defaultAIBatchSize = 500;
  static const bool defaultUseLocalContent = false;

  // Secure storage keys for Google Places API
  static const String _googlePlacesApiKeyKey = 'google_places_api_key';
  static const String _googlePlacesRequestCountKey =
      'google_places_request_count';
  static const String _googlePlacesRequestDateKey =
      'google_places_request_date';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Default POI type order (prioritized by user preference)
  static final List<POIType> defaultPoiOrder = [
    // Attractions
    POIType.touristAttraction,
    POIType.museum,
    POIType.historicSite,
    POIType.monument,
    POIType.viewpoint,
    POIType.religiousSite,
    POIType.park,
    POIType.other,
    // Commercial
    POIType.restaurant,
    POIType.cafe,
    POIType.bakery,
    POIType.supermarket,
    POIType.hardwareStore,
    POIType.pharmacy,
    POIType.gasStation,
    POIType.hotel,
    POIType.bar,
    POIType.fastFood,
  ];

  /// Default attraction POI type order
  static final List<POIType> defaultAttractionPoiOrder = [
    POIType.touristAttraction,
    POIType.museum,
    POIType.historicSite,
    POIType.monument,
    POIType.viewpoint,
    POIType.religiousSite,
    POIType.park,
    POIType.other,
  ];

  /// Default commercial POI type order
  static final List<POIType> defaultCommercialPoiOrder = [
    POIType.restaurant,
    POIType.cafe,
    POIType.bakery,
    POIType.supermarket,
    POIType.hardwareStore,
    POIType.pharmacy,
    POIType.gasStation,
    POIType.hotel,
    POIType.bar,
    POIType.fastFood,
  ];

  /// Default POI search distance in meters (5km)
  static const int defaultPoiDistance = 5000;
  static const int minPoiDistance = 1000; // 1km
  static const int maxPoiDistance = 50000; // 50km

  /// Default POI providers (all enabled by default, except those requiring API key)
  static final Map<POISource, bool> defaultPoiProvidersEnabled = {
    POISource.wikipediaGeosearch: true,
    POISource.overpass: true,
    POISource.wikidata: true,
    POISource.googlePlaces: false, // Disabled until API key is configured
  };

  /// Load POI type order with enabled state from persistent storage
  /// Returns list of (POIType, bool) tuples where bool indicates if enabled
  Future<List<(POIType, bool)>> loadPoiOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStrings = prefs.getStringList(_poiOrderKey);

      if (orderStrings == null || orderStrings.isEmpty) {
        // Return default with all types enabled
        return defaultPoiOrder.map((type) => (type, true)).toList();
      }

      // Check if this is old format (just type names) or new format (type=enabled)
      final order = <(POIType, bool)>[];
      final bool isOldFormat = !orderStrings.first.contains('=');

      if (isOldFormat) {
        // Migrate from old format: just type names
        for (final typeString in orderStrings) {
          try {
            final type = POIType.values.firstWhere(
              (t) => t.toString() == typeString,
            );
            // All types enabled by default in migration
            order.add((type, true));
          } catch (e) {
            // Skip invalid types (e.g., if enum changes or removed types)
            continue;
          }
        }
      } else {
        // New format: "type=enabled"
        for (final entry in orderStrings) {
          final parts = entry.split('=');
          if (parts.length == 2) {
            try {
              final type = POIType.values.firstWhere(
                (t) => t.toString() == parts[0],
              );
              final enabled = parts[1] == 'true';
              order.add((type, enabled));
            } catch (e) {
              // Skip invalid entries
              continue;
            }
          }
        }
      }

      // Ensure all POI types are present (in case new types were added)
      for (final type in POIType.values) {
        if (!order.any((entry) => entry.$1 == type)) {
          order.add((type, true)); // New types enabled by default
        }
      }

      return order;
    } catch (e) {
      // Return default order with all enabled on error
      return defaultPoiOrder.map((type) => (type, true)).toList();
    }
  }

  /// Save POI type order with enabled state to persistent storage
  Future<bool> savePoiOrder(List<(POIType, bool)> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStrings =
          order.map((entry) => '${entry.$1.toString()}=${entry.$2}').toList();
      return await prefs.setStringList(_poiOrderKey, orderStrings);
    } catch (e) {
      return false;
    }
  }

  /// Reset POI order to default (all types enabled)
  Future<bool> resetPoiOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_poiOrderKey);
    } catch (e) {
      return false;
    }
  }

  /// Load attraction POI type order with enabled state
  Future<List<(POIType, bool)>> loadAttractionPoiOrder() async {
    return _loadCategoryPoiOrder(
      _attractionPoiOrderKey,
      defaultAttractionPoiOrder,
      POICategory.attraction,
    );
  }

  /// Load commercial POI type order with enabled state
  Future<List<(POIType, bool)>> loadCommercialPoiOrder() async {
    return _loadCategoryPoiOrder(
      _commercialPoiOrderKey,
      defaultCommercialPoiOrder,
      POICategory.commercial,
    );
  }

  /// Generic method to load POI order for a specific category
  Future<List<(POIType, bool)>> _loadCategoryPoiOrder(
    String key,
    List<POIType> defaultOrder,
    POICategory category,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStrings = prefs.getStringList(key);

      if (orderStrings == null || orderStrings.isEmpty) {
        // Return default with all types enabled
        return defaultOrder.map((type) => (type, true)).toList();
      }

      final order = <(POIType, bool)>[];
      for (final entry in orderStrings) {
        final parts = entry.split('=');
        if (parts.length == 2) {
          try {
            final type = POIType.values.firstWhere(
              (t) => t.toString() == parts[0],
            );
            // Only include types from the correct category
            if (type.category == category) {
              final enabled = parts[1] == 'true';
              order.add((type, enabled));
            }
          } catch (e) {
            continue;
          }
        }
      }

      // Ensure all types for this category are present
      for (final type in defaultOrder) {
        if (!order.any((entry) => entry.$1 == type)) {
          order.add((type, true));
        }
      }

      return order;
    } catch (e) {
      return defaultOrder.map((type) => (type, true)).toList();
    }
  }

  /// Save attraction POI type order with enabled state
  Future<bool> saveAttractionPoiOrder(List<(POIType, bool)> order) async {
    return _saveCategoryPoiOrder(_attractionPoiOrderKey, order);
  }

  /// Save commercial POI type order with enabled state
  Future<bool> saveCommercialPoiOrder(List<(POIType, bool)> order) async {
    return _saveCategoryPoiOrder(_commercialPoiOrderKey, order);
  }

  /// Generic method to save POI order for a specific category
  Future<bool> _saveCategoryPoiOrder(
    String key,
    List<(POIType, bool)> order,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStrings =
          order.map((entry) => '${entry.$1.toString()}=${entry.$2}').toList();
      return await prefs.setStringList(key, orderStrings);
    } catch (e) {
      return false;
    }
  }

  /// Reset attraction POI order to default (all types enabled)
  Future<bool> resetAttractionPoiOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_attractionPoiOrderKey);
    } catch (e) {
      return false;
    }
  }

  /// Reset commercial POI order to default (all types enabled)
  Future<bool> resetCommercialPoiOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_commercialPoiOrderKey);
    } catch (e) {
      return false;
    }
  }

  /// Load POI search distance from persistent storage
  Future<int> loadPoiDistance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_poiDistanceKey) ?? defaultPoiDistance;
    } catch (e) {
      return defaultPoiDistance;
    }
  }

  /// Save POI search distance to persistent storage
  Future<bool> savePoiDistance(int distance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_poiDistanceKey, distance);
    } catch (e) {
      return false;
    }
  }

  /// Reset POI distance to default
  Future<bool> resetPoiDistance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_poiDistanceKey);
    } catch (e) {
      return false;
    }
  }

  /// Load default POI category from persistent storage
  Future<POICategory> loadDefaultPoiCategory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoryString = prefs.getString(_defaultPoiCategoryKey);
      if (categoryString == null) {
        return POICategory.attraction; // Default to attractions
      }
      return POICategory.values.firstWhere(
        (c) => c.name == categoryString,
        orElse: () => POICategory.attraction,
      );
    } catch (e) {
      return POICategory.attraction;
    }
  }

  /// Save default POI category to persistent storage
  Future<bool> saveDefaultPoiCategory(POICategory category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_defaultPoiCategoryKey, category.name);
    } catch (e) {
      return false;
    }
  }

  /// Load POI provider enabled state from persistent storage
  Future<Map<POISource, bool>> loadPoiProvidersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabledStrings = prefs.getStringList(_poiProvidersEnabledKey);

      if (enabledStrings == null) {
        return Map.from(defaultPoiProvidersEnabled);
      }

      // Convert strings back to Map<POISource, bool>
      final enabledMap = <POISource, bool>{};
      for (final entry in enabledStrings) {
        final parts = entry.split('=');
        if (parts.length == 2) {
          try {
            final source = POISource.values.firstWhere(
              (s) => s.toString() == parts[0],
            );
            enabledMap[source] = parts[1] == 'true';
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }

      // Ensure all sources have an entry (for new sources added later)
      for (final source in POISource.values) {
        enabledMap[source] ??= true;
      }

      return enabledMap;
    } catch (e) {
      return Map.from(defaultPoiProvidersEnabled);
    }
  }

  /// Save POI provider enabled state to persistent storage
  Future<bool> savePoiProvidersEnabled(Map<POISource, bool> enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabledStrings =
          enabled.entries.map((e) => '${e.key.toString()}=${e.value}').toList();
      return await prefs.setStringList(_poiProvidersEnabledKey, enabledStrings);
    } catch (e) {
      return false;
    }
  }

  /// Reset POI providers to default (all enabled)
  Future<bool> resetPoiProvidersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_poiProvidersEnabledKey);
    } catch (e) {
      return false;
    }
  }

  /// Save OpenAI API key to secure storage
  Future<bool> saveOpenAIApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: _openaiApiKeyKey, value: apiKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load OpenAI API key from secure storage
  Future<String?> loadOpenAIApiKey() async {
    try {
      return await _secureStorage.read(key: _openaiApiKeyKey);
    } catch (e) {
      return null;
    }
  }

  /// Delete OpenAI API key from secure storage
  Future<bool> deleteOpenAIApiKey() async {
    try {
      await _secureStorage.delete(key: _openaiApiKeyKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save AI request count and date to secure storage
  Future<bool> saveAIRequestCount(int count, DateTime date) async {
    try {
      await _secureStorage.write(
          key: _aiRequestCountKey, value: count.toString());
      await _secureStorage.write(
          key: _aiRequestDateKey, value: date.toIso8601String());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load AI request count and date from secure storage
  /// Returns (count, date) tuple, or (0, today) if not found
  Future<(int, DateTime)> loadAIRequestCount() async {
    try {
      final countStr = await _secureStorage.read(key: _aiRequestCountKey);
      final dateStr = await _secureStorage.read(key: _aiRequestDateKey);

      if (countStr == null || dateStr == null) {
        return (0, DateTime.now());
      }

      final count = int.tryParse(countStr) ?? 0;
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      // Reset count if it's a new day
      final now = DateTime.now();
      if (date.year != now.year ||
          date.month != now.month ||
          date.day != now.day) {
        return (0, now);
      }

      return (count, date);
    } catch (e) {
      return (0, DateTime.now());
    }
  }

  /// Save Google Places API key to secure storage
  Future<bool> saveGooglePlacesApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: _googlePlacesApiKeyKey, value: apiKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load Google Places API key from secure storage
  Future<String?> loadGooglePlacesApiKey() async {
    try {
      return await _secureStorage.read(key: _googlePlacesApiKeyKey);
    } catch (e) {
      return null;
    }
  }

  /// Delete Google Places API key from secure storage
  Future<bool> deleteGooglePlacesApiKey() async {
    try {
      await _secureStorage.delete(key: _googlePlacesApiKeyKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save Google Places request count and date
  Future<bool> saveGooglePlacesRequestCount(int count, DateTime date) async {
    try {
      await _secureStorage.write(
          key: _googlePlacesRequestCountKey, value: count.toString());
      await _secureStorage.write(
          key: _googlePlacesRequestDateKey, value: date.toIso8601String());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load Google Places request count and date
  /// Returns (count, date) tuple, or (0, today) if not found
  /// Resets count monthly (Google billing cycle)
  Future<(int, DateTime)> loadGooglePlacesRequestCount() async {
    try {
      final countStr =
          await _secureStorage.read(key: _googlePlacesRequestCountKey);
      final dateStr =
          await _secureStorage.read(key: _googlePlacesRequestDateKey);

      if (countStr == null || dateStr == null) {
        return (0, DateTime.now());
      }

      final count = int.tryParse(countStr) ?? 0;
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      // Reset count if it's a new month (Google billing is monthly)
      final now = DateTime.now();
      if (date.year != now.year || date.month != now.month) {
        return (0, now);
      }

      return (count, date);
    } catch (e) {
      return (0, DateTime.now());
    }
  }

  /// Save OpenAI model selection
  Future<bool> saveOpenAIModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_openaiModelKey, model);
    } catch (e) {
      return false;
    }
  }

  /// Load OpenAI model selection
  Future<String> loadOpenAIModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_openaiModelKey) ?? defaultOpenAIModel;
    } catch (e) {
      return defaultOpenAIModel;
    }
  }

  /// Save AI batch size
  Future<bool> saveAIBatchSize(int batchSize) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_aiBatchSizeKey, batchSize);
    } catch (e) {
      return false;
    }
  }

  /// Load AI batch size
  Future<int> loadAIBatchSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_aiBatchSizeKey) ?? defaultAIBatchSize;
    } catch (e) {
      return defaultAIBatchSize;
    }
  }

  /// Save use local content setting
  Future<bool> saveUseLocalContent(bool useLocal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_useLocalContentKey, useLocal);
    } catch (e) {
      return false;
    }
  }

  /// Load use local content setting
  Future<bool> loadUseLocalContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_useLocalContentKey) ?? defaultUseLocalContent;
    } catch (e) {
      return defaultUseLocalContent;
    }
  }

  /// Save background location enabled setting
  Future<bool> saveBackgroundLocationEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_backgroundLocationEnabledKey, enabled);
    } catch (e) {
      return false;
    }
  }

  /// Load background location enabled setting
  Future<bool> loadBackgroundLocationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_backgroundLocationEnabledKey) ?? true; // Default enabled
    } catch (e) {
      return true;
    }
  }
}

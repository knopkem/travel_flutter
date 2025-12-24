import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';

/// Service for persisting user settings using SharedPreferences
class SettingsService {
  static const String _poiOrderKey = 'poi_type_order';
  static const String _poiDistanceKey = 'poi_search_distance';
  static const String _poiProvidersEnabledKey = 'poi_providers_enabled';

  /// Default POI type order (prioritized by user preference)
  static final List<POIType> defaultPoiOrder = [
    POIType.touristAttraction,
    POIType.museum,
    POIType.historicSite,
    POIType.monument,
    POIType.viewpoint,
    POIType.religiousSite,
    POIType.park,
    POIType.other,
  ];

  /// Default POI search distance in meters (5km)
  static const int defaultPoiDistance = 5000;
  static const int minPoiDistance = 1000; // 1km
  static const int maxPoiDistance = 10000; // 10km

  /// Default POI providers (all enabled by default)
  static final Map<POISource, bool> defaultPoiProvidersEnabled = {
    POISource.wikipediaGeosearch: true,
    POISource.overpass: true,
    POISource.wikidata: true,
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
}

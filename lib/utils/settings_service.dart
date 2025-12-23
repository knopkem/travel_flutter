import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi_type.dart';

/// Service for persisting user settings using SharedPreferences
class SettingsService {
  static const String _poiOrderKey = 'poi_type_order';
  static const String _poiDistanceKey = 'poi_search_distance';

  /// Default POI type order (prioritized by user preference)
  static final List<POIType> defaultPoiOrder = [
    POIType.touristAttraction,
    POIType.museum,
    POIType.historicSite,
    POIType.monument,
    POIType.landmark,
    POIType.viewpoint,
    POIType.religiousSite,
    POIType.park,
    POIType.square,
    POIType.other,
  ];

  /// Default POI search distance in meters (5km)
  static const int defaultPoiDistance = 5000;
  static const int minPoiDistance = 1000; // 1km
  static const int maxPoiDistance = 10000; // 10km

  /// Load POI type order from persistent storage
  Future<List<POIType>> loadPoiOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStrings = prefs.getStringList(_poiOrderKey);

      if (orderStrings == null || orderStrings.isEmpty) {
        return List.from(defaultPoiOrder);
      }

      // Convert strings back to POIType enum values
      final order = <POIType>[];
      for (final typeString in orderStrings) {
        try {
          final type = POIType.values.firstWhere(
            (t) => t.toString() == typeString,
          );
          order.add(type);
        } catch (e) {
          // Skip invalid types (e.g., if enum changes)
          continue;
        }
      }

      // Ensure all POI types are present (in case new types were added)
      for (final type in POIType.values) {
        if (!order.contains(type)) {
          order.add(type);
        }
      }

      return order;
    } catch (e) {
      // Return default order on error
      return List.from(defaultPoiOrder);
    }
  }

  /// Save POI type order to persistent storage
  Future<bool> savePoiOrder(List<POIType> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStrings = order.map((type) => type.toString()).toList();
      return await prefs.setStringList(_poiOrderKey, orderStrings);
    } catch (e) {
      return false;
    }
  }

  /// Reset POI order to default
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
}

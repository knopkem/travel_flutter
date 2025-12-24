import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';

/// Abstract repository interface for fetching Points of Interest (POIs)
abstract class POIRepository {
  /// Fetches nearby POIs within a specified radius of the given city
  ///
  /// Returns a list of POI objects discovered near the city coordinates.
  /// The [radiusMeters] parameter allows customizing the search radius (default: 10km).
  /// The [enabledTypes] parameter allows filtering to only specific POI types.
  ///
  /// Throws an exception if the API call fails or if coordinates are invalid.
  Future<List<POI>> fetchNearbyPOIs(
    Location city, {
    int radiusMeters = 10000,
    Set<POIType>? enabledTypes,
  });
}
import '../models/location.dart';
import '../models/poi.dart';

/// Abstract repository interface for fetching Points of Interest (POIs)
abstract class POIRepository {
  /// Fetches nearby POIs within a specified radius of the given city
  ///
  /// Returns a list of POI objects discovered near the city coordinates.
  /// The [radiusMeters] parameter allows customizing the search radius (default: 10km).
  ///
  /// Throws an exception if the API call fails or if coordinates are invalid.
  Future<List<POI>> fetchNearbyPOIs(
    Location city, {
    int radiusMeters = 10000,
  });
}

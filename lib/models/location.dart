/// Represents a geographic location with coordinates.
///
/// This model is used to store selected locations from the search results.
/// Locations are immutable once created and stored in the user's location list
/// during the app session.
///
/// Coordinates are validated to ensure they fall within valid ranges:
/// - Latitude: -90.0 to 90.0
/// - Longitude: -180.0 to 180.0
///
/// Example:
/// ```dart
/// final location = Location.fromJson({
///   'osm_id': 123456,
///   'display_name': 'Berlin, Germany',
///   'lat': '52.5200',
///   'lon': '13.4050',
///   'address': {
///     'city': 'Berlin',
///     'country': 'Germany'
///   }
/// });
/// ```
class Location {
  /// Unique identifier from OpenStreetMap (osm_id)
  final String id;

  /// City or town name (e.g., "Paris")
  final String name;

  /// Country name (e.g., "France")
  final String country;

  /// Full display name for UI (e.g., "Paris, France")
  final String displayName;

  /// Geographic latitude coordinate (range: -90 to 90)
  final double latitude;

  /// Geographic longitude coordinate (range: -180 to 180)
  final double longitude;

  /// Creates a new [Location] instance.
  ///
  /// All parameters are required and must not be null.
  /// Coordinates must be within valid ranges.
  const Location({
    required this.id,
    required this.name,
    required this.country,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  })  : assert(latitude >= -90 && latitude <= 90,
            'Latitude must be between -90 and 90'),
        assert(longitude >= -180 && longitude <= 180,
            'Longitude must be between -180 and 180');

  /// Creates a [Location] from a Nominatim API JSON response.
  ///
  /// Expected JSON structure:
  /// ```json
  /// {
  ///   "osm_id": 123456,
  ///   "display_name": "Paris, France",
  ///   "lat": "48.8566",
  ///   "lon": "2.3522",
  ///   "address": {
  ///     "city": "Paris",
  ///     "country": "France"
  ///   }
  /// }
  /// ```
  ///
  /// Falls back to parsing display_name if city is not in address object.
  /// Falls back to "Unknown" for missing country.
  factory Location.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    final displayName = json['display_name'] as String;

    // Extract city name: try city, town, or first part of display_name
    String name;
    if (address != null && address['city'] != null) {
      name = address['city'] as String;
    } else if (address != null && address['town'] != null) {
      name = address['town'] as String;
    } else {
      name = displayName.split(',')[0].trim();
    }

    // Extract country name with fallback
    final country = address?['country'] as String? ?? 'Unknown';

    final lat = double.parse(json['lat'] as String);
    final lon = double.parse(json['lon'] as String);

    return Location(
      id: json['osm_id'].toString(),
      name: name.trim(),
      country: country.trim(),
      displayName: displayName,
      latitude: lat,
      longitude: lon,
    );
  }

  @override
  String toString() =>
      'Location(id: $id, displayName: $displayName, lat: $latitude, lon: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

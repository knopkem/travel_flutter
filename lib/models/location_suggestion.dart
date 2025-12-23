import 'location.dart';

/// Represents a temporary search result from the geocoding API.
///
/// This lightweight model is used to display autocomplete suggestions in the
/// search dropdown. When a user selects a suggestion, it is converted to a
/// [Location] and added to the saved locations list.
///
/// Suggestions are discarded when:
/// - The search query changes
/// - A location is selected
/// - The suggestion list is cleared
///
/// Example:
/// ```dart
/// final suggestion = LocationSuggestion.fromJson({
///   'osm_id': 123456,
///   'display_name': 'Paris, France',
///   'lat': '48.8566',
///   'lon': '2.3522',
///   'address': {
///     'city': 'Paris',
///     'country': 'France'
///   }
/// });
///
/// // Convert to Location when user selects
/// final location = suggestion.toLocation();
/// ```
class LocationSuggestion {
  /// Unique identifier from OpenStreetMap (osm_id)
  final String id;

  /// City or town name (e.g., "Paris")
  final String name;

  /// Country name (e.g., "France")
  final String country;

  /// Full display name for suggestion list (e.g., "Paris, France")
  final String displayName;

  /// Geographic latitude coordinate (range: -90 to 90)
  final double latitude;

  /// Geographic longitude coordinate (range: -180 to 180)
  final double longitude;

  /// Creates a new [LocationSuggestion] instance.
  ///
  /// All parameters are required and must not be null.
  /// Coordinates must be within valid ranges.
  const LocationSuggestion({
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

  /// Creates a [LocationSuggestion] from a Nominatim API JSON response.
  ///
  /// Expected JSON structure matches the Nominatim search endpoint response.
  /// Falls back to parsing display_name if city is not in address object.
  /// Falls back to "Unknown" for missing country.
  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
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

    return LocationSuggestion(
      id: json['osm_id'].toString(),
      name: name.trim(),
      country: country.trim(),
      displayName: displayName,
      latitude: lat,
      longitude: lon,
    );
  }

  /// Converts this suggestion to a [Location] entity.
  ///
  /// Used when the user selects a suggestion from the autocomplete list.
  /// The resulting [Location] is added to the saved locations.
  Location toLocation() {
    return Location(
      id: id,
      name: name,
      country: country,
      displayName: displayName,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  String toString() => 'LocationSuggestion(id: $id, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSuggestion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

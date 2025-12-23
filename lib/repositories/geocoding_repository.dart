import '../models/models.dart';

/// Repository interface for geocoding operations (location search).
///
/// Implementations of this interface provide location search functionality
/// using geocoding services. Results are returned as [LocationSuggestion]
/// objects that can be displayed in an autocomplete dropdown.
///
/// Example usage:
/// ```dart
/// final repository = NominatimGeocodingRepository();
/// try {
///   final suggestions = await repository.searchLocations('Berlin');
///   for (final suggestion in suggestions) {
///     print(suggestion.displayName);
///   }
/// } catch (e) {
///   print('Search failed: $e');
/// } finally {
///   repository.dispose();
/// }
/// ```
abstract class GeocodingRepository {
  /// Searches for locations matching the given [query].
  ///
  /// Returns a list of [LocationSuggestion] objects representing places
  /// that match the search query. The list may be empty if no matches found.
  ///
  /// The [query] parameter is the user's search text (e.g., "Paris", "Berlin").
  ///
  /// Throws an [Exception] if:
  /// - Network request fails
  /// - API returns an error status code
  /// - Response cannot be parsed
  ///
  /// Example:
  /// ```dart
  /// final results = await repository.searchLocations('London');
  /// print('Found ${results.length} locations');
  /// ```
  Future<List<LocationSuggestion>> searchLocations(String query);

  /// Reverse geocodes coordinates to a location name.
  ///
  /// Returns a [LocationSuggestion] representing the place at the given
  /// coordinates, or null if the operation fails (network error, timeout, etc.).
  ///
  /// The [latitude] parameter must be between -90 and 90.
  /// The [longitude] parameter must be between -180 and 180.
  ///
  /// Returns null on failure to allow graceful fallback to coordinate-only mode.
  ///
  /// Example:
  /// ```dart
  /// final location = await repository.reverseGeocode(48.8566, 2.3522);
  /// if (location != null) {
  ///   print('Found: ${location.displayName}');
  /// } else {
  ///   print('Could not resolve location name');
  /// }
  /// ```
  Future<LocationSuggestion?> reverseGeocode(double latitude, double longitude);

  /// Releases resources used by this repository.
  ///
  /// Call this method when the repository is no longer needed to close
  /// HTTP connections and free resources.
  void dispose();
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'geocoding_repository.dart';

/// Implementation of [GeocodingRepository] using Google Places Autocomplete API.
///
/// This repository provides higher-quality location search results compared to
/// free alternatives, including:
/// - More accurate place matching
/// - Better international coverage
/// - Structured address components
/// - Place details like types and importance
///
/// Requires a valid Google Places API key. Falls back to Nominatim when
/// no API key is provided.
///
/// Usage:
/// ```dart
/// final repository = GooglePlacesAutocompleteRepository(apiKey: 'YOUR_KEY');
/// try {
///   final suggestions = await repository.searchLocations('Paris');
///   print('Found ${suggestions.length} suggestions');
/// } catch (e) {
///   print('Error: $e');
/// } finally {
///   repository.dispose();
/// }
/// ```
class GooglePlacesAutocompleteRepository implements GeocodingRepository {
  final http.Client _client;
  final String? _apiKey;
  final void Function()? onRequestMade;
  // New Places API (v1) endpoints
  static const String _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const String _placeDetailsUrl =
      'https://places.googleapis.com/v1/places';
  static const String _geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const Duration _timeout = Duration(seconds: 10);

  /// Creates a new Google Places Autocomplete repository.
  ///
  /// [apiKey] is optional. If not provided, this repository will not function
  /// and should not be used (use Nominatim instead).
  /// [onRequestMade] is an optional callback invoked when API requests are made.
  GooglePlacesAutocompleteRepository({
    http.Client? client,
    String? apiKey,
    this.onRequestMade,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey;

  /// Returns a new instance with the specified API key
  GooglePlacesAutocompleteRepository withApiKey(String apiKey) {
    return GooglePlacesAutocompleteRepository(
      client: _client,
      apiKey: apiKey,
      onRequestMade: onRequestMade,
    );
  }

  @override
  Future<List<LocationSuggestion>> searchLocations(String query) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Places API key is required');
    }

    if (query.isEmpty) {
      return [];
    }

    try {
      // Track API request
      onRequestMade?.call();
      
      // Use new Places API (v1) with JSON body and header authentication
      final autocompleteResponse = await _client
          .post(
            Uri.parse(_autocompleteUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey!,
            },
            body: json.encode({
              'input': query,
              'includedPrimaryTypes': [
                'locality',
                'administrative_area_level_1'
              ],
              'languageCode': 'en',
            }),
          )
          .timeout(_timeout);

      if (autocompleteResponse.statusCode != 200) {
        throw Exception(
            'Google Places Autocomplete API failed with status ${autocompleteResponse.statusCode}');
      }

      final autocompleteData =
          json.decode(autocompleteResponse.body) as Map<String, dynamic>;

      final suggestions =
          autocompleteData['suggestions'] as List<dynamic>? ?? [];

      // Fetch details for each suggestion to get coordinates
      final results = <LocationSuggestion>[];
      for (final suggestion in suggestions.take(10)) {
        final placePrediction =
            suggestion['placePrediction'] as Map<String, dynamic>?;
        if (placePrediction != null) {
          final placeId = placePrediction['placeId'] as String?;
          if (placeId != null) {
            final locationSuggestion = await _fetchPlaceDetails(placeId);
            if (locationSuggestion != null) {
              results.add(locationSuggestion);
            }
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('Google Places Autocomplete error: $e');
      rethrow;
    }
  }

  /// Fetches detailed information for a place including coordinates
  Future<LocationSuggestion?> _fetchPlaceDetails(String placeId) async {
    try {
      // Track API request
      onRequestMade?.call();

      // Use new Places API (v1) with field mask
      final detailsUri = Uri.parse('$_placeDetailsUrl/$placeId');

      final response = await _client.get(
        detailsUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey!,
          'X-Goog-FieldMask':
              'id,displayName,formattedAddress,location,addressComponents',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
            'Place details failed: ${response.statusCode} - ${response.body}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) {
        return null;
      }

      final addressComponents =
          data['addressComponents'] as List<dynamic>? ?? [];

      // Extract country and city from address components
      String? country;
      String? city;
      for (final component in addressComponents) {
        final types = component['types'] as List<dynamic>? ?? [];
        if (types.contains('country')) {
          country = component['longText'] as String?;
        }
        if (types.contains('locality')) {
          city = component['longText'] as String?;
        }
      }

      final displayName = data['displayName'] as Map<String, dynamic>?;
      final formattedAddress = data['formattedAddress'] as String? ??
          displayName?['text'] as String? ??
          'Unknown Location';
      final cityName =
          city ?? displayName?['text'] as String? ?? 'Unknown City';

      return LocationSuggestion(
        id: placeId,
        name: cityName,
        country: country ?? 'Unknown',
        displayName: formattedAddress,
        latitude: (location['latitude'] as num).toDouble(),
        longitude: (location['longitude'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('Error fetching place details for $placeId: $e');
      return null;
    }
  }

  @override
  Future<LocationSuggestion?> reverseGeocode(
      double latitude, double longitude) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Places API key is required');
    }

    try {
      // Track API request
      onRequestMade?.call();

      final uri = Uri.parse(_geocodeUrl).replace(
        queryParameters: {
          'latlng': '$latitude,$longitude',
          'result_type': 'locality|administrative_area_level_1',
          'key': _apiKey!,
        },
      );

      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Google Geocoding API error: HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
        debugPrint('Google Geocoding API status: $status');
        return null;
      }

      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        return null;
      }

      final result = results[0] as Map<String, dynamic>;
      final addressComponents =
          result['address_components'] as List<dynamic>? ?? [];

      // Extract country and city from address components
      String? country;
      String? city;
      for (final component in addressComponents) {
        final types = component['types'] as List<dynamic>;
        if (types.contains('country')) {
          country = component['long_name'] as String;
        }
        if (types.contains('locality')) {
          city = component['long_name'] as String;
        }
      }

      final formattedAddress = result['formatted_address'] as String;
      final cityName = city ?? formattedAddress.split(',').first;

      return LocationSuggestion(
        id: 'gps_${latitude}_$longitude',
        name: cityName,
        country: country ?? 'Unknown',
        displayName: formattedAddress,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      debugPrint('Google reverse geocode error: $e');
      return null; // Graceful fallback
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}

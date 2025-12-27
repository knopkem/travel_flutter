import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';
import 'poi_repository.dart';

/// Google Places API repository implementation
///
/// Fetches POIs from Google Places Nearby Search API.
/// Requires a valid Google Places API key.
class GooglePlacesRepository implements POIRepository {
  final http.Client _client;
  final String? _apiKey;
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const Duration _timeout = Duration(seconds: 15);

  GooglePlacesRepository({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey;

  /// Update the API key
  GooglePlacesRepository withApiKey(String apiKey) {
    return GooglePlacesRepository(client: _client, apiKey: apiKey);
  }

  @override
  Future<List<POI>> fetchNearbyPOIs(
    Location city, {
    int radiusMeters = 10000,
    Set<POIType>? enabledTypes,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Places API key is required');
    }

    // Return empty list if no types enabled
    if (enabledTypes != null && enabledTypes.isEmpty) {
      return [];
    }

    // Validate coordinates
    if (city.latitude < -90 || city.latitude > 90) {
      throw ArgumentError('Invalid latitude: ${city.latitude}');
    }
    if (city.longitude < -180 || city.longitude > 180) {
      throw ArgumentError('Invalid longitude: ${city.longitude}');
    }

    // Google Places API has a max radius of 50km
    final clampedRadius = radiusMeters.clamp(1, 50000);

    try {
      final allPOIs = <POI>[];

      // Fetch POIs for each relevant Google place type
      final placeTypes = _getGooglePlaceTypes(enabledTypes);

      for (final placeType in placeTypes) {
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          'location': '${city.latitude},${city.longitude}',
          'radius': clampedRadius.toString(),
          'type': placeType,
          'key': _apiKey!,
        });

        final response = await _client.get(uri).timeout(_timeout);

        if (response.statusCode != 200) {
          throw Exception(
              'Google Places API failed with status ${response.statusCode}');
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;

        if (status == 'REQUEST_DENIED') {
          throw Exception(
              'Google Places API key is invalid or has insufficient permissions');
        }

        if (status == 'OVER_QUERY_LIMIT') {
          throw Exception('Google Places API quota exceeded');
        }

        if (status != 'OK' && status != 'ZERO_RESULTS') {
          throw Exception('Google Places API error: $status');
        }

        final results = data['results'] as List<dynamic>? ?? [];

        for (final result in results) {
          try {
            final poi = POI.fromGooglePlaces(
              result as Map<String, dynamic>,
              city,
              apiKey: _apiKey,
            );
            // Filter by enabled types if specified
            if (enabledTypes == null || enabledTypes.contains(poi.type)) {
              allPOIs.add(poi);
            }
          } catch (e) {
            // Skip invalid POIs
            continue;
          }
        }
      }

      return allPOIs;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Google Places API request timed out');
      }
      rethrow;
    }
  }

  /// Validate a Google Places API key
  /// Note: Due to CORS restrictions, we can't make actual API calls from web browsers.
  /// This validation checks the key format instead.
  static Future<bool> validateApiKey(String apiKey,
      {http.Client? client}) async {
    if (apiKey.isEmpty) return false;

    // Google API keys start with "AIza" and are typically 39 characters long
    // This is a basic format check to catch obvious errors
    if (!apiKey.startsWith('AIza')) return false;
    if (apiKey.length < 30 || apiKey.length > 50) return false;

    // Check for valid characters (alphanumeric, hyphens, underscores)
    final validChars = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!validChars.hasMatch(apiKey)) return false;

    // Format looks valid - actual validation will happen when making real requests
    return true;
  }

  /// Map POITypes to Google Places API types
  List<String> _getGooglePlaceTypes(Set<POIType>? enabledTypes) {
    final types = <String>[];

    // If no filter, use a broad set of tourist-relevant types
    final typesToCheck = enabledTypes ?? POIType.values.toSet();

    for (final poiType in typesToCheck) {
      switch (poiType) {
        case POIType.museum:
          types.add('museum');
          break;
        case POIType.monument:
        case POIType.historicSite:
          types.add('tourist_attraction');
          break;
        case POIType.park:
          types.add('park');
          break;
        case POIType.religiousSite:
          types.add('church');
          types.add('mosque');
          types.add('synagogue');
          types.add('hindu_temple');
          break;
        case POIType.viewpoint:
          types.add('tourist_attraction');
          break;
        case POIType.touristAttraction:
          types.add('tourist_attraction');
          break;
        case POIType.other:
          types.add('point_of_interest');
          break;
      }
    }

    // Remove duplicates and limit to avoid too many requests
    return types.toSet().take(5).toList();
  }

  /// Fetch detailed information for a specific place by place_id
  ///
  /// Returns a map with additional details including:
  /// - rating: double (average rating 1-5)
  /// - userRatingsTotal: int (number of reviews)
  /// - reviews: List of review objects
  /// - formattedAddress: String (full address)
  /// - formattedPhoneNumber: String (phone number)
  /// - priceLevel: int (0-4, where 0 is free and 4 is expensive)
  /// - openingHours: Map with current open status and periods
  Future<Map<String, dynamic>?> fetchPlaceDetails(String placeId) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Places API key is required');
    }

    try {
      final uri = Uri.parse(_detailsUrl).replace(queryParameters: {
        'place_id': placeId,
        'fields':
            'rating,user_ratings_total,reviews,formatted_address,formatted_phone_number,price_level,opening_hours,website',
        'key': _apiKey!,
      });

      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception(
            'Google Places Details API failed with status ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'REQUEST_DENIED') {
        throw Exception(
            'Google Places API key is invalid or has insufficient permissions');
      }

      if (status == 'OK' && data['result'] != null) {
        return data['result'] as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }
}

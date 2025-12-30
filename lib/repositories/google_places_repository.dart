import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  final void Function()? onRequestMade;
  String _languageCode = 'en';
  // New Places API (v1) endpoints
  static const String _searchUrl =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const String _detailsUrl = 'https://places.googleapis.com/v1/places';
  static const Duration _timeout = Duration(seconds: 15);

  GooglePlacesRepository({http.Client? client, String? apiKey, this.onRequestMade, String? languageCode})
      : _client = client ?? http.Client(),
        _apiKey = apiKey,
        _languageCode = languageCode ?? 'en';

  /// Update the API key
  GooglePlacesRepository withApiKey(String apiKey) {
    return GooglePlacesRepository(client: _client, apiKey: apiKey, onRequestMade: onRequestMade, languageCode: _languageCode);
  }

  /// Set the language code for API responses
  void setLanguageCode(String languageCode) {
    _languageCode = languageCode;
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
      final seenIds = <String>{}; // Track seen place IDs to avoid duplicates

      // Fetch POIs for each type group
      final typeGroups = _getNewApiPlaceTypeGroups(enabledTypes);

      for (final typeGroup in typeGroups) {
        // Track API request
        onRequestMade?.call();

        // Use new Places API (v1) with POST and JSON body
        final response = await _client
            .post(
              Uri.parse(_searchUrl),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': _apiKey!,
                'X-Goog-FieldMask':
                    'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.userRatingCount,places.priceLevel,places.currentOpeningHours,places.photos,places.editorialSummary',
              },
              body: json.encode({
                'locationRestriction': {
                  'circle': {
                    'center': {
                      'latitude': city.latitude,
                      'longitude': city.longitude,
                    },
                    'radius': clampedRadius.toDouble(),
                  },
                },
                'includedTypes': typeGroup,
                'maxResultCount': 20,
                'rankPreference': 'DISTANCE',
                'languageCode': _languageCode,
              }),
            )
            .timeout(_timeout);

        if (response.statusCode != 200) {
          // Log but continue with other type groups
          debugPrint('Google Places API failed for types $typeGroup: ${response.statusCode}');
          continue;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>? ?? [];

        for (final place in places) {
          try {
            final placeMap = place as Map<String, dynamic>;
            final placeId = placeMap['id'] as String?;
            
            // Skip duplicates
            if (placeId != null && seenIds.contains(placeId)) {
              continue;
            }
            if (placeId != null) {
              seenIds.add(placeId);
            }
            
            final poi = POI.fromGooglePlaces(
              placeMap,
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

  /// Map POITypes to new Google Places API (v1) types
  /// Returns a list of type groups - each group will be queried separately
  /// to maximize results within API limits
  List<List<String>> _getNewApiPlaceTypeGroups(Set<POIType>? enabledTypes) {
    final typeGroups = <List<String>>[];

    // If no filter, use a broad set of tourist-relevant types
    final typesToCheck = enabledTypes ?? POIType.values.toSet();

    for (final poiType in typesToCheck) {
      switch (poiType) {
        case POIType.museum:
          typeGroups.add(['museum']);
          break;
        case POIType.monument:
        case POIType.historicSite:
          typeGroups.add(['tourist_attraction', 'historical_landmark']);
          break;
        case POIType.park:
          typeGroups.add(['park', 'national_park']);
          break;
        case POIType.religiousSite:
          typeGroups.add(['church', 'mosque', 'synagogue', 'hindu_temple']);
          break;
        case POIType.viewpoint:
          // Already covered by tourist_attraction
          break;
        case POIType.touristAttraction:
          typeGroups.add(['tourist_attraction']);
          break;
        case POIType.restaurant:
          // Split into multiple queries to get more results
          typeGroups.add(['restaurant']);
          typeGroups.add(['italian_restaurant', 'chinese_restaurant', 'japanese_restaurant']);
          typeGroups.add(['mexican_restaurant', 'indian_restaurant', 'thai_restaurant']);
          typeGroups.add(['american_restaurant', 'french_restaurant', 'greek_restaurant']);
          typeGroups.add(['seafood_restaurant', 'steak_house', 'pizza_restaurant']);
          break;
        case POIType.fastFood:
          typeGroups.add(['fast_food_restaurant', 'hamburger_restaurant', 'sandwich_shop']);
          typeGroups.add(['meal_takeaway']);
          break;
        case POIType.cafe:
          typeGroups.add(['cafe', 'coffee_shop']);
          break;
        case POIType.bakery:
          typeGroups.add(['bakery']);
          break;
        case POIType.supermarket:
          typeGroups.add(['supermarket', 'grocery_store']);
          break;
        case POIType.hardwareStore:
          typeGroups.add(['hardware_store', 'home_goods_store', 'home_improvement_store']);
          break;
        case POIType.pharmacy:
          typeGroups.add(['pharmacy', 'drugstore']);
          break;
        case POIType.gasStation:
          typeGroups.add(['gas_station']);
          break;
        case POIType.hotel:
          typeGroups.add(['hotel', 'lodging']);
          typeGroups.add(['motel', 'bed_and_breakfast', 'resort_hotel']);
          break;
        case POIType.bar:
          typeGroups.add(['bar', 'night_club', 'pub']);
          break;
        case POIType.other:
          // Skip 'other' type
          break;
      }
    }

    return typeGroups;
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
      // Track API request
      onRequestMade?.call();

      // Use new Places API (v1) with field mask
      final uri = Uri.parse('$_detailsUrl/$placeId');

      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey!,
          'X-Goog-FieldMask':
              'id,displayName,formattedAddress,internationalPhoneNumber,rating,userRatingCount,priceLevel,currentOpeningHours,websiteUri,editorialSummary',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception(
            'Google Places Details API failed with status ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Extract editorial summary text
      String? editorialSummary;
      final summary = data['editorialSummary'] as Map<String, dynamic>?;
      if (summary != null && summary['text'] != null) {
        editorialSummary = summary['text'] as String;
      }

      // Convert new API format to match expected format
      return {
        'rating': data['rating'],
        'user_ratings_total': data['userRatingCount'],
        'formatted_address': data['formattedAddress'],
        'formatted_phone_number': data['internationalPhoneNumber'],
        'price_level': data['priceLevel'],
        'opening_hours': data['currentOpeningHours'],
        'website': data['websiteUri'],
        'editorial_summary': editorialSummary,
      };
    } catch (e) {
      rethrow;
    }
  }
}

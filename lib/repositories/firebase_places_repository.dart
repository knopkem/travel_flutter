import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';
import 'google_places_repository.dart';
import '../services/firebase_service.dart';

/// Firebase Cloud Functions-based POI repository
/// Extends GooglePlacesRepository to provide Firebase integration with fallback
class FirebasePlacesRepository extends GooglePlacesRepository {
  final FirebaseFunctions _functions;
  bool _quotaExceeded = false;

  FirebasePlacesRepository({
    FirebaseFunctions? functions,
    http.Client? client,
    String? apiKey,
    void Function()? onRequestMade,
    String? languageCode,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        super(
          client: client,
          apiKey: apiKey,
          onRequestMade: onRequestMade,
          languageCode: languageCode,
        );

  @override
  Future<List<POI>> fetchNearbyPOIs(
    Location city, {
    int radiusMeters = 10000,
    Set<POIType>? enabledTypes,
  }) async {
    // Check if Firebase is available
    if (!FirebaseService.isInitialized || !FirebaseService.isAuthenticated) {
      debugPrint(
          '⚠ FirebasePlaces: Firebase not initialized, using fallback');
      return super.fetchNearbyPOIs(
        city,
        radiusMeters: radiusMeters,
        enabledTypes: enabledTypes,
      );
    }

    // If quota already exceeded this session, use fallback immediately
    if (_quotaExceeded) {
      debugPrint('⚠ FirebasePlaces: Quota exceeded, using fallback');
      return super.fetchNearbyPOIs(
        city,
        radiusMeters: radiusMeters,
        enabledTypes: enabledTypes,
      );
    }

    try {
      debugPrint(
        'FirebasePlaces: Searching places at (${city.latitude}, ${city.longitude}), radius: $radiusMeters',
      );

      final callable = _functions.httpsCallable('searchPlaces');
      final result = await callable.call({
        'latitude': city.latitude,
        'longitude': city.longitude,
        'radius': radiusMeters,
        'types': enabledTypes?.map((t) => t.name).toList(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Cloud function timeout');
        },
      );

      // Check if quota exceeded
      if (result.data['quotaExceeded'] == true) {
        debugPrint('⚠ FirebasePlaces: Monthly quota exceeded');
        _quotaExceeded = true;
        return super.fetchNearbyPOIs(
          city,
          radiusMeters: radiusMeters,
          enabledTypes: enabledTypes,
        );
      }

      if (result.data['success'] != true) {
        debugPrint('⚠ FirebasePlaces: API returned error, using fallback');
        return super.fetchNearbyPOIs(
          city,
          radiusMeters: radiusMeters,
          enabledTypes: enabledTypes,
        );
      }

      final places = (result.data['places'] as List?)
              ?.map((p) => _parseGooglePlace(p))
              .whereType<POI>()
              .toList() ??
          [];

      debugPrint('✓ FirebasePlaces: Found ${places.length} places');
      return places;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          '✗ FirebasePlaces: Cloud Function error: ${e.code} - ${e.message}');

      if (e.code == 'resource-exhausted') {
        _quotaExceeded = true;
      }

      return super.fetchNearbyPOIs(
        city,
        radiusMeters: radiusMeters,
        enabledTypes: enabledTypes,
      );
    } catch (e) {
      debugPrint('✗ FirebasePlaces: Search failed: $e');
      return super.fetchNearbyPOIs(
        city,
        radiusMeters: radiusMeters,
        enabledTypes: enabledTypes,
      );
    }
  }

  /// Parse Google Places API response to POI model
  POI? _parseGooglePlace(Map<String, dynamic> json) {
    try {
      final location = json['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      final lat = location['latitude'] as num?;
      final lng = location['longitude'] as num?;
      if (lat == null || lng == null) return null;

      return POI(
        id: json['id'] as String? ?? '',
        name: json['displayName']?['text'] as String? ??
            json['name'] as String? ??
            'Unknown',
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        type: _parsePOIType(json['types'] as List?),
        distanceFromCity: 0.0, // Will be calculated by POIProvider
        sources: [POISource.googlePlaces],
        notabilityScore: 5, // Default score for Google Places
        discoveredAt: DateTime.now(),
        placeId: json['id'] as String?,
        formattedAddress: json['formattedAddress'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        userRatingsTotal: json['userRatingCount'] as int?,
        priceLevel: json['priceLevel'] as int?,
        formattedPhoneNumber: json['internationalPhoneNumber'] as String?,
        website: json['websiteUri'] as String?,
      );
    } catch (e) {
      debugPrint('✗ FirebasePlaces: Failed to parse place: $e');
      return null;
    }
  }

  /// Parse POI type from Google Places types
  POIType _parsePOIType(List? types) {
    if (types == null || types.isEmpty) return POIType.other;

    final typeStr = types.first.toString().toLowerCase();

    // Map Google Places types to our POIType enum
    if (typeStr.contains('restaurant') || typeStr.contains('food')) {
      return POIType.restaurant;
    } else if (typeStr.contains('museum')) {
      return POIType.museum;
    } else if (typeStr.contains('park')) {
      return POIType.park;
    } else if (typeStr.contains('hotel') || typeStr.contains('lodging')) {
      return POIType.hotel;
    } else if (typeStr.contains('store')) {
      return POIType.other;
    } else if (typeStr.contains('cafe') || typeStr.contains('coffee')) {
      return POIType.cafe;
    } else if (typeStr.contains('bar') || typeStr.contains('night_club')) {
      return POIType.bar;
    } else if (typeStr.contains('tourist') ||
        typeStr.contains('point_of_interest')) {
      return POIType.touristAttraction;
    }

    return POIType.other;
  }

  @override
  FirebasePlacesRepository withApiKey(String apiKey) {
    return FirebasePlacesRepository(
      functions: _functions,
      apiKey: apiKey,
      onRequestMade: super.onRequestMade,
    );
  }

  /// Reset quota exceeded flag (for new billing period)
  void resetQuota() {
    _quotaExceeded = false;
  }
}

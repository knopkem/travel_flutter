import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import 'poi_repository.dart';

/// Wikipedia Geosearch API repository implementation
///
/// Fetches nearby POIs using Wikipedia's Geosearch API which returns
/// articles with geographic coordinates within a specified radius.
class WikipediaGeosearchRepository implements POIRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://en.wikipedia.org/w/api.php';
  static const int _searchRadiusMeters = 10000; // 10km
  static const int _resultLimit = 50;
  static const Duration _timeout = Duration(seconds: 15);

  WikipediaGeosearchRepository({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<POI>> fetchNearbyPOIs(Location city) async {
    // Validate coordinates
    if (city.latitude < -90 || city.latitude > 90) {
      throw ArgumentError('Invalid latitude: ${city.latitude}');
    }
    if (city.longitude < -180 || city.longitude > 180) {
      throw ArgumentError('Invalid longitude: ${city.longitude}');
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'query',
      'list': 'geosearch',
      'gscoord': '${city.latitude}|${city.longitude}',
      'gsradius': _searchRadiusMeters.toString(),
      'gslimit': _resultLimit.toString(),
      'gsnamespace': '0', // Main articles only
      'format': 'json',
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception(
            'Wikipedia Geosearch API failed with status ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Check for API errors
      if (data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>;
        throw Exception(
            'Wikipedia API error: ${error['info'] ?? error['code']}');
      }

      final query = data['query'] as Map<String, dynamic>?;
      if (query == null) {
        return []; // No results
      }

      final geosearch = query['geosearch'] as List<dynamic>?;
      if (geosearch == null || geosearch.isEmpty) {
        return []; // No POIs found
      }

      // Parse results into POI objects
      final pois = <POI>[];
      for (final item in geosearch) {
        try {
          final poi = POI.fromWikipediaGeosearch(
            item as Map<String, dynamic>,
            city,
          );
          pois.add(poi);
        } catch (e) {
          // Skip invalid items but continue processing others
          debugPrint('Warning: Failed to parse Wikipedia Geosearch item: $e');
        }
      }

      return pois;
    } on http.ClientException catch (e) {
      throw Exception('Network error fetching Wikipedia Geosearch: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON response from Wikipedia Geosearch: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
            'Wikipedia Geosearch request timed out after 15 seconds');
      }
      rethrow;
    }
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}

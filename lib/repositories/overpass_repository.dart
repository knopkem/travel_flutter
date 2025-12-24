import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import 'poi_repository.dart';

/// OpenStreetMap Overpass API repository implementation
///
/// Fetches POIs from OpenStreetMap data using the Overpass API.
/// Enforces 1 request/second rate limiting to comply with API usage policy.
class OverpassRepository implements POIRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _minRequestInterval = Duration(seconds: 1);

  DateTime? _lastRequestTime;

  OverpassRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<POI>> fetchNearbyPOIs(
    Location city, {
    int radiusMeters = 10000,
  }) async {
    // Validate coordinates
    if (city.latitude < -90 || city.latitude > 90) {
      throw ArgumentError('Invalid latitude: ${city.latitude}');
    }
    if (city.longitude < -180 || city.longitude > 180) {
      throw ArgumentError('Invalid longitude: ${city.longitude}');
    }

    // Enforce rate limiting
    await _enforceRateLimit();

    final query = _buildOverpassQuery(
      city.latitude,
      city.longitude,
      radiusMeters,
    );

    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'TravelFlutterApp/1.0 (Flutter)',
            },
            body: 'data=$query',
          )
          .timeout(_timeout);

      if (response.statusCode == 429) {
        throw Exception(
            'Overpass API rate limit exceeded. Please wait before retrying.');
      }

      if (response.statusCode == 400) {
        throw Exception('Invalid Overpass query: ${response.body}');
      }

      if (response.statusCode == 504) {
        throw Exception(
            'Overpass API timeout. Try reducing search radius or simplifying query.');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Overpass API failed with status ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Check for API error in response
      if (data.containsKey('remark') &&
          data['remark'].toString().contains('error')) {
        throw Exception('Overpass API error: ${data['remark']}');
      }

      final elements = data['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) {
        return []; // No POIs found
      }

      // Parse results into POI objects
      final pois = <POI>[];
      for (final element in elements) {
        try {
          if (element['type'] == 'node') {
            final poi = POI.fromOverpass(
              element as Map<String, dynamic>,
              city,
            );
            // Filter out POIs with no proper name
            if (poi.name.isNotEmpty &&
                poi.name != 'Unnamed Location' &&
                !poi.name.toLowerCase().contains('unnamed')) {
              pois.add(poi);
            }
          }
        } catch (e) {
          // Skip invalid items but continue processing others
          // Silently continue to avoid production logging
        }
      }

      return pois;
    } on http.ClientException catch (e) {
      throw Exception('Network error fetching Overpass data: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON response from Overpass API: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Overpass API request timed out after 25 seconds');
      }
      rethrow;
    }
  }

  /// Enforce 1 request per second rate limit
  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        final delay = _minRequestInterval - elapsed;
        await Future.delayed(delay);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Build Overpass QL query for POI discovery
  String _buildOverpassQuery(double lat, double lon, int radius) {
    // URL encode the query for form data submission
    final query = '''
[out:json][timeout:25];
(
  node["tourism"~"^(attraction|museum|monument|artwork|viewpoint|gallery|zoo|aquarium|theme_park)\$"]
    (around:$radius,$lat,$lon);
  node["historic"~"^(monument|memorial|archaeological_site|castle|ruins|fort|manor|palace)\$"]
    (around:$radius,$lat,$lon);
  node["amenity"~"^(theatre|cinema|arts_centre|library|community_centre)\$"]
    (around:$radius,$lat,$lon);
);
out body;
>;
out skel qt;
''';
    return Uri.encodeComponent(query.trim());
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}

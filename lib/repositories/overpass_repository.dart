import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';
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
    Set<POIType>? enabledTypes,
  }) async {
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

    // Enforce rate limiting
    await _enforceRateLimit();

    final query = _buildOverpassQuery(
      city.latitude,
      city.longitude,
      radiusMeters,
      enabledTypes,
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

  /// Build Overpass QL query for POI discovery based on enabled types
  String _buildOverpassQuery(
      double lat, double lon, int radius, Set<POIType>? enabledTypes) {
    // If no filter provided, include all types
    final types = enabledTypes ?? POIType.values.toSet();

    final queryParts = <String>[];

    // Monument: historic=monument|memorial
    if (types.contains(POIType.monument)) {
      queryParts.add(
          '  node["historic"~"^(monument|memorial)\$"](around:$radius,$lat,$lon);');
    }

    // Museum: tourism=museum|gallery
    if (types.contains(POIType.museum)) {
      queryParts.add(
          '  node["tourism"~"^(museum|gallery)\$"](around:$radius,$lat,$lon);');
    }

    // Viewpoint: tourism=viewpoint
    if (types.contains(POIType.viewpoint)) {
      queryParts
          .add('  node["tourism"="viewpoint"](around:$radius,$lat,$lon);');
    }

    // Park: leisure=park
    if (types.contains(POIType.park)) {
      queryParts.add('  node["leisure"="park"](around:$radius,$lat,$lon);');
    }

    // Religious Site: amenity=place_of_worship
    if (types.contains(POIType.religiousSite)) {
      queryParts.add(
          '  node["amenity"="place_of_worship"](around:$radius,$lat,$lon);');
    }

    // Historic Site: historic=castle|ruins|archaeological_site|fort
    if (types.contains(POIType.historicSite)) {
      queryParts.add(
          '  node["historic"~"^(castle|ruins|archaeological_site|fort)\$"](around:$radius,$lat,$lon);');
    }

    // Tourist Attraction: tourism=attraction|artwork|zoo|aquarium|theme_park
    if (types.contains(POIType.touristAttraction)) {
      queryParts.add(
          '  node["tourism"~"^(attraction|artwork|zoo|aquarium|theme_park)\$"](around:$radius,$lat,$lon);');
    }

    // Other: catch various cultural/entertainment venues
    if (types.contains(POIType.other)) {
      queryParts.add(
          '  node["amenity"~"^(theatre|cinema|arts_centre)\$"](around:$radius,$lat,$lon);');
    }

    // Restaurant: amenity=restaurant
    if (types.contains(POIType.restaurant)) {
      queryParts
          .add('  node["amenity"="restaurant"](around:$radius,$lat,$lon);');
    }

    // Cafe: amenity=cafe
    if (types.contains(POIType.cafe)) {
      queryParts.add('  node["amenity"="cafe"](around:$radius,$lat,$lon);');
    }

    // Bakery: shop=bakery
    if (types.contains(POIType.bakery)) {
      queryParts.add('  node["shop"="bakery"](around:$radius,$lat,$lon);');
    }

    // Supermarket: shop=supermarket
    if (types.contains(POIType.supermarket)) {
      queryParts
          .add('  node["shop"="supermarket"](around:$radius,$lat,$lon);');
    }

    // Hardware Store: shop=doityourself|hardware
    if (types.contains(POIType.hardwareStore)) {
      queryParts.add(
          '  node["shop"~"^(doityourself|hardware)\$"](around:$radius,$lat,$lon);');
    }

    // Pharmacy: amenity=pharmacy
    if (types.contains(POIType.pharmacy)) {
      queryParts
          .add('  node["amenity"="pharmacy"](around:$radius,$lat,$lon);');
    }

    // Gas Station: amenity=fuel
    if (types.contains(POIType.gasStation)) {
      queryParts.add('  node["amenity"="fuel"](around:$radius,$lat,$lon);');
    }

    // Hotel: tourism=hotel
    if (types.contains(POIType.hotel)) {
      queryParts.add('  node["tourism"="hotel"](around:$radius,$lat,$lon);');
    }

    // Bar: amenity=bar
    if (types.contains(POIType.bar)) {
      queryParts.add('  node["amenity"="bar"](around:$radius,$lat,$lon);');
    }

    // Fast Food: amenity=fast_food
    if (types.contains(POIType.fastFood)) {
      queryParts
          .add('  node["amenity"="fast_food"](around:$radius,$lat,$lon);');
    }

    // If no query parts, return empty result
    if (queryParts.isEmpty) {
      return Uri.encodeComponent(
          '[out:json][timeout:25];();out body;>;out skel qt;');
    }

    final query = '''
[out:json][timeout:25];
(
${queryParts.join('\n')}
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

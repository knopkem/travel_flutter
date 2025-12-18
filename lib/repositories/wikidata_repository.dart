import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import 'poi_repository.dart';

/// Wikidata SPARQL API repository implementation
///
/// Fetches POIs from Wikidata using SPARQL queries with geographic filtering.
/// Provides structured data including inception dates, visitor counts, and heritage status.
class WikidataRepository implements POIRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://query.wikidata.org/sparql';
  static const int _searchRadiusKm = 10;
  static const int _resultLimit = 100;
  static const Duration _timeout = Duration(seconds: 30);

  WikidataRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<POI>> fetchNearbyPOIs(Location city) async {
    // Validate coordinates
    if (city.latitude < -90 || city.latitude > 90) {
      throw ArgumentError('Invalid latitude: ${city.latitude}');
    }
    if (city.longitude < -180 || city.longitude > 180) {
      throw ArgumentError('Invalid longitude: ${city.longitude}');
    }

    final query = _buildSPARQLQuery(city.latitude, city.longitude);
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': query,
      'format': 'json',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/sparql-results+json',
          'User-Agent': 'TravelFlutterApp/1.0 (Flutter)',
        },
      ).timeout(_timeout);

      if (response.statusCode == 429) {
        throw Exception('Wikidata query timeout limit reached');
      }

      if (response.statusCode == 503) {
        throw Exception('Wikidata service temporarily unavailable');
      }

      if (response.statusCode == 400) {
        throw Exception('Invalid SPARQL query: ${response.body}');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Wikidata SPARQL API failed with status ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Check for error in response
      if (data.containsKey('message')) {
        throw Exception('Wikidata API error: ${data['message']}');
      }

      final results = data['results'] as Map<String, dynamic>?;
      if (results == null) {
        return []; // No results
      }

      final bindings = results['bindings'] as List<dynamic>?;
      if (bindings == null || bindings.isEmpty) {
        return []; // No POIs found
      }

      // Parse results into POI objects
      final pois = <POI>[];
      for (final binding in bindings) {
        try {
          final poi = POI.fromWikidata(
            binding as Map<String, dynamic>,
            city,
          );
          pois.add(poi);
        } catch (e) {
          // Skip invalid items but continue processing others
          // Silently continue to avoid production logging
        }
      }

      return pois;
    } on http.ClientException catch (e) {
      throw Exception('Network error fetching Wikidata: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON response from Wikidata: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Wikidata SPARQL query timed out after 30 seconds');
      }
      rethrow;
    }
  }

  /// Build SPARQL query for notable places within radius
  String _buildSPARQLQuery(double lat, double lon) {
    return '''
SELECT DISTINCT ?place ?placeLabel ?coord ?wikipedia ?description ?inception ?visitorCount ?heritageStatus
WHERE {
  SERVICE wikibase:around {
    ?place wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point($lon $lat)"^^geo:wktLiteral.
    bd:serviceParam wikibase:radius "$_searchRadiusKm".
    bd:serviceParam wikibase:distance ?dist.
  }
  
  VALUES ?placeType {
    wd:Q570116    # tourist attraction
    wd:Q33506     # museum
    wd:Q4989906   # monument
    wd:Q839954    # archaeological site
    wd:Q23413     # castle
    wd:Q811979    # architectural structure
    wd:Q12518     # tower
    wd:Q16970     # church
    wd:Q44539     # temple
    wd:Q34627     # synagogue
    wd:Q32815     # mosque
    wd:Q41176     # building
  }
  ?place wdt:P31/wdt:P279* ?placeType.
  
  OPTIONAL {
    ?wikipedia schema:about ?place;
               schema:isPartOf <https://en.wikipedia.org/>;
               schema:name ?wikipediaTitle.
  }
  
  OPTIONAL {
    ?place schema:description ?description.
    FILTER(LANG(?description) = "en")
  }
  
  OPTIONAL { ?place wdt:P571 ?inception. }
  
  OPTIONAL { ?place wdt:P1174 ?visitorCount. }
  
  OPTIONAL {
    ?place wdt:P1435 ?heritage.
    ?heritage rdfs:label ?heritageStatus.
    FILTER(LANG(?heritageStatus) = "en")
  }
  
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT $_resultLimit
''';
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}

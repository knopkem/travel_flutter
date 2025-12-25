import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';
import 'poi_repository.dart';

/// Wikidata SPARQL API repository implementation
///
/// Fetches POIs from Wikidata using SPARQL queries with geographic filtering.
/// Provides structured data including inception dates, visitor counts, and heritage status.
class WikidataRepository implements POIRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://query.wikidata.org/sparql';
  static const int _resultLimit = 100;
  static const Duration _timeout = Duration(seconds: 30);
  String _languageCode = 'en';

  WikidataRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Set the language code for API requests (e.g., 'de' for German)
  void setLanguageCode(String languageCode) {
    _languageCode = languageCode;
  }

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

    final radiusKm = (radiusMeters / 1000).round();
    final query = _buildSPARQLQuery(
        city.latitude, city.longitude, radiusKm, enabledTypes);
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
          // Filter out POIs with no proper name
          if (poi.name.isNotEmpty &&
              poi.name != 'Unnamed Location' &&
              !poi.name.toLowerCase().contains('unnamed')) {
            pois.add(poi);
          }
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

  /// Build SPARQL query for notable places within radius based on enabled types
  String _buildSPARQLQuery(
      double lat, double lon, int radiusKm, Set<POIType>? enabledTypes) {
    // If no filter provided, include all types
    final types = enabledTypes ?? POIType.values.toSet();

    // Build VALUES clause based on enabled types
    final qCodes = <String>[];

    if (types.contains(POIType.touristAttraction)) {
      qCodes.add('wd:Q570116'); // tourist attraction
    }

    if (types.contains(POIType.museum)) {
      qCodes.add('wd:Q33506'); // museum
    }

    if (types.contains(POIType.monument)) {
      qCodes.add('wd:Q4989906'); // monument
    }

    if (types.contains(POIType.historicSite)) {
      qCodes.add('wd:Q23413'); // castle
      qCodes.add('wd:Q839954'); // archaeological site
    }

    if (types.contains(POIType.park)) {
      qCodes.add('wd:Q22698'); // park
    }

    if (types.contains(POIType.religiousSite)) {
      qCodes.add('wd:Q16970'); // church
      qCodes.add('wd:Q44539'); // temple
      qCodes.add('wd:Q34627'); // synagogue
      qCodes.add('wd:Q32815'); // mosque
    }

    if (types.contains(POIType.viewpoint)) {
      qCodes.add('wd:Q215380'); // viewpoint
    }

    // If 'other' is enabled, add general architectural/cultural types
    if (types.contains(POIType.other)) {
      qCodes.add('wd:Q811979'); // architectural structure
      qCodes.add('wd:Q12518'); // tower
      qCodes.add('wd:Q41176'); // building
    }

    // If no Q-codes selected, return query that matches nothing
    if (qCodes.isEmpty) {
      return '''
SELECT DISTINCT ?place ?placeLabel ?coord ?wikipedia ?description ?inception ?visitorCount ?heritageStatus
WHERE {
  SERVICE wikibase:around {
    ?place wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point($lon $lat)"^^geo:wktLiteral.
    bd:serviceParam wikibase:radius "$radiusKm".
  }
  FILTER(false)
}
LIMIT $_resultLimit
''';
    }

    // Build VALUES clause
    final valuesClause = qCodes.isNotEmpty
        ? '''VALUES ?placeType {
    ${qCodes.join('\n    ')}
  }
  ?place wdt:P31/wdt:P279* ?placeType.'''
        : '';

    return '''
SELECT DISTINCT ?place ?placeLabel ?coord ?wikipedia ?description ?inception ?visitorCount ?heritageStatus
WHERE {
  SERVICE wikibase:around {
    ?place wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point($lon $lat)"^^geo:wktLiteral.
    bd:serviceParam wikibase:radius "$radiusKm".
    bd:serviceParam wikibase:distance ?dist.
  }
  
  $valuesClause
  
  OPTIONAL {
    ?wikipedia schema:about ?place;
               schema:isPartOf <https://$_languageCode.wikipedia.org/>;
               schema:name ?wikipediaTitle.
  }
  
  OPTIONAL {
    ?place schema:description ?description.
    FILTER(LANG(?description) = "$_languageCode")
  }
  
  OPTIONAL { ?place wdt:P571 ?inception. }
  
  OPTIONAL { ?place wdt:P1174 ?visitorCount. }
  
  OPTIONAL {
    ?place wdt:P1435 ?heritage.
    ?heritage rdfs:label ?heritageStatus.
    FILTER(LANG(?heritageStatus) = "$_languageCode")
  }
  
  SERVICE wikibase:label { bd:serviceParam wikibase:language "$_languageCode". }
}
LIMIT $_resultLimit
''';
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}

# API Contract: Wikidata SPARQL API

**Provider**: Wikimedia Foundation  
**Base URL**: `https://query.wikidata.org/sparql`  
**Authentication**: None required  
**Rate Limit**: Reasonable use, 60-second query timeout  
**Documentation**: https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service

## Overview

The Wikidata SPARQL endpoint provides structured semantic data about notable places, including properties like inception dates, architect information, visitor counts, and cultural significance. This enriches POI data with authoritative metadata.

## Endpoint

### Query Places by Coordinates

**Method**: `GET`  
**Path**: `/sparql`  
**Accept**: `application/sparql-results+json`  
**Query Parameter**: `query` (URL-encoded SPARQL query)

## SPARQL Query Template

### Notable Places Within Radius

```sparql
SELECT DISTINCT ?place ?placeLabel ?coord ?wikipedia ?description ?inception ?visitorCount ?heritageStatus
WHERE {
  SERVICE wikibase:around {
    ?place wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point({lon} {lat})"^^geo:wktLiteral.
    bd:serviceParam wikibase:radius "10".
    bd:serviceParam wikibase:distance ?dist.
  }
  
  # Filter for notable places (instance of tourist attraction, museum, monument, etc.)
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
  
  # Optional: Get Wikipedia article (English)
  OPTIONAL {
    ?wikipedia schema:about ?place;
               schema:isPartOf <https://en.wikipedia.org/>;
               schema:name ?wikipediaTitle.
  }
  
  # Optional: Get description
  OPTIONAL {
    ?place schema:description ?description.
    FILTER(LANG(?description) = "en")
  }
  
  # Optional: Get inception date
  OPTIONAL { ?place wdt:P571 ?inception. }
  
  # Optional: Get visitor count per year
  OPTIONAL { ?place wdt:P1174 ?visitorCount. }
  
  # Optional: Get heritage status (UNESCO, national, etc.)
  OPTIONAL {
    ?place wdt:P1435 ?heritage.
    ?heritage rdfs:label ?heritageStatus.
    FILTER(LANG(?heritageStatus) = "en")
  }
  
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 100
```

### Query Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `{lat}` | float | Center latitude | `48.8566` |
| `{lon}` | float | Center longitude | `2.3522` |
| `radius` | integer | Search radius in kilometers | `10` |
| `LIMIT` | integer | Max results | `100` |

## Request Example

```http
GET /sparql?query=SELECT%20DISTINCT%20%3Fplace%20... HTTP/1.1
Host: query.wikidata.org
Accept: application/sparql-results+json
User-Agent: TravelFlutterApp/1.0 (Flutter; +https://github.com/flutter/flutter)
```

## Response Format

### Success Response (HTTP 200)

```json
{
  "head": {
    "vars": ["place", "placeLabel", "coord", "wikipedia", "description", "inception", "visitorCount", "heritageStatus"]
  },
  "results": {
    "bindings": [
      {
        "place": {
          "type": "uri",
          "value": "http://www.wikidata.org/entity/Q243"
        },
        "placeLabel": {
          "type": "literal",
          "value": "Eiffel Tower",
          "xml:lang": "en"
        },
        "coord": {
          "type": "literal",
          "value": "Point(2.2944813 48.8583701)",
          "datatype": "http://www.opengis.net/ont/geosparql#wktLiteral"
        },
        "wikipedia": {
          "type": "uri",
          "value": "https://en.wikipedia.org/wiki/Eiffel_Tower"
        },
        "description": {
          "type": "literal",
          "value": "tower on the Champ de Mars in Paris, France",
          "xml:lang": "en"
        },
        "inception": {
          "type": "literal",
          "value": "1889-03-31T00:00:00Z",
          "datatype": "http://www.w3.org/2001/XMLSchema#dateTime"
        },
        "visitorCount": {
          "type": "literal",
          "value": "7000000",
          "datatype": "http://www.w3.org/2001/XMLSchema#decimal"
        },
        "heritageStatus": {
          "type": "literal",
          "value": "UNESCO World Heritage Site",
          "xml:lang": "en"
        }
      }
    ]
  }
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `place.value` | URI | Wikidata entity URI (extract Q-ID) |
| `placeLabel.value` | string | Name of the place |
| `coord.value` | WKT | WKT coordinate string (parse lat/lon) |
| `wikipedia.value` | URI | Wikipedia article URL (extract title) |
| `description.value` | string | Short description of the place |
| `inception.value` | ISO 8601 | Date the place was established |
| `visitorCount.value` | decimal | Annual visitor count |
| `heritageStatus.value` | string | Heritage designation (if any) |

### Error Response (HTTP 429 - Rate Limit)

```json
{
  "message": "Query timeout limit reached"
}
```

## Mapping to POI Model

```dart
factory POI.fromWikidata(
  Map<String, dynamic> binding,
  City city,
) {
  final coord = _parseWKTCoordinate(binding['coord']['value']);
  final wikidataId = _extractWikidataId(binding['place']['value']);
  final wikipediaTitle = _extractWikipediaTitle(binding['wikipedia']?['value']);
  
  return POI(
    id: _generateId(binding['placeLabel']['value'], coord.latitude, coord.longitude),
    name: binding['placeLabel']['value'] as String,
    description: binding['description']?['value'] as String?,
    type: POIType.landmark, // Default, can refine based on place type
    latitude: coord.latitude,
    longitude: coord.longitude,
    distanceFromCity: _calculateDistance(
      city.latitude,
      city.longitude,
      coord.latitude,
      coord.longitude,
    ),
    sources: [POISource.wikidata],
    wikipediaTitle: wikipediaTitle,
    wikidataId: wikidataId,
    heritageStatus: binding['heritageStatus']?['value'] as String?,
    yearEstablished: _parseInceptionYear(binding['inception']?['value']),
    annualVisitors: _parseVisitorCount(binding['visitorCount']?['value']),
    notabilityScore: _calculateNotability(binding),
    discoveredAt: DateTime.now(),
  );
}

LatLng _parseWKTCoordinate(String wkt) {
  // Parse "Point(2.2944813 48.8583701)" -> LatLng(48.8583701, 2.2944813)
  final match = RegExp(r'Point\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(wkt);
  if (match == null) throw FormatException('Invalid WKT coordinate: $wkt');
  return LatLng(
    double.parse(match.group(2)!), // latitude (second number)
    double.parse(match.group(1)!), // longitude (first number)
  );
}

String _extractWikidataId(String uri) {
  // "http://www.wikidata.org/entity/Q243" -> "Q243"
  return uri.split('/').last;
}

String? _extractWikipediaTitle(String? url) {
  if (url == null) return null;
  // "https://en.wikipedia.org/wiki/Eiffel_Tower" -> "Eiffel Tower"
  final title = url.split('/').last;
  return Uri.decodeComponent(title.replaceAll('_', ' '));
}

int? _parseInceptionYear(String? inception) {
  if (inception == null) return null;
  // "1889-03-31T00:00:00Z" -> 1889
  return DateTime.tryParse(inception)?.year;
}

int? _parseVisitorCount(String? count) {
  if (count == null) return null;
  return int.tryParse(count);
}

int _calculateNotability(Map<String, dynamic> binding) {
  int score = 60; // Base score for Wikidata entities
  if (binding['wikipedia'] != null) score += 15;
  if (binding['heritageStatus'] != null) {
    final status = binding['heritageStatus']['value'] as String;
    if (status.contains('UNESCO')) score += 30;
    else score += 15;
  }
  if (binding['visitorCount'] != null) {
    final count = int.tryParse(binding['visitorCount']['value'] as String);
    if (count != null && count > 1000000) score += 10;
  }
  if (binding['inception'] != null) score += 5;
  return score.clamp(0, 100);
}
```

## Error Handling

### Client-Side Errors
- **Invalid SPARQL query**: Validate query syntax before sending
- **Empty results**: Return empty list, not an error
- **WKT parse error**: Log and skip entry

### API Errors
- **429 Query Timeout**: Reduce radius or simplify query, skip on retry failure
- **400 Bad Request**: Log query, skip this source
- **503 Service Unavailable**: Retry once after 5-second delay
- **Network timeout**: 30-second client timeout, catch and log

## Rate Limiting

**Strategy**: No explicit rate limiting, but respect 60-second query timeout

**Implementation**:
```dart
Future<List<POI>> _fetchFromWikidata(City city) async {
  try {
    final response = await http
        .get(Uri.parse(query))
        .timeout(Duration(seconds: 30));
    // Process response
  } on TimeoutException {
    _logger.warning('Wikidata query timeout for ${city.name}');
    return [];
  } catch (e) {
    _logger.error('Wikidata query failed: $e');
    return [];
  }
}
```

## Wikidata Place Types Reference

### Primary Types (Use in Query)
- `wd:Q570116` - tourist attraction
- `wd:Q33506` - museum
- `wd:Q4989906` - monument
- `wd:Q839954` - archaeological site
- `wd:Q23413` - castle
- `wd:Q811979` - architectural structure

### Secondary Types
- `wd:Q12518` - tower
- `wd:Q16970` - church (Christian)
- `wd:Q44539` - temple
- `wd:Q34627` - synagogue
- `wd:Q32815` - mosque
- `wd:Q41176` - building (general)

### Relevant Properties (Wikidata Property IDs)
- `wdt:P625` - coordinate location
- `wdt:P31` - instance of
- `wdt:P279` - subclass of
- `wdt:P571` - inception date
- `wdt:P1174` - visitors per year
- `wdt:P1435` - heritage designation
- `wdt:P84` - architect
- `wdt:P149` - architectural style

## Testing

### Mock Response
```dart
final mockWikidataResponse = {
  'results': {
    'bindings': [
      {
        'place': {'value': 'http://www.wikidata.org/entity/Q9202'},
        'placeLabel': {'value': 'Statue of Liberty'},
        'coord': {'value': 'Point(-74.0445 40.6892)'},
        'wikipedia': {'value': 'https://en.wikipedia.org/wiki/Statue_of_Liberty'},
        'description': {'value': 'colossal neoclassical sculpture on Liberty Island'},
        'inception': {'value': '1886-10-28T00:00:00Z'},
        'heritageStatus': {'value': 'UNESCO World Heritage Site'},
      }
    ]
  }
};
```

### Test Cases
1. ✅ Valid response with complete data
2. ✅ Response with missing optional fields
3. ✅ WKT coordinate parsing (various formats)
4. ✅ Wikidata ID extraction from URI
5. ✅ Wikipedia title extraction from URL
6. ✅ Inception date parsing (year extraction)
7. ✅ Query timeout (30 seconds)
8. ✅ Empty results
9. ✅ Malformed SPARQL query error
10. ✅ Service unavailable with retry

## Implementation Notes

1. **Query Complexity**: Keep SPARQL queries simple to avoid timeouts
2. **Coordinate Format**: WKT uses longitude-first order (lon, lat), opposite of typical LatLng
3. **Place Type Hierarchy**: Use `wdt:P31/wdt:P279*` to match subclasses (e.g., Gothic church is subclass of church)
4. **Language Filtering**: Always filter by `LANG(?var) = "en"` for English-language data
5. **Optional Properties**: Wrap all non-coordinate properties in `OPTIONAL` blocks
6. **Result Limit**: 100 results is reasonable, adjust if needed
7. **Service Wrapper**: Use `wikibase:around` service for geographic queries (more efficient than manual distance calculation)
8. **Label Service**: Use `wikibase:label` service for automatic label resolution in preferred language
9. **Heritage Bonus**: UNESCO World Heritage Sites get highest notability boost
10. **Visitor Counts**: Use for notability scoring but may be outdated (check last updated date if available)

# API Contract: Wikipedia Geosearch API

**Provider**: Wikimedia Foundation  
**Base URL**: `https://en.wikipedia.org/w/api.php`  
**Authentication**: None required  
**Rate Limit**: Reasonable use, no strict limit  
**Documentation**: https://www.mediawiki.org/wiki/API:Geosearch

## Overview

The Wikipedia Geosearch API returns Wikipedia articles that have geographic coordinates near a specified location. This is used for the initial fast POI discovery phase.

## Endpoint

### Search Articles by Coordinates

**Method**: `GET`  
**Path**: `/w/api.php`  
**Query Parameters**:
- `action=query` (required)
- `list=geosearch` (required)
- `gscoord={latitude}|{longitude}` (required) - Center point coordinates
- `gsradius={meters}` (required) - Search radius in meters (max 10000)
- `gslimit={count}` (optional) - Max results, default 10, max 500
- `format=json` (required)

## Request Example

```http
GET /w/api.php?action=query&list=geosearch&gscoord=48.8566|2.3522&gsradius=10000&gslimit=50&format=json HTTP/1.1
Host: en.wikipedia.org
User-Agent: TravelFlutterApp/1.0 (Flutter; +https://github.com/flutter/flutter)
```

## Response Format

### Success Response (HTTP 200)

```json
{
  "batchcomplete": "",
  "query": {
    "geosearch": [
      {
        "pageid": 22989,
        "ns": 0,
        "title": "Eiffel Tower",
        "lat": 48.8584,
        "lon": 2.2945,
        "dist": 1234.5,
        "primary": ""
      },
      {
        "pageid": 19185,
        "ns": 0,
        "title": "Louvre",
        "lat": 48.8606,
        "lon": 2.3376,
        "dist": 2156.8,
        "primary": ""
      }
    ]
  }
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `pageid` | integer | Wikipedia page ID (unique) |
| `ns` | integer | Namespace (0 = main articles, filter for this) |
| `title` | string | Article title (use for fetching full content) |
| `lat` | float | Latitude of the location |
| `lon` | float | Longitude of the location |
| `dist` | float | Distance from search center in meters |
| `primary` | string | Empty string or coordinate type |

### Error Response (HTTP 200 with error)

```json
{
  "error": {
    "code": "badvalue",
    "info": "Invalid value for parameter gscoord"
  }
}
```

## Mapping to POI Model

```dart
factory POI.fromWikipediaGeosearch(
  Map<String, dynamic> json,
  City city
) {
  return POI(
    id: _generateId(json['title'], json['lat'], json['lon']),
    name: json['title'] as String,
    type: POIType.touristAttraction, // Default, refine based on article
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    distanceFromCity: json['dist'] as double,
    sources: [POISource.wikipediaGeosearch],
    wikipediaTitle: json['title'] as String,
    notabilityScore: 75, // Base score for Wikipedia articles
    discoveredAt: DateTime.now(),
  );
}
```

## Error Handling

### Client-Side Errors
- **Invalid coordinates**: Validate before making request
- **Radius too large**: Clamp to 10000 meters max
- **Empty query**: Skip this source, continue with others

### API Errors
- **Network timeout**: 10-second timeout, catch and log
- **Invalid response**: Skip malformed entries, process valid ones
- **No results**: Return empty list, not an error condition

## Rate Limiting

**Strategy**: No explicit rate limiting required (reasonable use policy)

**Monitoring**: Log requests, if encountering 429 responses, implement exponential backoff

## Testing

### Mock Response
```dart
final mockResponse = {
  'query': {
    'geosearch': [
      {
        'pageid': 12345,
        'ns': 0,
        'title': 'Test Landmark',
        'lat': 40.7128,
        'lon': -74.0060,
        'dist': 1500.0,
      }
    ]
  }
};
```

### Test Cases
1. ✅ Valid response with multiple results
2. ✅ Valid response with zero results (empty array)
3. ✅ Response with non-main namespace entries (filter out)
4. ✅ Network timeout (10 seconds)
5. ✅ Malformed JSON response
6. ✅ API error response

## Implementation Notes

1. Always filter for `ns: 0` (main namespace articles only)
2. Use `title` field directly for Wikipedia article fetching
3. `dist` field is reliable for sorting by proximity
4. Some articles may not be POIs (e.g., city article itself) - handle in deduplication
5. Results are pre-sorted by distance (closest first)

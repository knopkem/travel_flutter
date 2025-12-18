# API Contract: OpenStreetMap Overpass API

**Provider**: OpenStreetMap Foundation  
**Base URL**: `https://overpass-api.de/api/interpreter`  
**Authentication**: None required  
**Rate Limit**: 1 request/second, 10K elements per query  
**Documentation**: https://wiki.openstreetmap.org/wiki/Overpass_API

## Overview

The Overpass API queries OpenStreetMap data for points of interest within a specified radius. This provides comprehensive coverage of tourist attractions, monuments, museums, and other tagged locations.

## Endpoint

### Query POIs by Radius

**Method**: `POST`  
**Path**: `/api/interpreter`  
**Content-Type**: `application/x-www-form-urlencoded`  
**Body**: Overpass QL query as form data with key `data`

## Query Structure

### Overpass QL Query Template

```overpass
[out:json][timeout:25];
(
  node["tourism"~"^(attraction|museum|monument|artwork|viewpoint|gallery|zoo|aquarium|theme_park)$"]
    (around:{radius},{lat},{lon});
  node["historic"~"^(monument|memorial|archaeological_site|castle|ruins|fort|manor|palace)$"]
    (around:{radius},{lat},{lon});
  node["amenity"~"^(theatre|cinema|arts_centre|library|community_centre)$"]
    (around:{radius},{lat},{lon});
);
out body;
>;
out skel qt;
```

### Query Parameters (Placeholders)

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `{radius}` | integer | Search radius in meters | `10000` |
| `{lat}` | float | Center latitude | `48.8566` |
| `{lon}` | float | Center longitude | `2.3522` |
| `timeout` | integer | Query timeout in seconds | `25` |

## Request Example

```http
POST /api/interpreter HTTP/1.1
Host: overpass-api.de
Content-Type: application/x-www-form-urlencoded
User-Agent: TravelFlutterApp/1.0 (Flutter; +https://github.com/flutter/flutter)

data=[out:json][timeout:25];(node["tourism"~"^(attraction|museum|monument)$"](around:10000,48.8566,2.3522););out body;
```

## Response Format

### Success Response (HTTP 200)

```json
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "node",
      "id": 1538734534,
      "lat": 48.8583701,
      "lon": 2.2944813,
      "tags": {
        "name": "Eiffel Tower",
        "name:en": "Eiffel Tower",
        "tourism": "attraction",
        "historic": "monument",
        "wikidata": "Q243",
        "wikipedia": "en:Eiffel Tower",
        "height": "330",
        "start_date": "1889",
        "website": "https://www.toureiffel.paris"
      }
    },
    {
      "type": "node",
      "id": 3536622229,
      "lat": 48.8606111,
      "lon": 2.337644,
      "tags": {
        "name": "Louvre Museum",
        "tourism": "museum",
        "wikidata": "Q19675",
        "wikipedia": "en:Louvre",
        "opening_hours": "Mo,Th-Su 09:00-18:00; We 09:00-21:45"
      }
    }
  ]
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `elements` | array | Array of OSM nodes matching the query |
| `elements[].id` | integer | OSM node ID (unique) |
| `elements[].lat` | float | Latitude |
| `elements[].lon` | float | Longitude |
| `elements[].tags` | object | Key-value pairs of OSM tags |
| `elements[].tags.name` | string | Primary name of the POI |
| `elements[].tags.tourism` | string | Tourism tag (attraction, museum, etc.) |
| `elements[].tags.historic` | string | Historic tag (monument, memorial, etc.) |
| `elements[].tags.wikidata` | string | Wikidata entity ID (Q-number) |
| `elements[].tags.wikipedia` | string | Wikipedia article reference (lang:Title) |

### Error Response (HTTP 429 - Rate Limit)

```json
{
  "remark": "runtime error: Query run out of memory using about 536870912 bytes of RAM."
}
```

### Error Response (HTTP 400 - Bad Query)

```json
{
  "remark": "Error: line 1: parse error: Key expected - '!' found."
}
```

## Mapping to POI Model

```dart
factory POI.fromOverpass(
  Map<String, dynamic> element,
  City city,
) {
  final tags = element['tags'] as Map<String, dynamic>? ?? {};
  final lat = (element['lat'] as num).toDouble();
  final lon = (element['lon'] as num).toDouble();
  
  return POI(
    id: _generateId(tags['name'], lat, lon),
    name: _extractName(tags),
    description: _extractDescription(tags),
    type: _mapOSMTagToType(tags),
    latitude: lat,
    longitude: lon,
    distanceFromCity: _calculateDistance(city.latitude, city.longitude, lat, lon),
    sources: [POISource.overpass],
    wikipediaTitle: _extractWikipediaTitle(tags['wikipedia']),
    wikidataId: tags['wikidata'] as String?,
    website: tags['website'] as String?,
    openingHours: tags['opening_hours'] as String?,
    notabilityScore: _calculateNotability(tags),
    discoveredAt: DateTime.now(),
  );
}

POIType _mapOSMTagToType(Map<String, dynamic> tags) {
  if (tags['historic'] != null) return POIType.monument;
  if (tags['tourism'] == 'museum') return POIType.museum;
  if (tags['tourism'] == 'viewpoint') return POIType.viewpoint;
  if (tags['tourism'] == 'attraction') return POIType.landmark;
  return POIType.touristAttraction;
}

int _calculateNotability(Map<String, dynamic> tags) {
  int score = 50; // Base score
  if (tags['wikidata'] != null) score += 20;
  if (tags['wikipedia'] != null) score += 15;
  if (tags['website'] != null) score += 5;
  if (tags['name:en'] != null) score += 5;
  if (tags['unesco'] != null) score += 30;
  return score.clamp(0, 100);
}

String? _extractWikipediaTitle(String? wikipedia) {
  if (wikipedia == null) return null;
  // Format: "en:Eiffel Tower" -> "Eiffel Tower"
  final parts = wikipedia.split(':');
  return parts.length > 1 ? parts[1] : null;
}
```

## Error Handling

### Client-Side Errors
- **Query timeout**: Set 25-second timeout, increase if needed
- **Empty results**: Return empty list, not an error
- **Invalid coordinates**: Validate before building query

### API Errors
- **429 Rate Limit**: Implement 1-second delay between requests
- **400 Bad Query**: Log query string, skip this source
- **504 Timeout**: Reduce radius or simplify query, retry once
- **Too Many Requests**: Exponential backoff (2s, 4s, 8s)

## Rate Limiting

**Enforcement**: 1 request per second per IP  
**Implementation**:
```dart
DateTime? _lastOverpassRequest;

Future<void> _enforceRateLimit() async {
  if (_lastOverpassRequest != null) {
    final elapsed = DateTime.now().difference(_lastOverpassRequest!);
    if (elapsed.inMilliseconds < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
    }
  }
  _lastOverpassRequest = DateTime.now();
}
```

## OSM Tag Reference

### Tourism Tags (Primary)
- `tourism=attraction` - General tourist attraction
- `tourism=museum` - Museum
- `tourism=monument` - Monument (deprecated, use historic)
- `tourism=artwork` - Public art installation
- `tourism=viewpoint` - Scenic viewpoint
- `tourism=gallery` - Art gallery
- `tourism=zoo` - Zoo
- `tourism=aquarium` - Aquarium
- `tourism=theme_park` - Theme park

### Historic Tags (Secondary)
- `historic=monument` - Historic monument
- `historic=memorial` - Memorial
- `historic=archaeological_site` - Archaeological site
- `historic=castle` - Castle
- `historic=ruins` - Ruins
- `historic=fort` - Fort/fortress
- `historic=manor` - Historic manor
- `historic=palace` - Palace

### Amenity Tags (Tertiary)
- `amenity=theatre` - Theatre
- `amenity=cinema` - Cinema
- `amenity=arts_centre` - Arts center
- `amenity=library` - Library
- `amenity=community_centre` - Community center

## Testing

### Mock Response
```dart
final mockOverpassResponse = {
  'elements': [
    {
      'type': 'node',
      'id': 123456,
      'lat': 40.7128,
      'lon': -74.0060,
      'tags': {
        'name': 'Statue of Liberty',
        'tourism': 'attraction',
        'historic': 'monument',
        'wikidata': 'Q9202',
        'wikipedia': 'en:Statue of Liberty',
        'unesco': 'yes',
      }
    }
  ]
};
```

### Test Cases
1. ✅ Valid response with multiple POIs
2. ✅ Response with missing optional tags
3. ✅ Response with no name tag (skip entry)
4. ✅ Rate limit enforcement (1 req/sec)
5. ✅ Network timeout (25 seconds)
6. ✅ Empty results array
7. ✅ 429 rate limit error with retry
8. ✅ Invalid query syntax error

## Implementation Notes

1. **Query Optimization**: Combine multiple tag queries with OR logic to reduce API calls
2. **Name Extraction**: Prefer `name:en` over `name` for English localization
3. **Distance Calculation**: Calculate client-side using Haversine formula (Overpass doesn't return distance)
4. **Wikidata Linking**: Use `wikidata` tag to enrich POI data from Wikidata API
5. **Rate Limiting**: CRITICAL - must enforce 1 req/sec to avoid IP ban
6. **Timeout**: 25 seconds is reasonable for 10km radius queries
7. **Element Limit**: If hitting 10K element limit, reduce radius or narrow tags

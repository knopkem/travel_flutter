# Nominatim Geocoding API Contract
*Path: kitty-specs/001-location-search-wikipedia/contracts/nominatim-api.md*

**Service**: OpenStreetMap Nominatim
**Base URL**: `https://nominatim.openstreetmap.org`
**Documentation**: https://nominatim.org/release-docs/latest/api/Search/
**Authentication**: None required
**Rate Limit**: 1 request per second

---

## Search Endpoint

### Request

**Method**: GET

**URL**: `/search`

**Query Parameters**:

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `q` | string | Yes | Search query text | `Paris` |
| `format` | string | Yes | Response format | `json` |
| `limit` | integer | No | Maximum results (default: 10) | `5` |
| `addressdetails` | integer | No | Include address breakdown (0 or 1) | `1` |
| `accept-language` | string | No | Preferred language | `en` |

**Headers**:

| Header | Value | Required | Description |
|--------|-------|----------|-------------|
| `User-Agent` | `TravelFlutterApp/1.0` | Yes | Custom user agent identifying the app |

**Example Request**:
```http
GET https://nominatim.openstreetmap.org/search?q=Paris&format=json&limit=5&addressdetails=1
User-Agent: TravelFlutterApp/1.0
```

**Flutter/Dart Example**:
```dart
final uri = Uri.https(
  'nominatim.openstreetmap.org',
  '/search',
  {
    'q': 'Paris',
    'format': 'json',
    'limit': '5',
    'addressdetails': '1',
  },
);

final response = await http.get(
  uri,
  headers: {'User-Agent': 'TravelFlutterApp/1.0'},
);
```

---

### Response

**Success Status Code**: 200 OK

**Content-Type**: `application/json`

**Response Body**: Array of place objects

**Example Response**:
```json
[
  {
    "place_id": 240109189,
    "licence": "Data © OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
    "osm_type": "relation",
    "osm_id": 7444,
    "boundingbox": ["48.8155414", "48.9021532", "2.2242191", "2.4699099"],
    "lat": "48.8588897",
    "lon": "2.3200410217200766",
    "display_name": "Paris, Île-de-France, France métropolitaine, France",
    "class": "boundary",
    "type": "administrative",
    "importance": 0.9654895599999999,
    "icon": "https://nominatim.openstreetmap.org/ui/mapicons/poi_boundary_administrative.p.20.png",
    "address": {
      "city": "Paris",
      "county": "Paris",
      "state": "Île-de-France",
      "ISO3166-2-lvl6": "FR-75",
      "country": "France",
      "country_code": "fr"
    }
  },
  {
    "place_id": 297340388,
    "osm_id": 574406,
    "lat": "33.6617962",
    "lon": "-95.5577144",
    "display_name": "Paris, Lamar County, Texas, United States",
    "address": {
      "city": "Paris",
      "county": "Lamar County",
      "state": "Texas",
      "country": "United States",
      "country_code": "us"
    }
  }
]
```

**Key Response Fields**:

| Field | Type | Description | Always Present? |
|-------|------|-------------|-----------------|
| `place_id` | integer | Nominatim's internal place ID | Yes |
| `osm_id` | integer | OpenStreetMap ID (use as unique identifier) | Yes |
| `lat` | string | Latitude coordinate | Yes |
| `lon` | string | Longitude coordinate | Yes |
| `display_name` | string | Full formatted address | Yes |
| `address` | object | Structured address components | If `addressdetails=1` |
| `address.city` | string | City name | Sometimes (may be `town`, `village`, etc.) |
| `address.country` | string | Country name | Usually |
| `address.country_code` | string | ISO country code | Usually |
| `importance` | float | Search relevance score (0-1) | Yes |

---

### Error Responses

**Empty Results** (valid request, no matches):
```json
[]
```
- Status: 200 OK
- Body: Empty array
- Handling: Display "No locations found" message

**Rate Limit Exceeded**:
```json
{"error": "Rate limit exceeded"}
```
- Status: 429 Too Many Requests
- Handling: Display "Too many requests. Please wait a moment." + retry after 1 second

**Invalid Request**:
```json
{"error": "Missing query parameter"}
```
- Status: 400 Bad Request
- Handling: Should not occur with proper client-side validation

**Service Unavailable**:
- Status: 503 Service Unavailable
- Handling: Display "Search unavailable. Please try again later."

---

## Usage Guidelines

### Rate Limiting
- **Limit**: 1 request per second
- **Implementation**: Use 300ms debouncing on search input to naturally comply
- **Consequences**: IP may be temporarily blocked if exceeded
- **Mitigation**: Always debounce user input, never make rapid successive calls

### User-Agent Requirement
- **Required**: Custom User-Agent header identifying your application
- **Format**: `<AppName>/<Version>` (e.g., "TravelFlutterApp/1.0")
- **Consequences**: Requests without User-Agent may be blocked
- **Implementation**: Set header on all requests

### Best Practices
1. Always include `addressdetails=1` to get structured address data
2. Limit results to 5-10 for autocomplete UI
3. Handle empty results gracefully (common for typos)
4. Cache results briefly to reduce duplicate requests
5. URL-encode query parameter (handle special characters)
6. Parse `lat` and `lon` as strings (may have many decimal places)

### Data Extraction
- **Primary ID**: Use `osm_id` for uniqueness
- **City Name**: Check `address.city`, fallback to `address.town` or first part of `display_name`
- **Country**: Use `address.country`, fallback to "Unknown"
- **Coordinates**: Parse `lat` and `lon` as doubles

---

## Example Implementation

```dart
class GeocodingRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'TravelFlutterApp/1.0';
  
  GeocodingRepository(this._client);
  
  Future<List<LocationSuggestion>> search(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      },
    );
    
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => LocationSuggestion.fromJson(json))
            .toList();
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait.');
      } else {
        throw Exception('Search unavailable. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
```

---

## Contract Summary

**Endpoint**: `GET https://nominatim.openstreetmap.org/search`

**Authentication**: None

**Rate Limit**: 1 req/sec (enforced via debouncing)

**Key Requirements**:
- User-Agent header mandatory
- URL-encode query parameter
- Handle empty array as valid response

**Response**: JSON array of place objects with lat/lon and structured address

**Error Handling**: 200 (empty array), 429 (rate limit), 503 (unavailable)

**Ready for Implementation**: ✅

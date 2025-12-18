# Wikipedia REST API Contract
*Path: kitty-specs/001-location-search-wikipedia/contracts/wikipedia-api.md*

**Service**: Wikipedia REST API
**Base URL**: `https://en.wikipedia.org/api/rest_v1`
**Documentation**: https://en.wikipedia.org/api/rest_v1/
**Authentication**: None required
**Rate Limit**: 200 requests per second (generous, no concerns for this app)

---

## Page Summary Endpoint

### Request

**Method**: GET

**URL**: `/page/summary/{title}`

**Path Parameters**:

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `title` | string | Yes | Wikipedia page title (URL-encoded) | `Paris` or `Paris,_France` |

**Query Parameters**: None required

**Headers**: None required (optional: `Accept: application/json`)

**Example Request**:
```http
GET https://en.wikipedia.org/api/rest_v1/page/summary/Paris
Accept: application/json
```

**Flutter/Dart Example**:
```dart
final title = Uri.encodeComponent('Paris');
final uri = Uri.parse(
  'https://en.wikipedia.org/api/rest_v1/page/summary/$title'
);

final response = await http.get(uri);
```

---

### Response

**Success Status Code**: 200 OK

**Content-Type**: `application/json`

**Response Body**: Page summary object

**Example Response**:
```json
{
  "type": "standard",
  "title": "Paris",
  "displaytitle": "Paris",
  "namespace": {
    "id": 0,
    "text": ""
  },
  "wikibase_item": "Q90",
  "titles": {
    "canonical": "Paris",
    "normalized": "Paris",
    "display": "Paris"
  },
  "pageid": 22989,
  "thumbnail": {
    "source": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/La_Tour_Eiffel_vue_de_la_Tour_Saint-Jacques%2C_Paris_ao%C3%BBt_2014_%282%29.jpg/320px-La_Tour_Eiffel_vue_de_la_Tour_Saint-Jacques%2C_Paris_ao%C3%BBt_2014_%282%29.jpg",
    "width": 320,
    "height": 213
  },
  "originalimage": {
    "source": "https://upload.wikimedia.org/wikipedia/commons/4/4b/La_Tour_Eiffel_vue_de_la_Tour_Saint-Jacques%2C_Paris_ao%C3%BBt_2014_%282%29.jpg",
    "width": 2848,
    "height": 1897
  },
  "lang": "en",
  "dir": "ltr",
  "revision": "1234567890",
  "tid": "abcdef12-3456-7890-abcd-ef1234567890",
  "timestamp": "2025-12-01T10:30:00Z",
  "description": "Capital and most populous city of France",
  "description_source": "local",
  "content_urls": {
    "desktop": {
      "page": "https://en.wikipedia.org/wiki/Paris",
      "revisions": "https://en.wikipedia.org/wiki/Paris?action=history",
      "edit": "https://en.wikipedia.org/wiki/Paris?action=edit",
      "talk": "https://en.wikipedia.org/wiki/Talk:Paris"
    },
    "mobile": {
      "page": "https://en.m.wikipedia.org/wiki/Paris",
      "revisions": "https://en.m.wikipedia.org/wiki/Special:History/Paris",
      "edit": "https://en.m.wikipedia.org/wiki/Paris?action=edit",
      "talk": "https://en.m.wikipedia.org/wiki/Talk:Paris"
    }
  },
  "extract": "Paris is the capital and most populous city of France. With an official estimated population of 2,102,650 residents as of 1 January 2023 in an area of more than 105 km2 (41 sq mi), Paris is the fourth-most populated city in the European Union and the 30th most densely populated city in the world in 2022.",
  "extract_html": "<p><b>Paris</b> is the capital and most populous city of <b>France</b>. With an official estimated population of 2,102,650 residents as of 1 January 2023 in an area of more than 105 km<sup>2</sup> (41 sq mi), Paris is the fourth-most populated city in the European Union and the 30th most densely populated city in the world in 2022.</p>",
  "coordinates": {
    "lat": 48.856614,
    "lon": 2.352222
  }
}
```

**Key Response Fields**:

| Field | Type | Description | Always Present? |
|-------|------|-------------|-----------------|
| `type` | string | Page type (`standard`, `disambiguation`, `mainpage`) | Yes |
| `title` | string | Page title | Yes |
| `displaytitle` | string | Formatted display title | Yes |
| `extract` | string | Plain text summary (first paragraph) | Yes (unless redirect) |
| `extract_html` | string | HTML formatted summary | Yes (unless redirect) |
| `thumbnail` | object | Thumbnail image details | Sometimes |
| `thumbnail.source` | string | Image URL | If thumbnail exists |
| `thumbnail.width` | integer | Image width in pixels | If thumbnail exists |
| `thumbnail.height` | integer | Image height in pixels | If thumbnail exists |
| `content_urls.desktop.page` | string | Full article URL | Yes |
| `description` | string | Short description | Usually |
| `coordinates` | object | Geographic coordinates | For places |
| `pageid` | integer | Wikipedia page ID | Yes |

---

### Error Responses

**Page Not Found**:
```json
{
  "type": "https://mediawiki.org/wiki/HyperSwitch/errors/not_found",
  "title": "Not found.",
  "method": "get",
  "detail": "Page or revision not found.",
  "uri": "/page/summary/NonexistentPage"
}
```
- Status: 404 Not Found
- Handling: Display "No information available for this location."

**Disambiguation Page**:
```json
{
  "type": "disambiguation",
  "title": "Paris",
  "extract": "Paris most often refers to: Paris, the capital of France...",
  ...
}
```
- Status: 200 OK
- Note: `type` field = "disambiguation"
- Handling: Can still display the extract (it lists disambiguation options), or show custom message

**Service Unavailable**:
- Status: 503 Service Unavailable
- Handling: Display "Service temporarily unavailable. Please try again."

**Invalid Title**:
- Status: 400 Bad Request
- Handling: Should be rare (sanitize input)

---

## Usage Guidelines

### Title Encoding
- **URL Encoding**: Always encode the title parameter
- **Special Characters**: Spaces become `%20` or `_`
- **Examples**:
  - "New York" → `New%20York` or `New_York`
  - "São Paulo" → `S%C3%A3o%20Paulo`

### Best Practices
1. URL-encode location names before building request
2. Handle disambiguation pages gracefully (show extract or custom message)
3. Check for `thumbnail` existence before accessing `thumbnail.source`
4. Use `extract` (plain text) for simple display, `extract_html` for rich formatting
5. Provide link to full article via `content_urls.desktop.page`
6. Cache responses to avoid redundant requests (e.g., if user navigates back)

### Content Display
- **Summary Length**: `extract` is typically 1-3 sentences (perfect for mobile)
- **HTML Rendering**: If using `extract_html`, render with WebView or HTML parser
- **Images**: Show `thumbnail.source` if available, handle null case
- **Full Article**: Provide button/link to `content_urls.desktop.page`

### Error Handling Strategy
- **404**: Common for small towns without Wikipedia pages → friendly message
- **Disambiguation**: Usually has useful extract → can still display
- **Network errors**: Retry logic or show offline message

---

## Example Implementation

```dart
class WikipediaRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://en.wikipedia.org/api/rest_v1';
  
  WikipediaRepository(this._client);
  
  Future<WikipediaContent> getContent(String locationName) async {
    final encodedTitle = Uri.encodeComponent(locationName);
    final uri = Uri.parse('$_baseUrl/page/summary/$encodedTitle');
    
    try {
      final response = await _client.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Check if it's a disambiguation page
        if (data['type'] == 'disambiguation') {
          // Can still return content or throw custom exception
          return WikipediaContent.fromJson(data);
        }
        
        return WikipediaContent.fromJson(data);
      } else if (response.statusCode == 404) {
        throw WikipediaNotFoundException('No Wikipedia page found for $locationName');
      } else if (response.statusCode == 503) {
        throw WikipediaServiceException('Wikipedia service temporarily unavailable');
      } else {
        throw WikipediaException('Failed to fetch content. Status: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No internet connection');
    } catch (e) {
      throw WikipediaException('Error fetching Wikipedia content: $e');
    }
  }
}

// Custom exceptions
class WikipediaException implements Exception {
  final String message;
  WikipediaException(this.message);
  @override
  String toString() => message;
}

class WikipediaNotFoundException extends WikipediaException {
  WikipediaNotFoundException(String message) : super(message);
}

class WikipediaServiceException extends WikipediaException {
  WikipediaServiceException(String message) : super(message);
}

class NetworkException extends WikipediaException {
  NetworkException(String message) : super(message);
}
```

---

## Title Matching Strategy

When searching for Wikipedia articles based on location names:

1. **Try exact location name first**: `"Paris"`
2. **If 404, try with country**: `"Paris, France"`
3. **If still 404, accept failure**: Show "No information available"

**Why this approach?**
- Most major cities have Wikipedia pages with simple names ("Paris", "London")
- Adding country helps disambiguate (Paris, France vs Paris, Texas)
- Two attempts max to avoid excessive API calls

**Implementation**:
```dart
Future<WikipediaContent> getContent(Location location) async {
  try {
    // First attempt: just city name
    return await _fetchContent(location.name);
  } on WikipediaNotFoundException {
    try {
      // Second attempt: city + country
      return await _fetchContent('${location.name}, ${location.country}');
    } on WikipediaNotFoundException {
      // Give up
      throw WikipediaNotFoundException('No Wikipedia page found for ${location.displayName}');
    }
  }
}
```

---

## Contract Summary

**Endpoint**: `GET https://en.wikipedia.org/api/rest_v1/page/summary/{title}`

**Authentication**: None

**Rate Limit**: 200 req/sec (no concerns)

**Key Requirements**:
- URL-encode title parameter
- Handle 404 gracefully (common for small locations)
- Check `type` field for disambiguation pages
- Handle null `thumbnail` field

**Response**: JSON object with title, extract, thumbnail, and full article URL

**Error Handling**: 404 (not found), 503 (unavailable), disambiguation pages

**Ready for Implementation**: ✅

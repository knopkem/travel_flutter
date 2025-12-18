# Research: Location Search & Wikipedia Browser
*Path: kitty-specs/001-location-search-wikipedia/research.md*

**Feature**: Location Search & Wikipedia Browser
**Date**: 2025-12-12
**Status**: Complete

## Overview

This document consolidates research findings for implementing a Flutter mobile app with city search and Wikipedia content display. Focus areas: Nominatim geocoding API, Wikipedia REST API, Provider state management, and debouncing strategies.

---

## 1. Nominatim Geocoding API

### Decision
Use OpenStreetMap Nominatim free geocoding service for city search autocomplete.

### API Details

**Endpoint**: `https://nominatim.openstreetmap.org/search`

**Query Parameters**:
- `q` - Search query (e.g., "Paris")
- `format=json` - Response format
- `limit=5` - Maximum results (5-10 recommended for autocomplete)
- `addressdetails=1` - Include detailed address components
- `featuretype=city` - Filter for cities/towns (optional but recommended)

**Example Request**:
```
https://nominatim.openstreetmap.org/search?q=Paris&format=json&limit=5&addressdetails=1
```

**Response Structure**:
```json
[
  {
    "place_id": 240109189,
    "licence": "Data © OpenStreetMap contributors, ODbL 1.0...",
    "osm_type": "relation",
    "osm_id": 7444,
    "lat": "48.8588897",
    "lon": "2.3200410217200766",
    "display_name": "Paris, Île-de-France, France métropolitaine, France",
    "address": {
      "city": "Paris",
      "county": "Paris",
      "state": "Île-de-France",
      "country": "France",
      "country_code": "fr"
    }
  }
]
```

**Rate Limits**:
- Maximum 1 request per second
- Must include User-Agent header
- Bulk usage requires dedicated server setup

**Error Handling**:
- Empty array `[]` when no results
- HTTP 429 if rate limit exceeded
- HTTP 503 if service unavailable

### Rationale
- Free service with no API key requirements
- Comprehensive global coverage
- Well-documented REST API
- Returns structured address data including country
- Rate limits manageable with 300ms debouncing

### Alternatives Considered
- **Google Places Autocomplete API**: Excellent quality but requires API key, billing setup, and costs money at scale. Rejected for complexity.
- **Mapbox Geocoding API**: Good free tier (100k requests/month) but requires API key. Rejected to minimize setup.
- **GeoNames**: Free but less accurate geocoding. Rejected for quality concerns.

### Implementation Notes
- Debounce user input by 300ms to comply with 1 req/sec limit
- Include User-Agent header: "TravelFlutterApp/1.0"
- Handle empty results gracefully with "No locations found" message
- Parse `display_name` for UI display
- Extract `address.city` and `address.country` for structured data
- Store `osm_id` for Wikipedia lookup correlation

---

## 2. Wikipedia REST API

### Decision
Use Wikipedia REST API v1 for retrieving city information and summaries.

### API Details

**Endpoint**: `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`

**Path Parameters**:
- `title` - Wikipedia page title (URL-encoded, e.g., "Paris" or "Paris,_France")

**Example Request**:
```
https://en.wikipedia.org/api/rest_v1/page/summary/Paris
```

**Response Structure**:
```json
{
  "type": "standard",
  "title": "Paris",
  "displaytitle": "Paris",
  "extract": "Paris is the capital and most populous city of France...",
  "extract_html": "<p>Paris is the capital...</p>",
  "thumbnail": {
    "source": "https://upload.wikimedia.org/...",
    "width": 320,
    "height": 213
  },
  "originalimage": {...},
  "content_urls": {
    "desktop": {
      "page": "https://en.wikipedia.org/wiki/Paris"
    },
    "mobile": {...}
  }
}
```

**Key Fields**:
- `title` - Page title
- `extract` - Plain text summary (first paragraph)
- `extract_html` - HTML formatted summary
- `thumbnail.source` - Image URL (if available)
- `content_urls.desktop.page` - Full article URL

**Error Handling**:
- HTTP 404 when page not found
- HTTP 503 if service unavailable
- Disambiguation pages return `type: "disambiguation"`

### Rationale
- Free, no API key required
- REST API is simpler than MediaWiki API
- Returns clean summary text perfect for mobile display
- Includes thumbnail images for visual appeal
- Well-maintained by Wikimedia Foundation

### Alternatives Considered
- **MediaWiki API**: More powerful but complex query syntax. Rejected for simplicity.
- **DBpedia**: Structured data but requires SPARQL knowledge. Rejected as overkill.
- **Direct Wikipedia scraping**: Against ToS and fragile. Rejected.

### Implementation Notes
- URL-encode location names before API call
- Handle disambiguation pages by showing "Multiple results found" message
- Display `extract` text in ScrollView for long content
- Show thumbnail image if available
- Provide "View full article" link to `content_urls.desktop.page`
- Cache responses in WikipediaProvider to avoid redundant requests during navigation

---

## 3. Provider State Management Pattern

### Decision
Use Provider package (official Flutter recommendation) for state management.

### Architecture Pattern

**Provider Structure**:

1. **LocationProvider** - Manages selected locations
   ```dart
   class LocationProvider extends ChangeNotifier {
     List<Location> _locations = [];
     
     List<Location> get locations => _locations;
     
     void addLocation(Location location) {
       _locations.add(location);
       notifyListeners();
     }
   }
   ```

2. **WikipediaProvider** - Manages Wikipedia content loading
   ```dart
   class WikipediaProvider extends ChangeNotifier {
     WikipediaContent? _content;
     bool _isLoading = false;
     String? _error;
     
     Future<void> fetchContent(String locationName) async {
       _isLoading = true;
       notifyListeners();
       // ... API call
       _isLoading = false;
       notifyListeners();
     }
   }
   ```

**Dependency Injection**:
- Pass repositories to providers via constructor
- Use `MultiProvider` in `main.dart` to provide both providers
- Repositories remain stateless, providers manage state

### Rationale
- Official Flutter recommendation for simple to medium complexity
- Well-documented and widely adopted
- Minimal boilerplate compared to BLoC
- ChangeNotifier pattern is easy to understand
- Good performance for this scale (2 screens, simple state)

### Alternatives Considered
- **BLoC**: More structured but overkill for this simple feature. Rejected for complexity.
- **Riverpod**: Modern but adds learning curve. Provider is sufficient. Rejected.
- **setState**: Too limited for managing shared state across screens. Rejected.
- **GetX**: Not official, introduces magic. Rejected.

### Implementation Notes
- Wrap `MaterialApp` with `MultiProvider`
- Use `context.watch<LocationProvider>()` for reactive UI
- Use `context.read<LocationProvider>()` for one-time actions
- Separate search state (temporary) from selected locations (persistent)

---

## 4. Debouncing Search Input

### Decision
Implement custom debouncing using Dart Timer to delay API calls until user stops typing.

### Implementation Strategy

**Debounce Logic**:
```dart
Timer? _debounceTimer;

void onSearchTextChanged(String query) {
  _debounceTimer?.cancel();
  
  if (query.isEmpty) {
    // Clear suggestions immediately
    return;
  }
  
  _debounceTimer = Timer(Duration(milliseconds: 300), () {
    // Make API call
    fetchSuggestions(query);
  });
}
```

**Key Points**:
- Cancel previous timer on each keystroke
- Wait 300ms after last keystroke before API call
- Clear suggestions immediately when query is empty
- Dispose timer in widget's dispose() method

### Rationale
- Reduces API calls from potentially dozens to ~1 per search phrase
- Complies with Nominatim 1 req/sec rate limit
- Improves UX by reducing visual flickering
- Simple implementation with no external dependencies
- 300ms feels responsive to users

### Alternatives Considered
- **rxdart package**: Provides debounce operators but adds dependency. Rejected for simplicity.
- **easy_debounce package**: Third-party package for same functionality. Rejected to minimize dependencies.
- **No debouncing**: Would violate Nominatim rate limits. Rejected.

### Implementation Notes
- Debounce implemented in search widget or dedicated search provider
- Show loading indicator during debounce period
- Cancel ongoing requests if new search initiated
- Handle edge case: user types, waits 300ms, types again before response

---

## 5. Error Handling & User Feedback

### Decision
Implement comprehensive error handling with user-friendly messages for all failure scenarios.

### Error Categories

**Network Errors**:
- No internet connection → "No internet connection. Please check your network."
- API timeout → "Request timed out. Please try again."
- API unavailable (5xx) → "Service temporarily unavailable. Please try again later."

**Data Errors**:
- No search results → "No locations found. Try a different search term."
- Wikipedia page not found → "No information available for this location."
- Rate limit exceeded → "Too many requests. Please wait a moment and try again."

**UI Implementation**:
- Show `SnackBar` for transient errors (network, rate limit)
- Display centered message widget for empty states (no results, no content)
- Use `CircularProgressIndicator` during loading
- Preserve user's location list even if detail view fails

### Rationale
- Clear communication prevents user confusion
- Actionable messages when possible (check network, try again)
- Graceful degradation (location list persists even if Wikipedia fails)
- Follows Material Design error patterns

---

## 6. Flutter Project Structure Best Practices

### Decision
Organize code by feature/layer: screens, widgets, providers, repositories, models.

### Directory Organization

```
lib/
├── main.dart              # App entry, provider setup
├── screens/               # Full-screen widgets
├── widgets/               # Reusable UI components
├── providers/             # State management
├── repositories/          # API clients (data layer)
└── models/                # Data classes
```

### File Naming Conventions
- All files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `lowerCamelCase` or `SCREAMING_SNAKE_CASE` for compile-time constants

### Rationale
- Clear separation of concerns
- Easy to locate files by responsibility
- Scales well as app grows
- Follows Flutter community conventions
- Repository pattern separates data access from business logic

---

## 7. HTTP Client Selection

### Decision
Use official `http` package for API calls.

### Rationale
- Official Dart package maintained by Dart team
- Simple API for basic GET requests
- No overhead for features we don't need (interceptors, FormData)
- Well-documented and widely used
- Sufficient for this app's needs (simple GET requests)

### Alternatives Considered
- **dio**: More features (interceptors, FormData, cancellation) but overkill. Rejected.
- **chopper**: Code generation approach, adds build complexity. Rejected.

### Implementation Notes
```dart
import 'package:http/http.dart' as http;

final response = await http.get(
  Uri.parse('https://nominatim.openstreetmap.org/search?q=Paris&format=json'),
  headers: {'User-Agent': 'TravelFlutterApp/1.0'},
);
```

---

## Summary of Key Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Geocoding API | Nominatim (OSM) | Free, no API key, good coverage |
| Wikipedia API | REST API v1 | Simple, free, returns clean summaries |
| State Management | Provider | Official recommendation, right complexity |
| Debouncing | Custom Timer | Simple, no dependencies, 300ms delay |
| HTTP Client | http package | Official, sufficient for GET requests |
| Error Handling | User-friendly messages | Clear communication, graceful degradation |
| Project Structure | Feature/layer organization | Community standard, scalable |

---

## Open Questions (None)

All technical questions resolved during planning interrogation. Ready for Phase 1 design.

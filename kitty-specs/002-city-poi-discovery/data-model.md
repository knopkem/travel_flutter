# Data Model: City POI Discovery & Detail View

**Feature**: 002-city-poi-discovery  
**Date**: 2025-12-18  
**Status**: Complete

## Overview

This document defines the data entities, their relationships, and state management for the POI discovery feature. The model extends the existing architecture while refactoring from multi-city to single-city selection.

---

## Core Entities

### 1. City (Modified)

**Purpose**: Represents the currently selected city for exploration

**Changes from Feature 001**:
- Context change: From "one of many selected" to "the single active city"
- No structural changes to model itself
- Usage changes in LocationProvider (no longer a list)

**Attributes**:
```dart
class City {
  final String id;              // OpenStreetMap ID
  final String name;            // e.g., "Paris"
  final String country;         // e.g., "France"
  final String displayName;     // e.g., "Paris, France"
  final double latitude;        // Range: -90 to 90
  final double longitude;       // Range: -180 to 180
}
```

**Validation Rules**:
- `id` must be unique (OSM ID)
- `latitude` must be between -90 and 90
- `longitude` must be between -180 and 180
- `name`, `country`, `displayName` cannot be empty

**Relationships**:
- Has one WikipediaContent (full article)
- Has many POIs (discovered nearby)

**State in Provider**:
```dart
// LocationProvider
City? _selectedCity;  // Changed from List<Location> _selectedLocations
```

---

### 2. POI (Point of Interest) - NEW

**Purpose**: Represents a notable place, attraction, or landmark near the selected city

**Attributes**:
```dart
class POI {
  final String id;                    // Unique identifier (generated)
  final String name;                  // e.g., "Eiffel Tower"
  final String type;                  // e.g., "monument", "museum", "landmark"
  final double latitude;
  final double longitude;
  final double distanceFromCity;      // Meters from city center
  final List<POISource> sources;      // Which APIs provided this POI
  final String? description;          // Short description (optional)
  final String? wikipediaTitle;       // For fetching full article (optional)
  final String? imageUrl;             // Thumbnail image (optional)
  final int notabilityScore;          // For sorting (higher = more notable)
  final DateTime discoveredAt;        // When added to list
}
```

**Validation Rules**:
- `id` must be unique within POI list
- `latitude` and `longitude` must be valid coordinates
- `distanceFromCity` must be non-negative
- `sources` cannot be empty (POI must come from at least one source)
- `type` must be one of predefined types (see POIType enum)
- `notabilityScore` must be 0-100

**Derived Fields**:
- `id`: Generated from coordinate hash + name hash (for consistency across sources)
- `distanceFromCity`: Calculated via Haversine formula
- `notabilityScore`: Calculated from source data (Wikipedia page views, Wikidata statements)

**Relationships**:
- Belongs to one City (implicit via POIProvider)
- Can have one WikipediaContent (if `wikipediaTitle` is set)
- Has one or more POISource entries

**State Transitions**:
```
[Discovered] → [Deduplicated] → [Displayed] → [Selected] → [Details Loaded]
```

**Factory Methods**:
```dart
// Create from Wikipedia Geosearch
factory POI.fromWikipediaGeosearch(Map<String, dynamic> json, City city);

// Create from Overpass API
factory POI.fromOverpass(Map<String, dynamic> json, City city);

// Create from Wikidata
factory POI.fromWikidata(Map<String, dynamic> json, City city);

// Merge duplicate POIs from multiple sources
factory POI.merge(List<POI> duplicates);
```

---

### 3. POISource (Enum) - NEW

**Purpose**: Tracks which data source(s) provided information about a POI

**Values**:
```dart
enum POISource {
  wikipediaGeosearch,  // Wikipedia Geosearch API
  overpass,            // OpenStreetMap Overpass API
  wikidata,            // Wikidata SPARQL Query Service
}
```

**Usage**:
- POI can have multiple sources if found by multiple APIs
- Used in deduplication to prefer certain sources (Wikipedia > Wikidata > OSM)
- Helps debug data quality issues

---

### 4. POIType (Enum) - NEW

**Purpose**: Categorizes POIs by their function/purpose

**Values**:
```dart
enum POIType {
  monument,           // Historical monuments, statues
  museum,             // Art, history, science museums
  landmark,           // Famous buildings, structures
  religiousSite,      // Churches, temples, mosques
  park,               // Parks, gardens
  viewpoint,          // Scenic overlooks
  touristAttraction,  // General attractions
  historicSite,       // Archaeological sites, ruins
  square,             // Public squares, plazas
  other,              // Miscellaneous POIs
}
```

**Mapping from Source Tags**:
```dart
// OpenStreetMap tags → POIType
'tourism=monument' → POIType.monument
'tourism=museum' → POIType.museum
'tourism=attraction' → POIType.touristAttraction
'tourism=viewpoint' → POIType.viewpoint
'historic=monument' → POIType.monument
'historic=castle' → POIType.historicSite
'leisure=park' → POIType.park
'amenity=place_of_worship' → POIType.religiousSite

// Wikidata instance types → POIType
Q33506 (museum) → POIType.museum
Q4989906 (monument) → POIType.monument
Q570116 (tourist attraction) → POIType.touristAttraction
```

---

### 5. WikipediaContent (Enhanced)

**Purpose**: Stores Wikipedia article content (now supports full articles, not just summaries)

**Existing Attributes** (unchanged):
```dart
class WikipediaContent {
  final String title;
  final String summary;          // Short extract (first paragraph)
  final String? extractHtml;     // HTML version of summary
  final String? thumbnailUrl;
  final String pageUrl;
}
```

**New Attributes**:
```dart
class WikipediaContent {
  // ... existing attributes ...
  final String? fullContent;           // NEW: Complete article HTML
  final List<ArticleSection>? sections; // NEW: Parsed article sections
  final DateTime fetchedAt;            // NEW: Cache timestamp
  final bool isFullArticle;            // NEW: true if fullContent loaded
}
```

**New Model: ArticleSection** - NEW
```dart
class ArticleSection {
  final String title;         // Section heading (e.g., "History", "Geography")
  final int level;            // Heading level (1-6)
  final String content;       // Section HTML content
  final int order;            // Display order
}
```

**Factory Methods**:
```dart
// Existing (from REST API summary endpoint)
factory WikipediaContent.fromJson(Map<String, dynamic> json);

// NEW: From mobile-html endpoint
factory WikipediaContent.fromMobileHtml(String html, String title, String pageUrl);
```

---

## State Management

### LocationProvider (Refactored)

**Purpose**: Manages single city selection and search

**State Changes**:
```dart
// OLD (Feature 001)
class LocationProvider extends ChangeNotifier {
  List<LocationSuggestion> _suggestions = [];
  final List<Location> _selectedLocations = [];  // Multiple cities
  
  bool selectLocation(LocationSuggestion suggestion) {
    // Add to list, check for duplicates
  }
  
  void removeLocation(String locationId) {
    // Remove from list
  }
}

// NEW (Feature 002)
class LocationProvider extends ChangeNotifier {
  List<LocationSuggestion> _suggestions = [];
  City? _selectedCity;  // Single city only
  
  void selectCity(LocationSuggestion suggestion) {
    // Replace current city, notify listeners
    _selectedCity = suggestion.toCity();
    notifyListeners();
  }
  
  void clearCity() {
    _selectedCity = null;
    notifyListeners();
  }
}
```

**Key Methods**:
- `searchLocations(String query)` - Unchanged
- `selectCity(LocationSuggestion)` - Replaces selectLocation, no duplicate checking
- `clearCity()` - New: Clears the current city
- `City? get selectedCity` - New: Getter for active city

**State Transitions**:
```
[No City] → [City Selected] → [Different City Selected] → [No City]
```

---

### POIProvider - NEW

**Purpose**: Manages POI discovery, deduplication, and caching for the selected city

**State**:
```dart
class POIProvider extends ChangeNotifier {
  final Map<String, List<POI>> _poiCache;  // Keyed by city ID
  List<POI> _currentPOIs = [];
  bool _isLoading = false;
  String? _errorMessage;
  POILoadingPhase _loadingPhase = POILoadingPhase.none;
}

enum POILoadingPhase {
  none,
  initial,      // Wikipedia Geosearch loading
  enriching,    // Overpass + Wikidata loading
  complete,
}
```

**Key Methods**:
```dart
Future<void> discoverPOIs(City city);
void _fetchInitialPOIs(City city);  // Wikipedia Geosearch
void _fetchAdditionalPOIs(City city);  // Overpass + Wikidata in parallel
List<POI> _deduplicate(List<POI> pois);
void clearPOIs();
POI? getPOIById(String id);
```

**Progressive Loading Flow**:
```dart
discoverPOIs(city):
  1. Check cache → return if exists
  2. Set _loadingPhase = POILoadingPhase.initial
  3. Call _fetchInitialPOIs(city)
     - Wikipedia Geosearch
     - Add to _currentPOIs, notifyListeners
  4. Set _loadingPhase = POILoadingPhase.enriching
  5. Call _fetchAdditionalPOIs(city)
     - Future.wait([overpass, wikidata])
     - Merge + deduplicate as each completes
     - notifyListeners after each source
  6. Final deduplication pass
  7. Cache result, set _loadingPhase = POILoadingPhase.complete
  8. notifyListeners
```

---

### WikipediaProvider (Enhanced)

**Purpose**: Manages Wikipedia content caching (now supports full articles)

**State Changes**:
```dart
// Existing
final Map<String, WikipediaContent> _content = {};  // Keyed by title

// Enhanced methods
Future<void> fetchContent(String title) {
  // Fetch summary only (existing behavior)
}

// NEW
Future<void> fetchFullArticle(String title) {
  // Fetch complete article via mobile-html endpoint
}
```

**Key Methods**:
- `fetchContent(String title)` - Existing: Fetch summary
- `fetchFullArticle(String title)` - NEW: Fetch full article
- `WikipediaContent? getContent(String title)` - Existing: Retrieve cached
- `clearCache()` - NEW: Clear all cached content

---

## Repository Interfaces

### POIRepository - NEW

**Purpose**: Common interface for all POI data sources

```dart
abstract class POIRepository {
  /// Fetch POIs near the given coordinates within the specified radius
  Future<List<POI>> fetchNearbyPOIs(
    double latitude,
    double longitude,
    double radiusKm,
  );
  
  /// Dispose of any resources (HTTP clients)
  void dispose();
}
```

**Implementations**:
1. `WikipediaGeosearchRepository implements POIRepository`
2. `OverpassRepository implements POIRepository`
3. `WikidataRepository implements POIRepository`

---

## Data Flow Diagrams

### POI Discovery Flow

```
[User Selects City]
        ↓
[LocationProvider.selectCity()]
        ↓
[Triggers POIProvider.discoverPOIs()]
        ↓
[Wikipedia Geosearch Request] → [Initial POIs] → [UI Updates (2s)]
        ↓
[Parallel: Overpass + Wikidata Requests]
        ↓
[Merge Results] → [Deduplicate] → [UI Updates (3-5s)]
        ↓
[Cache POIs] → [Complete]
```

### POI Detail Flow

```
[User Taps POI in List]
        ↓
[Navigate to POIDetailScreen]
        ↓
[Check if POI has wikipediaTitle]
   ├─ Yes → [WikipediaProvider.fetchFullArticle(title)]
   │         ↓
   │   [Display Full Article with Sections]
   │
   └─ No → [Display POI data from discovery]
           ↓
      [Show available description, image, type]
```

### City Switch Flow

```
[User Searches New City]
        ↓
[LocationProvider.selectCity(newCity)]
        ↓
[POIProvider.clearPOIs()] (cancels in-flight requests)
        ↓
[POIProvider.discoverPOIs(newCity)]
        ↓
[UI Updates with New City POIs]
```

---

## Validation & Constraints

### City
- ✅ Valid OSM ID format
- ✅ Coordinates within Earth bounds
- ✅ Non-empty name/country

### POI
- ✅ Unique ID within city context
- ✅ Valid coordinates
- ✅ Distance ≤ 10km from city center
- ✅ At least one source
- ✅ Notability score 0-100

### WikipediaContent
- ✅ Valid Wikipedia title (no special characters except spaces, underscores)
- ✅ Page URL must be valid HTTPS URL
- ✅ If isFullArticle=true, fullContent must not be null

---

## Caching Strategy

### In-Memory Caches

**POIProvider Cache**:
```dart
Map<String, List<POI>> _poiCache;  // Key: City ID
// Max size: 10 cities (LRU eviction)
// Lifetime: Session only (cleared on app restart)
```

**WikipediaProvider Cache**:
```dart
Map<String, WikipediaContent> _content;  // Key: Wikipedia title
// Max size: 50 articles
// Lifetime: Session only
// Contains both summaries and full articles
```

**Cache Invalidation**:
- City cache: Never (POIs don't change during session)
- Wikipedia cache: Never (articles don't change frequently)
- Full clear on app restart (no persistence)

---

## Error Handling

### POI Discovery Errors
- **One source fails**: Continue with other sources, log error
- **All sources fail**: Show error message, provide retry button
- **Network timeout**: Individual source 10s timeout, total 30s max
- **Invalid response**: Skip that source, use other sources

### Wikipedia Content Errors
- **Full article unavailable**: Fall back to summary
- **Network error**: Show error with retry
- **Invalid HTML**: Show raw summary text

### Coordinate Errors
- **Invalid coordinates**: Skip that POI, log warning
- **Distance calculation overflow**: Use infinity, sort to end

---

## Performance Considerations

### Memory
- POI cache: ~500 KB per city × 10 cities = ~5 MB
- Wikipedia cache: ~100 KB per article × 50 articles = ~5 MB
- Total: ~10 MB acceptable for mobile

### Network
- POI discovery: 3 requests × ~50 KB = ~150 KB per city
- Full Wikipedia article: ~100 KB
- Total: ~250 KB per city visit (acceptable for 4G/5G)

### CPU
- Deduplication: O(n²) with n ≤ 150 POIs = ~22,500 comparisons
- Haversine calculation: ~0.01 ms each = ~225 ms total
- Acceptable latency: <300ms for deduplication

---

## Testing Strategy

### Unit Tests
- City model validation
- POI model validation and factory methods
- WikipediaContent parsing (summary and full article)
- Deduplication algorithm with known duplicates
- Haversine distance calculation with known coordinates

### Integration Tests
- Repository implementations with real API calls
- POIProvider progressive loading behavior
- LocationProvider single-city state transitions
- Cache behavior and LRU eviction

### Widget Tests
- POI list rendering with mock data
- Progressive loading UI states
- Empty state handling
- Error state handling

---

## Migration from Feature 001

### Breaking Changes
1. `LocationProvider.selectedLocations` → `LocationProvider.selectedCity`
2. `selectLocation()` → `selectCity()`
3. `removeLocation()` → `clearCity()`

### UI Updates Required
1. Remove SelectedLocationsList widget (no multi-select)
2. Update HomeScreen to show single city + POI list
3. Update LocationDetailScreen to show full Wikipedia content
4. Add POIListScreen and POIDetailScreen

### Data Migration
- No persistent data to migrate (in-memory only)
- User starts fresh with new single-city model

---

## Status

✅ All entities defined  
✅ Relationships documented  
✅ State management specified  
✅ Validation rules established  
✅ Caching strategy documented  
✅ Performance characteristics acceptable  

**Ready for**: Contract definitions (Phase 1 continued)

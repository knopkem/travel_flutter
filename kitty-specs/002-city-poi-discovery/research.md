# Research: City POI Discovery & Detail View

**Feature**: 002-city-poi-discovery  
**Date**: 2025-12-18  
**Status**: Complete

## Research Overview

This document captures technical research for implementing POI (Point of Interest) discovery from multiple free data sources with intelligent deduplication and progressive loading.

## Key Research Areas

### 1. Wikipedia Full Article Content Fetching

**Decision**: Use Wikipedia REST API v1 with different parsing strategy

**Rationale**:
- Current implementation uses `/page/summary/{title}` endpoint which returns only extract/introduction
- Wikipedia REST API provides `/page/mobile-html/{title}` endpoint for full formatted content
- Alternative: `/page/html/{title}` returns desktop HTML (heavier but more complete)
- For mobile app, `/page/mobile-html/{title}` is optimal (formatted for mobile, includes all sections)

**Implementation Approach**:
- Modify RestWikipediaRepository to add new method `fetchFullArticle(String title)`
- Parse mobile-html response to extract sections (history, geography, culture, etc.)
- Keep existing `fetchSummary()` method as fallback for error cases
- Cache full content in WikipediaProvider using same strategy as summaries

**API Example**:
```
GET https://en.wikipedia.org/api/rest_v1/page/mobile-html/Paris
Response: Full HTML content with all article sections
```

**Alternatives Considered**:
- MediaWiki Action API (`action=parse`): More complex, requires HTML parsing
- Wikimedia content API: Similar to REST API but less mobile-optimized
- Third-party Wikipedia libraries: Adds dependency, not needed for simple HTTP calls

---

### 2. OpenStreetMap Overpass API for POI Discovery

**Decision**: Use Overpass API with `node/way` queries filtered by tourism tags

**Rationale**:
- Overpass API is the standard query interface for OpenStreetMap data
- Free to use, no API key required (similar to Nominatim)
- Supports radius-based searches around coordinates
- Rich tagging system for POI types (tourism=*, historic=*, amenity=*)
- Rate limit: ~10,000 queries per day, practical 1 req/sec limit

**Implementation Approach**:
- Create OverpassRepository implementing new POIRepository interface
- Query structure: Search for nodes/ways within 10km radius with POI tags
- Filter tags: `tourism=attraction|museum|monument|viewpoint`, `historic=*`, `amenity=place_of_worship`
- Return format: JSON with name, coordinates, type, OSM ID
- Timeout: 10 seconds per query
- Email parameter in request (same as Nominatim compliance)

**Query Example**:
```
[out:json][timeout:10];
(
  node["tourism"~"attraction|museum|monument|viewpoint"](around:10000,48.8566,2.3522);
  node["historic"](around:10000,48.8566,2.3522);
  way["tourism"~"attraction|museum|monument"](around:10000,48.8566,2.3522);
);
out body;
>;
out skel qt;
```

**Alternatives Considered**:
- Direct OSM API: Not designed for complex queries, rate limits too restrictive
- Nominatim search with POI types: Returns places but not as comprehensive as Overpass
- OSM data dumps: Overkill for dynamic queries, requires local database

---

### 3. Wikipedia Geosearch API for Nearby Articles

**Decision**: Use MediaWiki Action API `geosearch` for articles with coordinates

**Rationale**:
- Wikipedia articles about notable places include coordinate metadata
- Geosearch returns articles within radius of given coordinates
- Free, no API key, reasonable rate limits
- Complements Overpass by providing Wikipedia-documented POIs
- Returns page titles that can be used to fetch article content

**Implementation Approach**:
- Create WikipediaGeosearchRepository implementing POIRepository interface
- Use `action=query` with `list=geosearch` parameter
- Search within 10km radius, limit to 50 results
- Filter for pages in main namespace (avoid meta pages)
- Return: title, coordinates, page ID, distance from center

**API Example**:
```
GET https://en.wikipedia.org/w/api.php?action=query&list=geosearch
    &gscoord=48.8566|2.3522&gsradius=10000&gslimit=50&format=json
```

**Response Format**:
```json
{
  "query": {
    "geosearch": [
      {"pageid": 22989, "title": "Eiffel Tower", "lat": 48.8584, "lon": 2.2945, "dist": 1234.5},
      ...
    ]
  }
}
```

**Alternatives Considered**:
- Wikivoyage API: Travel-focused but less comprehensive than main Wikipedia
- GeoNames: Separate service, requires account
- DBpedia SPARQL: More complex, unnecessary for simple coordinate queries

---

### 4. Wikidata SPARQL Query Service for Structured POI Data

**Decision**: Use Wikidata Query Service with SPARQL for notable places

**Rationale**:
- Wikidata provides structured data about notable locations
- SPARQL queries can filter by coordinates and instance types
- Free, no API key required
- Includes notability indicators (sitelinks count, statements count)
- Cross-referenced with Wikipedia articles

**Implementation Approach**:
- Create WikidataRepository implementing POIRepository interface
- SPARQL query to find items (places) within radius
- Filter by instance types: tourist attraction (Q570116), museum (Q33506), monument (Q4989906)
- Extract: label, coordinates, Wikipedia article link, notability metrics
- Timeout: 10 seconds
- Return standardized POI objects

**Query Example**:
```sparql
SELECT DISTINCT ?place ?placeLabel ?coord ?article WHERE {
  ?place wdt:P625 ?coord.
  ?place (wdt:P31/wdt:P279*) wd:Q570116.  # tourist attraction
  ?article schema:about ?place;
           schema:inLanguage "en";
           schema:isPartOf <https://en.wikipedia.org/>.
  SERVICE wikibase:around {
    ?place wdt:P625 ?coord.
    bd:serviceParam wikibase:center "Point(2.3522 48.8566)"^^geo:wktLiteral.
    bd:serviceParam wikibase:radius "10".
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 50
```

**Alternatives Considered**:
- Wikidata API (not SPARQL): Less powerful for coordinate-based searches
- Wikidata dumps: Requires local processing, overkill
- OpenStreetMap + Wikidata linking: More complex, unnecessary duplication

---

### 5. POI Deduplication Strategy

**Decision**: Two-phase deduplication using coordinate proximity + name similarity

**Rationale**:
- Different sources often have same POI with slight name variations
- Coordinate proximity is most reliable indicator (POIs can't move)
- Name similarity handles typos and formatting differences
- Prefer Wikipedia entries (better descriptions) over other sources

**Implementation Approach**:

**Phase 1: Coordinate Proximity Matching**
- Use Haversine formula to calculate distance between coordinates
- Threshold: 50 meters (spec requirement)
- Group POIs within threshold as potential duplicates
- Algorithm: O(n²) comparison acceptable for 100-200 POIs per city

**Phase 2: Name Similarity Scoring**
- For POIs within proximity threshold, calculate name similarity
- Use Levenshtein distance or simpler approach: normalized token overlap
- Example: "Eiffel Tower" vs "The Eiffel Tower" = high similarity
- Threshold: 70% similarity or higher
- If names match, keep entry with more complete data (prefer Wikipedia)

**Priority When Merging Duplicates**:
1. Wikipedia Geosearch entry (has article, usually best description)
2. Wikidata entry (structured data, notability metrics)
3. OpenStreetMap entry (good coordinates, may lack description)

**Code Structure**:
```dart
class POIDeduplicator {
  List<POI> deduplicate(List<POI> pois) {
    // Phase 1: Group by proximity
    Map<String, List<POI>> proximityGroups = _groupByProximity(pois, 50);
    
    // Phase 2: Within groups, merge by name similarity
    List<POI> deduplicated = [];
    for (var group in proximityGroups.values) {
      deduplicated.add(_mergeGroup(group));
    }
    
    return deduplicated;
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula implementation
  }
  
  double _calculateNameSimilarity(String name1, String name2) {
    // Token overlap or Levenshtein distance
  }
  
  POI _mergeGroup(List<POI> group) {
    // Prefer Wikipedia > Wikidata > OSM
    // Merge descriptions, images, etc.
  }
}
```

**Alternatives Considered**:
- Name-only matching: Too many false positives ("Tower" appears in many names)
- Strict coordinate matching: GPS variance causes false negatives
- Manual curation: Not scalable
- Third-party deduplication services: Unnecessary complexity

---

### 6. Progressive Loading Strategy

**Decision**: Wikipedia Geosearch first, then parallel Overpass + Wikidata

**Rationale**:
- Wikipedia Geosearch is fastest (simple HTTP request, lightweight JSON)
- Provides immediate value: show popular POIs with Wikipedia articles first
- Overpass and Wikidata are slower (complex queries, larger responses)
- Parallel fetching of slower sources maximizes efficiency
- User sees results progressively populate (better UX than 5-second blank screen)

**Implementation Approach**:

**Phase 1: Initial Fast Load (0-2 seconds)**
```dart
// In POIProvider.fetchPOIs(City city)
1. Set loading = true
2. Call wikipediaGeosearchRepo.fetchNearbyPOIs(city.coordinates, 10km)
3. Display results immediately (notifyListeners)
4. Mark as "loading more..."
```

**Phase 2: Comprehensive Load (2-5 seconds)**
```dart
5. Parallel calls:
   - Future.wait([
       overpassRepo.fetchNearbyPOIs(city.coordinates, 10km),
       wikidataRepo.fetchNearbyPOIs(city.coordinates, 10km)
     ])
6. As each completes, merge + deduplicate + notifyListeners
7. Final deduplication pass
8. Set loading = false
```

**Benefits**:
- First POIs visible in ~2 seconds (Wikipedia)
- Complete list by 5 seconds (all sources)
- User can start browsing while data loads
- Graceful degradation if sources fail

**Alternatives Considered**:
- Sequential loading: Too slow (10-15 seconds total)
- All parallel: No fast initial results
- Single source only: Incomplete POI coverage
- Overpass first: Slower than Wikipedia, same initial delay

---

### 7. Haversine Distance Calculation

**Decision**: Implement standard Haversine formula for coordinate distances

**Rationale**:
- Industry-standard algorithm for calculating distances on a sphere
- Accurate enough for 10km radius searches (Earth curvature matters at this scale)
- Simple to implement, no external dependencies
- Used for both POI proximity searches and deduplication

**Implementation**:
```dart
class GeoUtils {
  static const double earthRadiusKm = 6371.0;
  
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c * 1000; // Return meters
  }
  
  static double _toRadians(double degrees) => degrees * pi / 180;
}
```

**Alternatives Considered**:
- Great circle distance: Equivalent to Haversine for our use case
- Vincenty formula: More accurate but unnecessary complexity for 10km radius
- Simple coordinate difference: Inaccurate, Earth is curved
- Third-party geospatial library: Adds dependency for simple calculation

---

## API Rate Limits Summary

| Data Source | Rate Limit | Compliance Strategy |
|-------------|------------|---------------------|
| Nominatim | 1 req/sec | Already implemented with delay in existing repo |
| Overpass API | ~1 req/sec (soft) | Implement similar delay, add email parameter |
| Wikipedia APIs | No strict limit | Reasonable usage, no special handling needed |
| Wikidata SPARQL | No strict limit | 10-second timeout, monitor for 429 responses |

**Implementation**: Create RateLimiter utility class for Overpass (similar to Nominatim's existing implementation).

---

## Testing Strategy

### Unit Tests
- POI model validation (coordinates, required fields)
- Deduplication algorithm (proximity + name matching)
- Haversine distance calculation (known coordinate pairs)
- Repository response parsing (mock HTTP responses)

### Integration Tests
- Real API calls to Wikipedia Geosearch (verify response parsing)
- Real API calls to Overpass (verify query works)
- Real API calls to Wikidata SPARQL (verify SPARQL syntax)
- Rate limit compliance (verify delays)

### Widget Tests
- Progressive loading UI (skeleton states)
- POI list display (with mock data)
- POI detail screen (with mock data)
- Empty state handling

### E2E Scenarios
- Select Paris → verify POIs appear progressively
- Switch cities → verify POI list updates
- Select POI → verify details load
- Handle API failures gracefully

---

## Dependencies Analysis

**No new dependencies required**:
- All APIs use HTTP/JSON (existing `http` package)
- State management via existing `provider` package
- No special parsing libraries needed (standard JSON, HTML parsing via RegExp)
- Haversine formula implemented in-app

**Development Dependencies**:
- mockito (already in use for mocking HTTP clients)
- flutter_test (standard testing framework)

---

## Performance Considerations

**Memory Usage**:
- In-memory cache: ~100 POIs × 5 KB each = ~500 KB per city
- Full Wikipedia article: ~50-200 KB per article
- Acceptable for mobile: <10 MB total for typical session

**Network Usage**:
- POI discovery: 3 requests per city (Wikipedia, Overpass, Wikidata)
- Response sizes: 20-100 KB each = ~200 KB per city
- Full Wikipedia article: 50-200 KB
- Total per city visit: ~400 KB
- Reasonable for mobile data

**CPU Usage**:
- Deduplication: O(n²) for ~100 POIs = ~10,000 comparisons
- Haversine: Simple trigonometry, ~1 ms per comparison
- Total: <100ms for deduplication
- Negligible impact

---

## Research Validation

✅ All technical unknowns resolved  
✅ API endpoints identified and documented  
✅ Deduplication strategy defined with clear algorithm  
✅ Progressive loading approach specified  
✅ Performance characteristics acceptable  
✅ No new dependencies required  
✅ Testing strategy comprehensive  

**Status**: Ready for Phase 1 (Data Model & Contracts)

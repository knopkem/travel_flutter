---
work_package_id: "WP01"
subtasks:
  - "T001"
  - "T002"
  - "T003"
  - "T004"
  - "T005"
  - "T006"
  - "T007"
  - "T008"
title: "Foundation - Data Models & Utilities"
phase: "Phase 0 - Foundation"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-18T08:24:50+0100"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP01 – Foundation - Data Models & Utilities

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Create foundational data models (POI, enums) and utility functions for distance calculation and deduplication that all subsequent work packages depend on.

**Success Criteria**:
- POI model can be instantiated with valid data and enforces validation rules
- Factory methods (`fromWikipediaGeosearch`, `fromOverpass`, `fromWikidata`, `merge`) work correctly
- Distance calculator returns accurate results for known coordinates (e.g., Paris to Eiffel Tower = ~2.3 km)
- Deduplication utility correctly identifies duplicates using 50m proximity + 70% name similarity
- Notability scorer produces consistent scores (0-100 range) from source data
- All models and utilities are exported via `models.dart`

## Context & Constraints

**Related Documents**:
- [data-model.md](../data-model.md) - Complete entity definitions with attributes and validation rules
- [research.md](../research.md) - Haversine formula implementation, deduplication algorithm details
- [spec.md](../spec.md) - Functional requirements FR-010 (deduplication), FR-013 (10km radius)

**Architectural Decisions**:
- Use immutable models (final fields) for thread safety
- Factory methods return fully-formed POI objects with calculated derived fields
- Utilities are pure functions (no side effects) for testability
- ID generation uses hash of normalized name + rounded coordinates for consistency across sources

**Constraints**:
- POI notability score must be 0-100 integer
- Distance calculations use Haversine formula (spherical Earth approximation)
- Deduplication thresholds are configurable constants (50m, 70%) for tuning

## Subtasks & Detailed Guidance

### Subtask T001 – Create POIType enum [P]
**Purpose**: Define categorical types for POIs to enable filtering and icon display.

**Steps**:
1. Create `lib/models/poi_type.dart`
2. Define enum with values: `monument`, `museum`, `landmark`, `religiousSite`, `park`, `viewpoint`, `touristAttraction`, `historicSite`, `square`, `other`
3. Add helper method `String get displayName` to return user-friendly labels (e.g., "Monument", "Religious Site")
4. Add helper method `IconData get icon` for type-specific icons (optional, can defer to UI layer)

**Files**: `lib/models/poi_type.dart`

**Parallel**: Yes, independent from other subtasks

**Example**:
```dart
enum POIType {
  monument,
  museum,
  landmark,
  religiousSite,
  park,
  viewpoint,
  touristAttraction,
  historicSite,
  square,
  other;

  String get displayName {
    switch (this) {
      case POIType.monument:
        return 'Monument';
      case POIType.religiousSite:
        return 'Religious Site';
      // ... etc
    }
  }
}
```

---

### Subtask T002 – Create POISource enum [P]
**Purpose**: Track which API(s) provided data for each POI, used in deduplication logic.

**Steps**:
1. Create `lib/models/poi_source.dart`
2. Define enum with values: `wikipediaGeosearch`, `overpass`, `wikidata`
3. Add helper method `String get displayName` for UI display
4. Add helper method `int get priority` for merge preference (Wikipedia=3, Wikidata=2, Overpass=1)

**Files**: `lib/models/poi_source.dart`

**Parallel**: Yes, independent from other subtasks

**Example**:
```dart
enum POISource {
  wikipediaGeosearch,
  overpass,
  wikidata;

  int get priority {
    switch (this) {
      case POISource.wikipediaGeosearch:
        return 3; // Prefer Wikipedia data
      case POISource.wikidata:
        return 2;
      case POISource.overpass:
        return 1;
    }
  }
}
```

---

### Subtask T003 – Create POI model
**Purpose**: Central data model representing a point of interest with all attributes.

**Steps**:
1. Create `lib/models/poi.dart`
2. Define class with 14 attributes (see data-model.md):
   - Required: `id`, `name`, `type`, `latitude`, `longitude`, `distanceFromCity`, `sources`, `notabilityScore`, `discoveredAt`
   - Optional: `description`, `wikipediaTitle`, `wikidataId`, `imageUrl`, `website`, `openingHours`
3. Add validation in constructor (throw ArgumentError for invalid data):
   - `latitude` between -90 and 90
   - `longitude` between -180 and 180
   - `distanceFromCity` non-negative
   - `sources` non-empty list
   - `notabilityScore` between 0 and 100
4. Implement `toJson()` and `fromJson()` for serialization (optional, for caching)
5. Override `==` and `hashCode` using `id` for identity comparison

**Files**: `lib/models/poi.dart`

**Depends on**: T001 (POIType), T002 (POISource)

**Example Structure**:
```dart
class POI {
  final String id;
  final String name;
  final POIType type;
  final double latitude;
  final double longitude;
  final double distanceFromCity;
  final List<POISource> sources;
  final String? description;
  final String? wikipediaTitle;
  final String? wikidataId;
  final String? imageUrl;
  final String? website;
  final String? openingHours;
  final int notabilityScore;
  final DateTime discoveredAt;

  POI({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceFromCity,
    required this.sources,
    this.description,
    this.wikipediaTitle,
    this.wikidataId,
    this.imageUrl,
    this.website,
    this.openingHours,
    required this.notabilityScore,
    required this.discoveredAt,
  }) {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    // ... more validation
  }
}
```

---

### Subtask T004 – Add POI factory methods
**Purpose**: Provide source-specific constructors and merge logic for POI objects.

**Steps**:
1. In `lib/models/poi.dart`, add factory method `POI.fromWikipediaGeosearch(Map<String, dynamic> json, City city)`
   - Parse Wikipedia Geosearch response fields: `title`, `lat`, `lon`, `dist`, `pageid`
   - Calculate distance using Haversine if `dist` not provided
   - Generate ID from title + coordinates hash
   - Set `sources: [POISource.wikipediaGeosearch]`
   - Set `wikipediaTitle: json['title']`
   - Set `type: POIType.touristAttraction` (default)
   - Calculate notability score (base 75 for Wikipedia articles)
2. Add factory method `POI.fromOverpass(Map<String, dynamic> element, City city)`
   - Parse Overpass element: `id`, `lat`, `lon`, `tags` object
   - Map OSM tags to POIType (see contracts/overpass-api.md)
   - Extract optional fields: `tags['name']`, `tags['website']`, `tags['opening_hours']`, `tags['wikidata']`, `tags['wikipedia']`
   - Calculate notability from tags (wikidata tag +20, wikipedia tag +15, etc.)
3. Add factory method `POI.fromWikidata(Map<String, dynamic> binding, City city)`
   - Parse SPARQL binding: `placeLabel.value`, WKT coordinate, `wikipedia.value`, etc.
   - Parse WKT coordinate format: "Point(lon lat)" → (lat, lon)
   - Extract Wikidata ID from URI
   - Calculate notability from structured data (UNESCO +30, visitor count >1M +10)
4. Add static method `POI.merge(List<POI> duplicates)`
   - Combine sources lists from all duplicates
   - Prefer data from highest-priority source (Wikipedia > Wikidata > Overpass)
   - Use most complete description, highest notability score
   - Keep earliest `discoveredAt` timestamp

**Files**: `lib/models/poi.dart`

**Depends on**: T003 (POI model), T005 (distance calculator for Haversine)

**Example**:
```dart
factory POI.fromWikipediaGeosearch(Map<String, dynamic> json, City city) {
  final lat = (json['lat'] as num).toDouble();
  final lon = (json['lon'] as num).toDouble();
  final title = json['title'] as String;
  
  return POI(
    id: _generateId(title, lat, lon),
    name: title,
    type: POIType.touristAttraction,
    latitude: lat,
    longitude: lon,
    distanceFromCity: json['dist'] as double,
    sources: [POISource.wikipediaGeosearch],
    wikipediaTitle: title,
    notabilityScore: 75,
    discoveredAt: DateTime.now(),
  );
}

static String _generateId(String name, double lat, double lon) {
  final normalized = name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  final latRounded = (lat * 10000).round();
  final lonRounded = (lon * 10000).round();
  return '$normalized-$latRounded-$lonRounded'.hashCode.toString();
}
```

---

### Subtask T005 – Create distance calculator utility [P]
**Purpose**: Calculate distance between two lat/lon coordinates using Haversine formula.

**Steps**:
1. Create `lib/utils/distance_calculator.dart`
2. Implement function `double calculateDistance(double lat1, double lon1, double lat2, double lon2)`
3. Use Haversine formula (see research.md for details):
   - Convert degrees to radians
   - Calculate differences (Δlat, Δlon)
   - Apply formula: a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)
   - Calculate c = 2 * atan2(√a, √(1−a))
   - Distance = R * c (where R = Earth radius = 6371 km)
4. Return distance in meters (multiply km result by 1000)
5. Add input validation (lat between -90 to 90, lon between -180 to 180)

**Files**: `lib/utils/distance_calculator.dart`

**Parallel**: Yes, independent utility function

**Example**:
```dart
import 'dart:math';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000; // meters
  
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  
  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
```

---

### Subtask T006 – Create deduplication utility [P]
**Purpose**: Identify and merge duplicate POIs from multiple sources using proximity and name matching.

**Steps**:
1. Create `lib/utils/deduplication_utils.dart`
2. Define constants: `proximityThresholdMeters = 50.0`, `nameSimilarityThreshold = 0.7`
3. Implement function `List<POI> deduplicatePOIs(List<POI> pois)`
   - Algorithm (see research.md):
     1. Sort POIs by notability score descending
     2. For each POI, find candidates within 50m radius using distance calculator
     3. For candidates, calculate name similarity using Levenshtein distance
     4. If similarity >= 70%, mark as duplicate
     5. Merge duplicates using `POI.merge()`
     6. Return deduplicated list
4. Implement helper function `double calculateNameSimilarity(String name1, String name2)`
   - Normalize names: lowercase, remove punctuation, trim whitespace
   - Calculate Levenshtein distance
   - Convert to similarity: 1 - (distance / max(len1, len2))
5. Add comprehensive comments explaining the two-phase approach

**Files**: `lib/utils/deduplication_utils.dart`

**Depends on**: T005 (distance calculator)

**Parallel**: Yes after T005 complete

**Example**:
```dart
const double proximityThresholdMeters = 50.0;
const double nameSimilarityThreshold = 0.7;

List<POI> deduplicatePOIs(List<POI> pois) {
  final deduplicated = <POI>[];
  final processed = <String>{};
  
  // Sort by notability to prefer high-quality entries
  final sorted = List<POI>.from(pois)..sort((a, b) => b.notabilityScore.compareTo(a.notabilityScore));
  
  for (final poi in sorted) {
    if (processed.contains(poi.id)) continue;
    
    // Find duplicates
    final duplicates = <POI>[poi];
    for (final other in sorted) {
      if (other.id == poi.id || processed.contains(other.id)) continue;
      
      // Phase 1: Coordinate proximity
      final distance = calculateDistance(poi.latitude, poi.longitude, other.latitude, other.longitude);
      if (distance > proximityThresholdMeters) continue;
      
      // Phase 2: Name similarity
      final similarity = calculateNameSimilarity(poi.name, other.name);
      if (similarity >= nameSimilarityThreshold) {
        duplicates.add(other);
        processed.add(other.id);
      }
    }
    
    deduplicated.add(POI.merge(duplicates));
    processed.add(poi.id);
  }
  
  return deduplicated;
}

double calculateNameSimilarity(String name1, String name2) {
  final normalized1 = _normalizeName(name1);
  final normalized2 = _normalizeName(name2);
  final distance = _levenshteinDistance(normalized1, normalized2);
  final maxLen = max(normalized1.length, normalized2.length);
  return maxLen == 0 ? 1.0 : 1.0 - (distance / maxLen);
}

String _normalizeName(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
}

int _levenshteinDistance(String s1, String s2) {
  // Standard Levenshtein algorithm implementation
  // ... (implement or use package like 'string_similarity')
}
```

---

### Subtask T007 – Create notability scorer utility [P]
**Purpose**: Calculate POI importance score (0-100) from source data for sorting.

**Steps**:
1. Create `lib/utils/notability_scorer.dart`
2. Implement function `int calculateNotabilityScore(POI poi, Map<String, dynamic> sourceData)`
3. Scoring rules (from data-model.md and contracts):
   - Base score: 50
   - Has Wikidata ID: +20
   - Has Wikipedia article: +15
   - Has website: +5
   - Has multiple language names: +5
   - UNESCO heritage site: +30
   - Annual visitors > 1M: +10
   - Has opening hours: +3
4. Clamp result to 0-100 range
5. Add comments explaining scoring rationale

**Files**: `lib/utils/notability_scorer.dart`

**Parallel**: Yes, independent utility

**Example**:
```dart
int calculateNotabilityScore({
  required POISource source,
  String? wikidataId,
  String? wikipediaTitle,
  String? website,
  String? heritageStatus,
  int? annualVisitors,
  String? openingHours,
}) {
  int score = 50; // Base score
  
  if (wikidataId != null) score += 20;
  if (wikipediaTitle != null) score += 15;
  if (website != null) score += 5;
  if (openingHours != null) score += 3;
  
  if (heritageStatus != null && heritageStatus.contains('UNESCO')) {
    score += 30;
  } else if (heritageStatus != null) {
    score += 15;
  }
  
  if (annualVisitors != null && annualVisitors > 1000000) {
    score += 10;
  }
  
  return score.clamp(0, 100);
}
```

---

### Subtask T008 – Update models.dart export file
**Purpose**: Make all new models and utilities accessible via single import.

**Steps**:
1. Open `lib/models/models.dart`
2. Add exports:
   ```dart
   export 'poi.dart';
   export 'poi_type.dart';
   export 'poi_source.dart';
   ```
3. Create `lib/utils/utils.dart` if it doesn't exist
4. Add exports:
   ```dart
   export 'distance_calculator.dart';
   export 'deduplication_utils.dart';
   export 'notability_scorer.dart';
   ```

**Files**: `lib/models/models.dart`, `lib/utils/utils.dart`

**Depends on**: All previous subtasks

---

## Risks & Mitigations

**Risk**: Deduplication too aggressive (false positives) or too lenient (false negatives)
- **Mitigation**: Thresholds (50m, 70%) are configurable constants at top of file; can tune based on testing with real data

**Risk**: Distance calculation performance with hundreds of POIs
- **Mitigation**: Haversine is O(1) per calculation; acceptable for 100s of POIs. If needed, can optimize with spatial indexing later

**Risk**: Name similarity algorithm too slow or inaccurate
- **Mitigation**: Use established Levenshtein implementation (consider `string_similarity` package); normalize names before comparison

**Risk**: ID generation produces collisions
- **Mitigation**: Include both name and rounded coordinates in hash; low probability of collision for distinct POIs

## Definition of Done Checklist

- [ ] POIType enum created with all 10 types and helper methods
- [ ] POISource enum created with 3 sources and priority logic
- [ ] POI model implemented with all 14 attributes and validation
- [ ] Factory methods work correctly for all 3 data sources (Wikipedia, Overpass, Wikidata)
- [ ] Distance calculator returns accurate results (test with known coordinates)
- [ ] Deduplication utility correctly identifies duplicates (test with sample data)
- [ ] Notability scorer produces consistent scores in 0-100 range
- [ ] All models and utilities exported via models.dart and utils.dart
- [ ] No lint errors or warnings
- [ ] Code documented with clear comments explaining algorithms

## Review Guidance

**Key Checkpoints**:
1. **Data Integrity**: POI validation prevents invalid coordinates, empty sources, out-of-range scores
2. **Algorithm Correctness**: Haversine distance matches known results (e.g., Paris center to Eiffel Tower ≈ 2.3 km)
3. **Deduplication Logic**: Two-phase approach (proximity + name) works as specified
4. **Factory Methods**: Each source-specific factory correctly parses its API response format
5. **Code Quality**: Pure functions, immutable models, clear variable names

**Common Issues to Check**:
- WKT coordinate order: Wikidata uses (lon, lat) not (lat, lon)
- Null safety: Optional POI fields handled correctly
- Edge cases: Empty name strings, coordinates at poles/dateline

## Activity Log

- 2025-12-18T08:24:50+0100 – system – lane=planned – Prompt created via /spec-kitty.tasks

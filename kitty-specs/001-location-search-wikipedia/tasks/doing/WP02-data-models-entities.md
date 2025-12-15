---
work_package_id: "WP02"
subtasks:
  - "T005"
  - "T006"
  - "T007"
  - "T008"
  - "T009"
title: "Data Models & Entities"
phase: "Phase 1 - Data Layer"
lane: "doing"
assignee: "Claude"
agent: "claude"
shell_pid: "28247"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-12T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-15T13:00:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "28247"
    action: "Started implementation of data models"
---
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP02-data-models-entities.md*

# Work Package Prompt: WP02 – Data Models & Entities

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Implement all data model classes with validation, serialization, and immutability.

**Success Criteria**:
- All 3 entity classes created (Location, LocationSuggestion, WikipediaContent)
- Each class has fromJson factory constructor
- Each class has validation rules
- Models are immutable
- `flutter analyze` shows zero warnings

## Context & Constraints

**Prerequisites**: WP01 complete (directory structure exists)

**References**:
- [data-model.md](../../data-model.md) - Complete entity specifications
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle II (Modular Architecture)

**Constraints**:
- All fields must be immutable (final)
- Use named constructors for factories
- Null-safety compliant

## Subtasks & Detailed Guidance

### Subtask T005 – Create Location model

**Purpose**: Primary entity representing a geographic location.

**Steps**:
1. Create `lib/models/location.dart`
2. Define Location class with fields: id, displayName, latitude, longitude
3. Add fromJson factory parsing Nominatim API response
4. Add validation for coordinate ranges (lat: -90 to 90, lon: -180 to 180)
5. Override toString() for debugging

**Files**: `lib/models/location.dart`

**Parallel?**: Yes (independent of other models)

**Example** (reference data-model.md for complete implementation):
```dart
class Location {
  final String id;
  final String displayName;
  final double latitude;
  final double longitude;

  const Location({
    required this.id,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['place_id'].toString(),
      displayName: json['display_name'] as String,
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
    );
  }

  @override
  String toString() => 'Location(id: $id, displayName: $displayName)';
}
```

---

### Subtask T006 – Create LocationSuggestion model

**Purpose**: Lightweight entity for search dropdown suggestions.

**Steps**:
1. Create `lib/models/location_suggestion.dart`
2. Define LocationSuggestion class with fields: id, displayName
3. Add fromJson factory parsing Nominatim search results
4. Add constructor to convert Location → LocationSuggestion
5. Override toString() for debugging

**Files**: `lib/models/location_suggestion.dart`

**Parallel?**: Yes (independent of other models)

**Example**:
```dart
class LocationSuggestion {
  final String id;
  final String displayName;

  const LocationSuggestion({
    required this.id,
    required this.displayName,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      id: json['place_id'].toString(),
      displayName: json['display_name'] as String,
    );
  }

  factory LocationSuggestion.fromLocation(Location location) {
    return LocationSuggestion(
      id: location.id,
      displayName: location.displayName,
    );
  }

  @override
  String toString() => 'LocationSuggestion(id: $id, displayName: $displayName)';
}
```

---

### Subtask T007 – Create WikipediaContent model

**Purpose**: Entity representing Wikipedia article summary data.

**Steps**:
1. Create `lib/models/wikipedia_content.dart`
2. Define WikipediaContent class with fields: title, extract, thumbnailUrl (nullable)
3. Add fromJson factory parsing Wikipedia API response
4. Add validation for required fields
5. Override toString() for debugging

**Files**: `lib/models/wikipedia_content.dart`

**Parallel?**: Yes (independent of other models)

**Example**:
```dart
class WikipediaContent {
  final String title;
  final String extract;
  final String? thumbnailUrl;

  const WikipediaContent({
    required this.title,
    required this.extract,
    this.thumbnailUrl,
  });

  factory WikipediaContent.fromJson(Map<String, dynamic> json) {
    return WikipediaContent(
      title: json['title'] as String,
      extract: json['extract'] as String,
      thumbnailUrl: json['thumbnail']?['source'] as String?,
    );
  }

  @override
  String toString() => 'WikipediaContent(title: $title)';
}
```

---

### Subtask T008 – Create models barrel file

**Purpose**: Simplify imports across the application.

**Steps**:
1. Create `lib/models/models.dart`
2. Export all model classes
3. Verify imports work with single statement: `import 'package:travel_flutter_app/models/models.dart';`

**Files**: `lib/models/models.dart`

**Parallel?**: No (requires T005-T007 complete)

**Example**:
```dart
export 'location.dart';
export 'location_suggestion.dart';
export 'wikipedia_content.dart';
```

---

### Subtask T009 – Add model documentation

**Purpose**: Document model usage and validation rules.

**Steps**:
1. Add dartdoc comments to each model class
2. Document each field with /// comments
3. Document validation rules in fromJson factories
4. Add usage examples in class-level documentation

**Files**: All model files

**Parallel?**: No (requires T005-T008 complete)

**Example documentation**:
```dart
/// Represents a geographic location with coordinates.
///
/// This model is used to store selected locations from the search results.
/// Coordinates are validated to ensure they fall within valid ranges:
/// - Latitude: -90.0 to 90.0
/// - Longitude: -180.0 to 180.0
///
/// Example:
/// ```dart
/// final location = Location.fromJson({
///   'place_id': '123',
///   'display_name': 'Berlin, Germany',
///   'lat': '52.5200',
///   'lon': '13.4050',
/// });
/// ```
class Location {
  /// Unique identifier from the geocoding service
  final String id;
  
  /// Human-readable location name (e.g., "Berlin, Germany")
  final String displayName;
  
  // ... rest of class
}
```

## Test Strategy

No tests required per constitution (testing on-demand only).

**Manual Verification**:
1. Run `flutter analyze` - should show zero warnings
2. Create test instance of each model with sample JSON
3. Verify toString() output is readable
4. Check that invalid coordinates throw errors

## Risks & Mitigations

**Risk**: API response format changes breaking fromJson
- **Mitigation**: Add try-catch in factories, log parsing errors

**Risk**: Missing null-safety annotations causing runtime errors
- **Mitigation**: Use `flutter analyze` to catch issues, test with null values

## Definition of Done Checklist

- [ ] Location model created with all fields and fromJson
- [ ] LocationSuggestion model created with all fields and fromJson
- [ ] WikipediaContent model created with all fields and fromJson
- [ ] models.dart barrel file created
- [ ] All classes have dartdoc comments
- [ ] All fields documented
- [ ] toString() implemented for each model
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual verification with sample JSON successful
- [ ] tasks.md updated to mark WP02 complete

## Review Guidance

**Verify**:
- All fields are final (immutable)
- fromJson factories handle missing/null fields gracefully
- Validation rules match data-model.md specification
- Documentation is clear and includes examples
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

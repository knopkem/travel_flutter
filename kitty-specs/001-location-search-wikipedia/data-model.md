# Data Model: Location Search & Wikipedia Browser
*Path: kitty-specs/001-location-search-wikipedia/data-model.md*

**Feature**: Location Search & Wikipedia Browser
**Date**: 2025-12-12
**Status**: Complete

## Overview

This document defines the data entities, their attributes, relationships, and validation rules for the location search and Wikipedia browser feature. All entities are modeled as Dart classes with immutability in mind.

---

## Entity Definitions

### 1. Location

**Purpose**: Represents a city or town that the user has selected and saved to their location list.

**Lifecycle**: Created when user selects from suggestions, persists in memory during app session, removed from list if app is closed.

**Attributes**:

| Attribute | Type | Description | Validation | Required |
|-----------|------|-------------|------------|----------|
| `id` | String | Unique identifier (using `osm_id` from Nominatim) | Non-empty string | Yes |
| `name` | String | City name (e.g., "Paris") | Non-empty, trimmed | Yes |
| `country` | String | Country name (e.g., "France") | Non-empty, trimmed | Yes |
| `displayName` | String | Full display name (e.g., "Paris, France") | Non-empty | Yes |
| `latitude` | double | Geographic latitude coordinate | -90 to 90 | Yes |
| `longitude` | double | Geographic longitude coordinate | -180 to 180 | Yes |

**Relationships**: None (standalone entity)

**State Transitions**: Immutable once created

**Dart Implementation**:
```dart
class Location {
  final String id;
  final String name;
  final String country;
  final String displayName;
  final double latitude;
  final double longitude;
  
  const Location({
    required this.id,
    required this.name,
    required this.country,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
  
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['osm_id'].toString(),
      name: json['address']['city'] ?? json['address']['town'] ?? json['display_name'].split(',')[0].trim(),
      country: json['address']['country'] ?? 'Unknown',
      displayName: json['display_name'],
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
    );
  }
}
```

**Business Rules**:
- Each location in the list must have a unique `id`
- Display name used for button labels and screen titles
- Latitude/longitude stored but not displayed (reserved for future GPS features)

---

### 2. LocationSuggestion

**Purpose**: Temporary representation of a search result from Nominatim API, displayed in the autocomplete dropdown.

**Lifecycle**: Created during search, displayed in suggestion list, converted to `Location` on user selection, discarded when search changes or suggestion selected.

**Attributes**:

| Attribute | Type | Description | Validation | Required |
|-----------|------|-------------|------------|----------|
| `id` | String | OSM place identifier | Non-empty string | Yes |
| `name` | String | City name | Non-empty, trimmed | Yes |
| `country` | String | Country name | Non-empty, trimmed | Yes |
| `displayName` | String | Full display text for suggestion | Non-empty | Yes |
| `latitude` | double | Geographic latitude | -90 to 90 | Yes |
| `longitude` | double | Geographic longitude | -180 to 180 | Yes |

**Relationships**: Converts to `Location` entity when selected

**State Transitions**: 
- Created from Nominatim API response
- Displayed in UI
- Converted to Location OR discarded

**Dart Implementation**:
```dart
class LocationSuggestion {
  final String id;
  final String name;
  final String country;
  final String displayName;
  final double latitude;
  final double longitude;
  
  const LocationSuggestion({
    required this.id,
    required this.name,
    required this.country,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
  
  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      id: json['osm_id'].toString(),
      name: json['address']['city'] ?? json['address']['town'] ?? json['display_name'].split(',')[0].trim(),
      country: json['address']['country'] ?? 'Unknown',
      displayName: json['display_name'],
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
    );
  }
  
  Location toLocation() {
    return Location(
      id: id,
      name: name,
      country: country,
      displayName: displayName,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
```

**Business Rules**:
- Maximum 5-10 suggestions displayed at once
- Suggestions cleared when search query changes
- Duplicate prevention: Don't add location if already in saved list

---

### 3. WikipediaContent

**Purpose**: Holds Wikipedia article information for a selected location, fetched on-demand when user taps location button.

**Lifecycle**: Created when detail screen loads, cached during screen lifetime, discarded when user navigates away.

**Attributes**:

| Attribute | Type | Description | Validation | Required |
|-----------|------|-------------|------------|----------|
| `title` | String | Wikipedia page title | Non-empty | Yes |
| `summary` | String | Plain text summary (first paragraph) | Non-empty | Yes |
| `extractHtml` | String? | HTML formatted summary | Valid HTML or null | No |
| `thumbnailUrl` | String? | Image thumbnail URL | Valid URL or null | No |
| `pageUrl` | String | Full Wikipedia article URL | Valid URL | Yes |

**Relationships**: Associated with `Location` (fetched using location's display name)

**State Transitions**:
- Loading (initial state when screen opens)
- Loaded (data fetched successfully)
- Error (API failure or page not found)

**Dart Implementation**:
```dart
class WikipediaContent {
  final String title;
  final String summary;
  final String? extractHtml;
  final String? thumbnailUrl;
  final String pageUrl;
  
  const WikipediaContent({
    required this.title,
    required this.summary,
    this.extractHtml,
    this.thumbnailUrl,
    required this.pageUrl,
  });
  
  factory WikipediaContent.fromJson(Map<String, dynamic> json) {
    return WikipediaContent(
      title: json['title'],
      summary: json['extract'],
      extractHtml: json['extract_html'],
      thumbnailUrl: json['thumbnail']?['source'],
      pageUrl: json['content_urls']['desktop']['page'],
    );
  }
}
```

**Business Rules**:
- If `thumbnailUrl` is null, don't display image placeholder
- If page not found (404), show "No information available" message
- Summary text should be scrollable for long content
- `pageUrl` can be opened in external browser if user wants full article

---

## Data Flow Diagrams

### Search Flow
```
User types in search field
    ↓
Debounce 300ms
    ↓
GeocodingRepository.search(query)
    ↓
Nominatim API call
    ↓
List<LocationSuggestion> returned
    ↓
Display in suggestion list
    ↓
User taps suggestion
    ↓
Convert LocationSuggestion → Location
    ↓
Add to LocationProvider locations list
    ↓
Display as button on home screen
```

### Wikipedia Content Flow
```
User taps Location button
    ↓
Navigate to LocationDetailScreen
    ↓
WikipediaProvider.fetchContent(location.displayName)
    ↓
Wikipedia API call
    ↓
WikipediaContent created
    ↓
Display title, thumbnail, summary
    ↓
User taps back button
    ↓
Return to home screen (location list preserved)
```

---

## Validation Rules

### Location Validation
- `id`: Must be unique within locations list
- `name`, `country`, `displayName`: Must not be empty after trimming
- `latitude`: Must be between -90 and 90
- `longitude`: Must be between -180 and 180

### LocationSuggestion Validation
- Same as Location (same attribute types)
- Additional: Must successfully convert to Location format

### WikipediaContent Validation
- `title`: Must not be empty
- `summary`: Must not be empty
- `thumbnailUrl`: If present, must be valid HTTP/HTTPS URL
- `pageUrl`: Must be valid HTTP/HTTPS URL

---

## Error Handling

### Invalid Data Scenarios

**Nominatim API Returns Incomplete Data**:
- Missing `address.city`: Fallback to first part of `display_name`
- Missing `address.country`: Use "Unknown" as default
- Invalid lat/lon format: Catch parsing exception, skip that result

**Wikipedia API Returns Error**:
- 404 Not Found: Display "No information available for this location"
- 503 Service Unavailable: Display "Service temporarily unavailable. Please try again."
- Invalid JSON: Display generic error message

**User Input Edge Cases**:
- Empty search query: Clear suggestions immediately, don't call API
- Special characters in query: URL encode before API call
- Very long query (>100 chars): Allow but may return no results

---

## State Management Integration

### LocationProvider State
```dart
class LocationProvider extends ChangeNotifier {
  List<Location> _locations = [];
  
  List<Location> get locations => List.unmodifiable(_locations);
  
  void addLocation(Location location) {
    // Prevent duplicates
    if (_locations.any((l) => l.id == location.id)) {
      return;
    }
    _locations.add(location);
    notifyListeners();
  }
  
  void removeLocation(String id) {
    _locations.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}
```

### WikipediaProvider State
```dart
enum ContentState { initial, loading, loaded, error }

class WikipediaProvider extends ChangeNotifier {
  WikipediaContent? _content;
  ContentState _state = ContentState.initial;
  String? _errorMessage;
  
  WikipediaContent? get content => _content;
  ContentState get state => _state;
  String? get errorMessage => _errorMessage;
  
  Future<void> fetchContent(String locationName) async {
    _state = ContentState.loading;
    _errorMessage = null;
    notifyListeners();
    
    try {
      _content = await _repository.getContent(locationName);
      _state = ContentState.loaded;
    } catch (e) {
      _state = ContentState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }
}
```

---

## Summary

**Total Entities**: 3 (Location, LocationSuggestion, WikipediaContent)

**Persistence**: In-memory only (no database, no local storage)

**Immutability**: All entities are immutable (const constructors, final fields)

**Conversion Path**: LocationSuggestion → Location (on user selection)

**State Management**: LocationProvider holds List<Location>, WikipediaProvider holds WikipediaContent with loading states

**Ready for Implementation**: All entities defined with Dart code examples, validation rules, and error handling strategies.

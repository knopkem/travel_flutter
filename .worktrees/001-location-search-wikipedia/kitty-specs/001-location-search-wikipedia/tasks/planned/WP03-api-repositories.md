---
work_package_id: "WP03"
subtasks:
  - "T010"
  - "T011"
  - "T012"
  - "T013"
  - "T014"
  - "T015"
title: "API Repositories"
phase: "Phase 1 - Data Layer"
lane: "planned"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-12T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP03-api-repositories.md*

# Work Package Prompt: WP03 – API Repositories

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Implement repositories for Nominatim geocoding and Wikipedia APIs with error handling.

**Success Criteria**:
- GeocodingRepository successfully fetches location suggestions
- WikipediaRepository successfully fetches article summaries
- Both repositories handle network errors gracefully
- HTTP client configured with proper headers and timeouts
- Rate limiting respected (Nominatim: 1 req/sec)

## Context & Constraints

**Prerequisites**: WP02 complete (models exist)

**References**:
- [contracts/nominatim-api.md](../../contracts/nominatim-api.md) - Nominatim API specification
- [contracts/wikipedia-api.md](../../contracts/wikipedia-api.md) - Wikipedia API specification
- [research.md](../../research.md) - API details and error handling patterns
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle I (Modern Dependencies)

**Constraints**:
- Use official `http` package (no Dio or other alternatives)
- Respect Nominatim rate limit: 1 request per second
- Set User-Agent header for both APIs
- Timeout: 10 seconds per request

## Subtasks & Detailed Guidance

### Subtask T010 – Create GeocodingRepository interface

**Purpose**: Define contract for geocoding operations.

**Steps**:
1. Create `lib/repositories/geocoding_repository.dart`
2. Define abstract class with searchLocations(query) method
3. Document expected behavior and exceptions
4. Return Future<List<LocationSuggestion>>

**Files**: `lib/repositories/geocoding_repository.dart`

**Parallel?**: Yes (independent of WikipediaRepository)

**Example**:
```dart
import '../models/models.dart';

/// Repository for geocoding operations (location search).
abstract class GeocodingRepository {
  /// Searches for locations matching the given query.
  ///
  /// Returns a list of location suggestions or throws an exception
  /// if the request fails.
  ///
  /// Throws:
  /// - [Exception] if network request fails or API returns error
  Future<List<LocationSuggestion>> searchLocations(String query);
}
```

---

### Subtask T011 – Implement NominatimGeocodingRepository

**Purpose**: Concrete implementation for OpenStreetMap Nominatim API.

**Steps**:
1. Create `lib/repositories/nominatim_geocoding_repository.dart`
2. Implement GeocodingRepository interface
3. Use http.Client for requests
4. Build query URL: `https://nominatim.openstreetmap.org/search?q={query}&format=json&limit=10`
5. Add headers: User-Agent, Accept-Language
6. Parse JSON response to List<LocationSuggestion>
7. Handle errors: network timeout, HTTP errors, parsing errors
8. Add rate limiting logic (1 req/sec)

**Files**: `lib/repositories/nominatim_geocoding_repository.dart`

**Parallel?**: No (requires T010)

**Key implementation details**:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'geocoding_repository.dart';

class NominatimGeocodingRepository implements GeocodingRepository {
  final http.Client _client;
  final String _baseUrl = 'https://nominatim.openstreetmap.org';
  DateTime? _lastRequestTime;

  NominatimGeocodingRepository({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<LocationSuggestion>> searchLocations(String query) async {
    // Rate limiting: ensure 1 second between requests
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
      }
    }
    _lastRequestTime = DateTime.now();

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '10',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'TravelFlutterApp/1.0',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => LocationSuggestion.fromJson(item)).toList();
      } else {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search locations: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Subtask T012 – Create WikipediaRepository interface

**Purpose**: Define contract for Wikipedia content operations.

**Steps**:
1. Create `lib/repositories/wikipedia_repository.dart`
2. Define abstract class with fetchSummary(title) method
3. Document expected behavior and exceptions
4. Return Future<WikipediaContent>

**Files**: `lib/repositories/wikipedia_repository.dart`

**Parallel?**: Yes (independent of GeocodingRepository)

**Example**:
```dart
import '../models/models.dart';

/// Repository for Wikipedia content operations.
abstract class WikipediaRepository {
  /// Fetches the summary for a Wikipedia article by title.
  ///
  /// Throws:
  /// - [Exception] if network request fails or article not found
  Future<WikipediaContent> fetchSummary(String title);
}
```

---

### Subtask T013 – Implement RestWikipediaRepository

**Purpose**: Concrete implementation for Wikipedia REST API.

**Steps**:
1. Create `lib/repositories/rest_wikipedia_repository.dart`
2. Implement WikipediaRepository interface
3. Use http.Client for requests
4. Build URL: `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
5. Add User-Agent header
6. Parse JSON response to WikipediaContent
7. Handle errors: 404 (article not found), network errors, parsing errors

**Files**: `lib/repositories/rest_wikipedia_repository.dart`

**Parallel?**: No (requires T012)

**Key implementation details**:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'wikipedia_repository.dart';

class RestWikipediaRepository implements WikipediaRepository {
  final http.Client _client;
  final String _baseUrl = 'https://en.wikipedia.org/api/rest_v1';

  RestWikipediaRepository({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<WikipediaContent> fetchSummary(String title) async {
    // URL-encode the title
    final encodedTitle = Uri.encodeComponent(title);
    final uri = Uri.parse('$_baseUrl/page/summary/$encodedTitle');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'TravelFlutterApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WikipediaContent.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Wikipedia article not found: $title');
      } else {
        throw Exception('Wikipedia API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch Wikipedia content: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Subtask T014 – Create repositories barrel file

**Purpose**: Simplify imports across the application.

**Steps**:
1. Create `lib/repositories/repositories.dart`
2. Export all repository classes
3. Verify imports work with single statement

**Files**: `lib/repositories/repositories.dart`

**Parallel?**: No (requires T010-T013 complete)

**Example**:
```dart
export 'geocoding_repository.dart';
export 'nominatim_geocoding_repository.dart';
export 'wikipedia_repository.dart';
export 'rest_wikipedia_repository.dart';
```

---

### Subtask T015 – Add repository documentation

**Purpose**: Document API contracts, error handling, and usage patterns.

**Steps**:
1. Add dartdoc comments to all repository classes
2. Document method parameters and return types
3. Document exceptions that can be thrown
4. Add usage examples

**Files**: All repository files

**Parallel?**: No (requires T010-T014 complete)

**Example documentation**:
```dart
/// Implementation of [GeocodingRepository] using OpenStreetMap Nominatim API.
///
/// This repository handles:
/// - Rate limiting (1 request per second)
/// - Network error handling
/// - Response parsing
///
/// Usage:
/// ```dart
/// final repository = NominatimGeocodingRepository();
/// try {
///   final suggestions = await repository.searchLocations('Berlin');
///   print('Found ${suggestions.length} suggestions');
/// } catch (e) {
///   print('Error: $e');
/// }
/// ```
///
/// Remember to call [dispose] when done to close the HTTP client.
class NominatimGeocodingRepository implements GeocodingRepository {
  // ...
}
```

## Test Strategy

No tests required per constitution (testing on-demand only).

**Manual Verification**:
1. Create repository instances
2. Test searchLocations with valid query (e.g., "Berlin")
3. Test fetchSummary with valid title (e.g., "Berlin")
4. Test error handling with invalid queries
5. Verify rate limiting works (multiple rapid requests)
6. Check User-Agent header in network logs

## Risks & Mitigations

**Risk**: Rate limiting too strict, causing delays
- **Mitigation**: Use 1 second delay as specified, test with real usage patterns

**Risk**: Network timeouts in poor connectivity
- **Mitigation**: Use 10 second timeout, display user-friendly error messages

**Risk**: API response format changes
- **Mitigation**: Wrap parsing in try-catch, log errors for debugging

## Definition of Done Checklist

- [ ] GeocodingRepository interface created
- [ ] NominatimGeocodingRepository implemented with rate limiting
- [ ] WikipediaRepository interface created
- [ ] RestWikipediaRepository implemented
- [ ] repositories.dart barrel file created
- [ ] All classes have dartdoc comments
- [ ] Error handling implemented for all failure scenarios
- [ ] User-Agent headers configured
- [ ] Timeout configured (10 seconds)
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual testing with valid/invalid queries successful
- [ ] tasks.md updated to mark WP03 complete

## Review Guidance

**Verify**:
- Rate limiting logic correct (1 req/sec for Nominatim)
- HTTP headers match API requirements (User-Agent, Accept-Language)
- Error messages are user-friendly
- dispose() methods clean up resources
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

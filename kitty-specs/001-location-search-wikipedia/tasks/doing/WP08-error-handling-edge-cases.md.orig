---
work_package_id: "WP08"
subtasks:
  - "T046"
  - "T047"
  - "T048"
  - "T049"
  - "T050"
  - "T051"
  - "T052"
title: "Error Handling & Edge Cases"
phase: "Phase 3 - Quality & Polish"
lane: "for_review"
assignee: "claude"
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
  - timestamp: "2025-12-15T15:25:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "28247"
    action: "Started implementation (most error handling already in place, will verify and add logging)"
  - timestamp: "2025-12-15T15:30:00Z"
    lane: "for_review"
    agent: "claude"
    shell_pid: "28247"
    action: "Completed all subtasks (T046-T052): Added debugPrint logging to all error paths. Verified comprehensive error handling: network errors, timeouts, rate limits, HTTP status codes, empty states, special characters. All user-facing error messages remain friendly. Zero analyzer warnings."
---
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP08-error-handling-edge-cases.md*

# Work Package Prompt: WP08 – Error Handling & Edge Cases

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Comprehensive error handling and edge case coverage.

**Success Criteria**:
- Network errors handled gracefully
- Invalid/special characters in queries handled
- Empty states display appropriately
- Rate limiting respected (no API errors)
- User-friendly error messages throughout
- App doesn't crash on any error scenario

## Context & Constraints

**Prerequisites**: WP05, WP06, WP07 complete (all features implemented)

**References**:
- [spec.md](../../spec.md) - See "Edge Cases & Error Handling" section
- [research.md](../../research.md) - Error handling patterns
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle III (Quality)

**Constraints**:
- All errors must be caught (no uncaught exceptions)
- User-facing messages must be clear and actionable
- Logging should help with debugging

## Subtasks & Detailed Guidance

### Subtask T046 – Handle network connectivity errors

**Purpose**: Gracefully handle no network / timeout scenarios.

**Steps**:
1. Test with airplane mode enabled
2. Verify error messages display: "No internet connection"
3. Add retry mechanism for failed requests
4. Consider adding connectivity check before API calls (optional)

**Files**: 
- `lib/repositories/nominatim_geocoding_repository.dart`
- `lib/repositories/rest_wikipedia_repository.dart`
- `lib/providers/location_provider.dart`
- `lib/providers/wikipedia_provider.dart`

**Parallel?**: No (integration testing)

**Example error handling**:
```dart
try {
  final response = await _client.get(uri).timeout(const Duration(seconds: 10));
  // ... parse response
} on TimeoutException {
  throw Exception('Request timed out. Please check your internet connection.');
} on SocketException {
  throw Exception('No internet connection available.');
} catch (e) {
  throw Exception('Failed to search locations: $e');
}
```

---

### Subtask T047 – Handle special characters in search queries

**Purpose**: Prevent errors from special characters in location names.

**Steps**:
1. Test queries with: &, %, #, /, special Unicode
2. Verify URL encoding works correctly
3. Handle empty queries gracefully
4. Strip leading/trailing whitespace

**Files**: 
- `lib/repositories/nominatim_geocoding_repository.dart`
- `lib/providers/location_provider.dart`

**Parallel?**: No (enhancement of existing logic)

**Example**:
```dart
Future<List<LocationSuggestion>> searchLocations(String query) async {
  // Sanitize input
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return [];
  }

  // URL encoding handled automatically by Uri.replace()
  final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
    'q': trimmedQuery,
    'format': 'json',
    'limit': '10',
  });

  // ... rest of method
}
```

---

### Subtask T048 – Handle API response errors

**Purpose**: Handle unexpected API responses gracefully.

**Steps**:
1. Test with invalid location names (gibberish)
2. Handle 404 errors (not found)
3. Handle 429 errors (rate limit exceeded)
4. Handle 500+ errors (server errors)
5. Parse errors gracefully (malformed JSON)

**Files**: All repository files

**Parallel?**: No (enhancement of existing error handling)

**Example HTTP status handling**:
```dart
if (response.statusCode == 200) {
  // Success
} else if (response.statusCode == 404) {
  throw Exception('Location not found');
} else if (response.statusCode == 429) {
  throw Exception('Too many requests. Please wait a moment.');
} else if (response.statusCode >= 500) {
  throw Exception('Server error. Please try again later.');
} else {
  throw Exception('API error: ${response.statusCode}');
}
```

---

### Subtask T049 – Add comprehensive empty states

**Purpose**: Ensure every screen has appropriate empty state.

**Steps**:
1. HomeScreen: "Search for a location to get started"
2. SuggestionList: "No results found for your search"
3. SelectedLocationsList: "No locations selected yet"
4. LocationDetailScreen: "Content not available"

**Files**: All screen and widget files

**Parallel?**: No (enhancement of existing UI)

**Example empty state**:
```dart
if (provider.selectedLocations.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.location_off,
          size: 64,
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        Text(
          'No locations selected yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Search and select locations to see them here',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
```

---

### Subtask T050 – Verify rate limiting compliance

**Purpose**: Ensure Nominatim rate limit (1 req/sec) is respected.

**Steps**:
1. Test rapid searches (type quickly, delete, type again)
2. Verify delay logic works correctly
3. Log request timestamps to verify spacing
4. Test with multiple quick searches

**Files**: `lib/repositories/nominatim_geocoding_repository.dart`

**Parallel?**: No (testing existing logic)

**Verification**:
```dart
// Already implemented in T011, verify it works:
if (_lastRequestTime != null) {
  final elapsed = DateTime.now().difference(_lastRequestTime!);
  if (elapsed.inMilliseconds < 1000) {
    await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
  }
}
_lastRequestTime = DateTime.now();
```

---

### Subtask T051 – Add error logging

**Purpose**: Log errors for debugging without exposing to users.

**Steps**:
1. Add debugPrint statements for caught exceptions
2. Log API response errors
3. Log parsing failures
4. Don't log sensitive data (API keys, etc.)

**Files**: All repository and provider files

**Parallel?**: No (enhancement of existing error handling)

**Example**:
```dart
} catch (e) {
  debugPrint('Failed to search locations: $e');
  _errorMessage = 'Failed to search locations. Please try again.';
}
```

---

### Subtask T052 – Test all error scenarios

**Purpose**: Systematic testing of error handling.

**Steps**:
1. Test with airplane mode (no network)
2. Test with invalid queries (special characters, very long strings)
3. Test with non-existent locations
4. Test rapid searches (rate limiting)
5. Test navigation during loading states
6. Test with slow network (throttle in DevTools)

**Files**: All files (integration testing)

**Parallel?**: No (final verification)

**Error Scenario Checklist**:
- [ ] No internet connection - handled
- [ ] Timeout (>10s) - handled
- [ ] Invalid location name - handled
- [ ] Special characters in query - handled
- [ ] Empty search query - handled
- [ ] Wikipedia article not found - handled
- [ ] Rate limit hit - prevented
- [ ] Server error (500+) - handled
- [ ] Malformed JSON response - handled
- [ ] Image load failure - handled

## Test Strategy

No automated tests required per constitution.

**Manual Testing Checklist**:
- [ ] Enable airplane mode - error message displayed
- [ ] Search with "&, %, #" - no crashes
- [ ] Search for "asdfghjkl" - handles no results
- [ ] Type very quickly - rate limit respected
- [ ] Remove network mid-search - graceful failure
- [ ] Navigate during loading - no crashes
- [ ] Try to add duplicate - prevented with message
- [ ] All empty states display correctly

## Risks & Mitigations

**Risk**: Uncaught exceptions crash the app
- **Mitigation**: Wrap all async operations in try-catch

**Risk**: Error messages too technical for users
- **Mitigation**: Use plain language, avoid technical jargon

**Risk**: Rate limit violations causing API blocks
- **Mitigation**: Thorough testing of rate limiting logic

## Definition of Done Checklist

- [ ] Network errors handled with user-friendly messages
- [ ] Special characters in queries handled
- [ ] All HTTP status codes handled (404, 429, 500+)
- [ ] Empty states implemented for all screens
- [ ] Rate limiting verified and compliant
- [ ] Error logging added for debugging
- [ ] All error scenarios tested
- [ ] No uncaught exceptions
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual testing checklist passed
- [ ] All spec.md edge cases addressed
- [ ] tasks.md updated to mark WP08 complete

## Review Guidance

**Verify**:
- All try-catch blocks have meaningful error messages
- Error messages are user-friendly (no technical jargon)
- Empty states are visually consistent
- Rate limiting logic correct
- No console errors during error scenarios
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

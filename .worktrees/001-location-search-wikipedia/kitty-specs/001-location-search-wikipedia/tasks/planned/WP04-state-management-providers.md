---
work_package_id: "WP04"
subtasks:
  - "T016"
  - "T017"
  - "T018"
  - "T019"
  - "T020"
  - "T021"
title: "State Management (Providers)"
phase: "Phase 1 - Business Logic"
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
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP04-state-management-providers.md*

# Work Package Prompt: WP04 – State Management (Providers)

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Implement Provider-based state management for location search and Wikipedia content.

**Success Criteria**:
- LocationProvider manages search state (query, suggestions, selected locations)
- WikipediaProvider manages content loading state
- Both providers use ChangeNotifier pattern
- Loading and error states properly handled
- MultiProvider configured in main.dart

## Context & Constraints

**Prerequisites**: WP02 (models) and WP03 (repositories) complete

**References**:
- [plan.md](../../plan.md) - See "State Management" section
- [research.md](../../research.md) - Provider pattern guidance
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle II (Modular Architecture)

**Constraints**:
- Use Provider package (official Flutter recommendation)
- Follow ChangeNotifier pattern
- Avoid business logic in UI widgets

## Subtasks & Detailed Guidance

### Subtask T016 – Create LocationProvider

**Purpose**: Manage location search state and selected locations list.

**Steps**:
1. Create `lib/providers/location_provider.dart`
2. Extend ChangeNotifier
3. Add fields: _suggestions, _selectedLocations, _isLoading, _errorMessage
4. Add searchLocations(query) method calling repository
5. Add selectLocation(LocationSuggestion) converting to Location
6. Add removeLocation(locationId) method
7. Call notifyListeners() after state changes
8. Add getters for all private fields

**Files**: `lib/providers/location_provider.dart`

**Parallel?**: Yes (independent of WikipediaProvider)

**Key implementation**:
```dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class LocationProvider extends ChangeNotifier {
  final GeocodingRepository _repository;

  List<LocationSuggestion> _suggestions = [];
  List<Location> _selectedLocations = [];
  bool _isLoading = false;
  String? _errorMessage;

  LocationProvider(this._repository);

  // Getters
  List<LocationSuggestion> get suggestions => _suggestions;
  List<Location> get selectedLocations => _selectedLocations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Searches for locations matching the query.
  Future<void> searchLocations(String query) async {
    if (query.isEmpty) {
      _suggestions = [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _suggestions = await _repository.searchLocations(query);
      _errorMessage = null;
    } catch (e) {
      _suggestions = [];
      _errorMessage = 'Failed to search locations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a selected location to the list.
  void selectLocation(LocationSuggestion suggestion) {
    // Convert suggestion to Location (will need full data from repository)
    // For now, create Location from suggestion data
    final location = Location(
      id: suggestion.id,
      displayName: suggestion.displayName,
      latitude: 0.0, // TODO: Get from full location data
      longitude: 0.0,
    );

    // Avoid duplicates
    if (!_selectedLocations.any((loc) => loc.id == location.id)) {
      _selectedLocations.add(location);
      notifyListeners();
    }
  }

  /// Removes a location from the selected list.
  void removeLocation(String locationId) {
    _selectedLocations.removeWhere((loc) => loc.id == locationId);
    notifyListeners();
  }

  /// Clears search suggestions.
  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    // Repository disposal handled elsewhere
    super.dispose();
  }
}
```

---

### Subtask T017 – Enhance Location model for full data

**Purpose**: Add method to fetch full Location data from suggestion.

**Steps**:
1. Update LocationProvider.selectLocation() to fetch full location data
2. Use repository to get complete coordinates
3. Handle errors during selection

**Files**: `lib/providers/location_provider.dart`

**Parallel?**: No (requires T016)

**Update selectLocation method**:
```dart
/// Adds a selected location to the list.
/// Fetches full location data including coordinates.
Future<void> selectLocation(LocationSuggestion suggestion) async {
  _isLoading = true;
  notifyListeners();

  try {
    // Search for the specific location to get full data
    final results = await _repository.searchLocations(suggestion.displayName);
    final fullLocation = results.firstWhere(
      (loc) => loc.id == suggestion.id,
      orElse: () => throw Exception('Location not found'),
    );

    // Convert to Location (assuming we have a method to do this)
    // Or modify repository to return Location directly
    final location = Location(
      id: fullLocation.id,
      displayName: fullLocation.displayName,
      latitude: 0.0, // Parse from full data
      longitude: 0.0,
    );

    // Avoid duplicates
    if (!_selectedLocations.any((loc) => loc.id == location.id)) {
      _selectedLocations.add(location);
    }
  } catch (e) {
    _errorMessage = 'Failed to select location: $e';
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

### Subtask T018 – Create WikipediaProvider

**Purpose**: Manage Wikipedia content loading state.

**Steps**:
1. Create `lib/providers/wikipedia_provider.dart`
2. Extend ChangeNotifier
3. Add fields: _content (Map<String, WikipediaContent>), _isLoading, _errorMessage
4. Add fetchContent(locationTitle) method calling repository
5. Cache content by title to avoid refetching
6. Call notifyListeners() after state changes
7. Add getters for all private fields

**Files**: `lib/providers/wikipedia_provider.dart`

**Parallel?**: Yes (independent of LocationProvider)

**Key implementation**:
```dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class WikipediaProvider extends ChangeNotifier {
  final WikipediaRepository _repository;

  final Map<String, WikipediaContent> _content = {};
  bool _isLoading = false;
  String? _errorMessage;

  WikipediaProvider(this._repository);

  // Getters
  Map<String, WikipediaContent> get content => _content;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches Wikipedia content for a given location title.
  /// Results are cached to avoid redundant API calls.
  Future<void> fetchContent(String title) async {
    // Return cached content if available
    if (_content.containsKey(title)) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final wikiContent = await _repository.fetchSummary(title);
      _content[title] = wikiContent;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch Wikipedia content: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gets cached content for a title, or null if not loaded.
  WikipediaContent? getContent(String title) {
    return _content[title];
  }

  /// Clears all cached content.
  void clearCache() {
    _content.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // Repository disposal handled elsewhere
    super.dispose();
  }
}
```

---

### Subtask T019 – Create providers barrel file

**Purpose**: Simplify imports across the application.

**Steps**:
1. Create `lib/providers/providers.dart`
2. Export all provider classes

**Files**: `lib/providers/providers.dart`

**Parallel?**: No (requires T016, T018 complete)

**Example**:
```dart
export 'location_provider.dart';
export 'wikipedia_provider.dart';
```

---

### Subtask T020 – Configure MultiProvider in main.dart

**Purpose**: Make providers available throughout the widget tree.

**Steps**:
1. Update `lib/main.dart`
2. Import provider package and local providers
3. Wrap MaterialApp with MultiProvider
4. Register LocationProvider and WikipediaProvider
5. Initialize repositories in providers

**Files**: `lib/main.dart`

**Parallel?**: No (requires T016, T018, T019 complete)

**Example main.dart update**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'repositories/repositories.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocationProvider(
            NominatimGeocodingRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WikipediaProvider(
            RestWikipediaRepository(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Flutter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Location Search'),
        ),
        body: const Center(
          child: Text('Providers configured - Ready for UI'),
        ),
      ),
    );
  }
}
```

---

### Subtask T021 – Add provider documentation

**Purpose**: Document state management patterns and usage.

**Steps**:
1. Add dartdoc comments to all provider classes
2. Document methods and state changes
3. Add usage examples with Consumer and Provider.of patterns
4. Document when to use notifyListeners()

**Files**: All provider files

**Parallel?**: No (requires T016-T020 complete)

**Example documentation**:
```dart
/// Manages location search state and selected locations.
///
/// This provider handles:
/// - Search query execution
/// - Location suggestions
/// - Selected locations list
/// - Loading and error states
///
/// Usage in widgets:
/// ```dart
/// // Listen to changes
/// Consumer<LocationProvider>(
///   builder: (context, provider, child) {
///     if (provider.isLoading) {
///       return CircularProgressIndicator();
///     }
///     return ListView(
///       children: provider.suggestions.map((s) => ListTile(...)).toList(),
///     );
///   },
/// )
///
/// // Call methods
/// Provider.of<LocationProvider>(context, listen: false)
///   .searchLocations('Berlin');
/// ```
class LocationProvider extends ChangeNotifier {
  // ...
}
```

## Test Strategy

No tests required per constitution (testing on-demand only).

**Manual Verification**:
1. Run app with providers configured
2. Test searchLocations with various queries
3. Verify suggestions update UI
4. Test selectLocation and verify list updates
5. Test Wikipedia content fetching
6. Verify loading states display correctly
7. Test error scenarios (network off)

## Risks & Mitigations

**Risk**: Provider methods called with listen=true causing rebuild loops
- **Mitigation**: Use listen=false for method calls, document pattern clearly

**Risk**: Memory leaks from undisposed providers
- **Mitigation**: Providers auto-disposed by ChangeNotifierProvider

**Risk**: State not updating in UI
- **Mitigation**: Ensure notifyListeners() called after every state change

## Definition of Done Checklist

- [ ] LocationProvider created with search and selection logic
- [ ] WikipediaProvider created with content caching
- [ ] providers.dart barrel file created
- [ ] MultiProvider configured in main.dart
- [ ] All repositories initialized in providers
- [ ] All classes have dartdoc comments
- [ ] Usage examples documented
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual testing confirms state updates work
- [ ] Loading and error states handled correctly
- [ ] tasks.md updated to mark WP04 complete

## Review Guidance

**Verify**:
- notifyListeners() called after every state mutation
- Error handling comprehensive (try-catch in all async methods)
- Loading states set correctly (before/after async operations)
- Documentation includes Consumer and Provider.of examples
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

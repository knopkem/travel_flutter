---
work_package_id: "WP05"
subtasks:
  - "T022"
  - "T023"
  - "T024"
  - "T025"
  - "T026"
  - "T027"
  - "T028"
  - "T029"
  - "T030"
  - "T031"
title: "User Story 1: Search & Select Locations"
phase: "Phase 2 - UI Implementation"
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
  - timestamp: "2025-12-15T14:45:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "28247"
    action: "Started implementation"
  - timestamp: "2025-12-15T15:00:00Z"
    lane: "for_review"
    agent: "claude"
    shell_pid: "28247"
    action: "Completed all subtasks (T022-T031): HomeScreen with search/suggestions/selections, SearchField with 300ms debouncing, SuggestionList, SelectedLocationsList, LocationDetailScreen for Wikipedia display. Keyboard handling, loading indicators, empty states, error handling, duplicate prevention. Implements US-001 and FR-001 through FR-007. Zero analyzer warnings."
---
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP05-user-story-1-search-select.md*

# Work Package Prompt: WP05 – User Story 1: Search & Select Locations

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Implement the main search screen with location input, suggestions dropdown, and selected locations list.

**Success Criteria**:
- User can type in search field
- Suggestions appear after 300ms debounce
- User can select suggestions
- Selected locations appear as buttons
- Minimum 3 characters required for search
- Loading indicator appears during search

**User Story**: "As a user, I want to search for locations by typing in a search field, see matching suggestions, and select locations that appear as buttons below the search field."

## Context & Constraints

**Prerequisites**: WP04 complete (providers configured)

**References**:
- [spec.md](../../spec.md) - User Story US-001, Requirements FR-001 through FR-007
- [research.md](../../research.md) - Debouncing pattern
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle II (Modular Architecture)

**Constraints**:
- 300ms debounce on search input
- Minimum 3 characters for search
- Maximum 10 suggestions displayed
- 60fps UI performance

## Subtasks & Detailed Guidance

### Subtask T022 – Create HomeScreen widget

**Purpose**: Main screen container for location search functionality.

**Steps**:
1. Create `lib/screens/home_screen.dart`
2. Create StatefulWidget extending StatefulWidget
3. Add AppBar with title "Location Search"
4. Create Column layout: SearchField + SuggestionList + SelectedLocationsList
5. Wrap in Consumer<LocationProvider> to access state

**Files**: `lib/screens/home_screen.dart`

**Parallel?**: No (foundational screen)

**Example structure**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/search_field.dart';
import '../widgets/suggestion_list.dart';
import '../widgets/selected_locations_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SearchField(),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<LocationProvider>(
                builder: (context, provider, child) {
                  if (provider.suggestions.isNotEmpty) {
                    return const SuggestionList();
                  } else if (provider.selectedLocations.isNotEmpty) {
                    return const SelectedLocationsList();
                  } else {
                    return const Center(
                      child: Text('Search for a location to get started'),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Subtask T023 – Create SearchField widget

**Purpose**: Text input with debouncing for location search.

**Steps**:
1. Create `lib/widgets/search_field.dart`
2. Create StatefulWidget with TextEditingController
3. Implement debouncing: wait 300ms after last keystroke
4. Call provider.searchLocations() after debounce
5. Show clear button when text present
6. Display error message if search fails
7. Show loading indicator during search

**Files**: `lib/widgets/search_field.dart`

**Parallel?**: Yes (can develop alongside other widgets)

**Key implementation with debouncing**:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounce?.cancel();

    // Start new timer
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 3) {
        Provider.of<LocationProvider>(context, listen: false)
            .searchLocations(query);
      } else if (query.isEmpty) {
        Provider.of<LocationProvider>(context, listen: false)
            .clearSuggestions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Search for a location',
                hintText: 'e.g., Berlin, Paris, Tokyo',
                prefixIcon: provider.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          provider.clearSuggestions();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

---

### Subtask T024 – Create SuggestionList widget

**Purpose**: Display location search results in a scrollable list.

**Steps**:
1. Create `lib/widgets/suggestion_list.dart`
2. Use Consumer<LocationProvider> to access suggestions
3. Display ListView of suggestions
4. Each item shows displayName
5. OnTap: call provider.selectLocation() and clear search field
6. Show "No results" message if empty after search

**Files**: `lib/widgets/suggestion_list.dart`

**Parallel?**: Yes (independent widget)

**Example**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class SuggestionList extends StatelessWidget {
  const SuggestionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, child) {
        if (provider.suggestions.isEmpty) {
          return const Center(
            child: Text('No locations found'),
          );
        }

        return ListView.builder(
          itemCount: provider.suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = provider.suggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(suggestion.displayName),
              onTap: () {
                provider.selectLocation(suggestion);
                provider.clearSuggestions();
              },
            );
          },
        );
      },
    );
  }
}
```

---

### Subtask T025 – Create SelectedLocationsList widget

**Purpose**: Display selected locations as interactive buttons.

**Steps**:
1. Create `lib/widgets/selected_locations_list.dart`
2. Use Consumer<LocationProvider> to access selectedLocations
3. Display scrollable list of location buttons
4. Each button shows location displayName
5. OnTap: navigate to LocationDetailScreen
6. Show remove icon (X) to unselect location

**Files**: `lib/widgets/selected_locations_list.dart`

**Parallel?**: Yes (independent widget)

**Example**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../screens/location_detail_screen.dart';

class SelectedLocationsList extends StatelessWidget {
  const SelectedLocationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, child) {
        if (provider.selectedLocations.isEmpty) {
          return const Center(
            child: Text('No locations selected'),
          );
        }

        return ListView.builder(
          itemCount: provider.selectedLocations.length,
          itemBuilder: (context, index) {
            final location = provider.selectedLocations[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: const Icon(Icons.place),
                title: Text(location.displayName),
                subtitle: Text('Lat: ${location.latitude}, Lon: ${location.longitude}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    provider.removeLocation(location.id);
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationDetailScreen(location: location),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
```

---

### Subtask T026 – Update main.dart to use HomeScreen

**Purpose**: Set HomeScreen as the main entry point.

**Steps**:
1. Update `lib/main.dart`
2. Import HomeScreen
3. Replace placeholder Scaffold with HomeScreen()

**Files**: `lib/main.dart`

**Parallel?**: No (requires T022 complete)

**Update**:
```dart
import 'screens/home_screen.dart';

// In MyApp.build():
return MaterialApp(
  title: 'Travel Flutter App',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  ),
  home: const HomeScreen(),
);
```

---

### Subtask T027 – Create LocationButton widget (reusable component)

**Purpose**: Reusable button widget for displaying locations.

**Steps**:
1. Create `lib/widgets/location_button.dart`
2. Accept location and onTap callback
3. Style as elevated button with location icon
4. Display location displayName

**Files**: `lib/widgets/location_button.dart`

**Parallel?**: Yes (optional enhancement)

**Example**:
```dart
import 'package:flutter/material.dart';
import '../models/models.dart';

class LocationButton extends StatelessWidget {
  final Location location;
  final VoidCallback onTap;

  const LocationButton({
    super.key,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.place),
      label: Text(location.displayName),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(12.0),
      ),
    );
  }
}
```

---

### Subtask T028 – Add empty state messages

**Purpose**: User-friendly messages when no data available.

**Steps**:
1. Update SearchField to show hint when empty
2. Update SuggestionList to show "No results found"
3. Update SelectedLocationsList to show "No locations selected"
4. Add instructional text: "Type at least 3 characters to search"

**Files**: Various widget files

**Parallel?**: No (requires T022-T025 complete)

---

### Subtask T029 – Add loading indicators

**Purpose**: Visual feedback during async operations.

**Steps**:
1. Show CircularProgressIndicator in SearchField when loading
2. Show shimmer or skeleton in SuggestionList during fetch (optional)
3. Disable interaction during loading states

**Files**: `lib/widgets/search_field.dart`, `lib/widgets/suggestion_list.dart`

**Parallel?**: No (requires T023, T024 complete)

---

### Subtask T030 – Implement keyboard handling

**Purpose**: Improve UX with keyboard management.

**Steps**:
1. Dismiss keyboard when suggestion tapped
2. Add "Done" action to keyboard
3. Handle Enter key to trigger search

**Files**: `lib/widgets/search_field.dart`

**Parallel?**: No (enhancement after T023)

**Example**:
```dart
TextField(
  controller: _controller,
  textInputAction: TextInputAction.search,
  onSubmitted: (value) {
    if (value.length >= 3) {
      Provider.of<LocationProvider>(context, listen: false)
          .searchLocations(value);
    }
  },
  // ... other properties
)
```

---

### Subtask T031 – Add widget documentation

**Purpose**: Document widget usage and parameters.

**Steps**:
1. Add dartdoc comments to all widgets
2. Document parameters and callbacks
3. Add usage examples

**Files**: All widget files

**Parallel?**: No (requires all widgets complete)

## Test Strategy

No automated tests required per constitution.

**Manual Testing Checklist**:
- [ ] Type less than 3 characters - no search triggered
- [ ] Type 3+ characters - search triggers after 300ms
- [ ] Rapid typing - only last query executes
- [ ] Select suggestion - appears in selected list
- [ ] Tap location button - navigates to detail screen
- [ ] Remove location - disappears from list
- [ ] Network error - error message displayed
- [ ] Clear search field - suggestions disappear
- [ ] Multiple locations - all appear correctly
- [ ] Duplicate selection - prevented

## Risks & Mitigations

**Risk**: Debouncing not working, too many API calls
- **Mitigation**: Test debounce logic thoroughly, add logging

**Risk**: UI freezes during network requests
- **Mitigation**: Ensure all API calls are async, show loading indicators

**Risk**: Keyboard covers input field
- **Mitigation**: Use SingleChildScrollView or ensure proper padding

## Definition of Done Checklist

- [ ] HomeScreen created with proper layout
- [ ] SearchField with 300ms debouncing implemented
- [ ] SuggestionList displays search results
- [ ] SelectedLocationsList displays selected locations
- [ ] LocationButton component created (optional)
- [ ] main.dart updated to use HomeScreen
- [ ] Empty states implemented
- [ ] Loading indicators displayed
- [ ] Keyboard handling implemented
- [ ] All widgets documented
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual testing checklist passed
- [ ] User Story US-001 acceptance criteria met
- [ ] tasks.md updated to mark WP05 complete

## Review Guidance

**Verify**:
- Debouncing works correctly (test with rapid typing)
- No duplicate locations in selected list
- Error messages are user-friendly
- Loading states don't block UI
- Keyboard dismisses appropriately
- Code formatted with `dart format`
- Widgets are reusable and modular

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

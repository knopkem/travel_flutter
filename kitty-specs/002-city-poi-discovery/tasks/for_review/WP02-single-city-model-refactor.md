---
work_package_id: "WP02"
subtasks:
  - "T009"
  - "T010"
  - "T011"
  - "T012"
  - "T013"
  - "T014"
  - "T015"
title: "Single City Model Refactor"
phase: "Phase 0 - Foundation"
lane: "for_review"
assignee: ""
agent: "claude"
shell_pid: "68023"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-18T08:24:50+0100"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP02 – Single City Model Refactor

## Objectives & Success Criteria

**Goal**: Refactor LocationProvider from multi-city list to single active city model; update UI to reflect single-city selection paradigm.

**Success Criteria**:
- Search for "Paris", select it → only Paris active
- Search for "Tokyo", select it → Paris deselected, Tokyo active
- UI shows single city (no list), search replaces current selection
- No crashes, all existing search functionality preserved

## Context & Constraints

**Related Documents**:
- [spec.md](../spec.md) - User Story 1 (FR-001, FR-002: single city model)
- [data-model.md](../data-model.md) - LocationProvider refactoring details
- Feature 001 code: `lib/providers/location_provider.dart`, `lib/screens/home_screen.dart`

**Architectural Decisions**:
- Breaking change from feature 001: `List<Location>` → `City?`
- Maintain ChangeNotifier pattern for state management
- Search functionality unchanged, only selection behavior changes

## Subtasks & Detailed Guidance

### T009 – Modify LocationProvider to single city model
- Change `List<Location> _selectedLocations` to `City? _selectedCity`
- Update all methods: `selectCity(City city)` replaces current, no add-to-list logic
- Update getters: `get selectedCity` returns nullable City, `get hasSelectedCity` boolean
- Maintain `notifyListeners()` calls for UI updates

### T010 – Update LocationProvider.selectCity() method
- Replace add-to-list logic with simple assignment: `_selectedCity = city`
- Remove duplicate checking (no list to check)
- Notify listeners after assignment

### T011 – Add LocationProvider.clearCity() method
- New method: `void clearCity() { _selectedCity = null; notifyListeners(); }`
- Called when user wants to deselect city (optional feature)

### T012 – Update LocationProvider getters
- Change: `List<Location> get selectedLocations` → `City? get selectedCity`
- Add: `bool get hasSelectedCity => _selectedCity != null`
- Remove any list-based getters (count, isEmpty, etc.)

### T013 – Modify HomeScreen for single city UI
- Remove list display of selected cities (was showing multiple chips/cards)
- Show single city display: name + country in header or under search field
- Update search result handling: selecting suggestion immediately navigates to city details
- Remove "deselect" buttons (no multi-select)

### T014 – Remove SelectedLocationsList widget
- Delete `lib/widgets/selected_locations_list.dart` (no longer needed)
- Remove all imports/references to this widget in HomeScreen

### T015 – Update SuggestionList widget
- Change onTap behavior: Instead of adding to list, call `locationProvider.selectCity(city)` and navigate
- Consider: Auto-navigate to city details screen on selection (UX improvement)

## Risks & Mitigations

- **Risk**: Breaking existing tests from feature 001
  - **Mitigation**: Update tests to expect single city, add new test cases
- **Risk**: User confusion if they expect multi-select
  - **Mitigation**: Clear UI indicates single city selection (search field placeholder "Search for a city")

## Definition of Done Checklist

- [ ] LocationProvider uses `City?` instead of `List<Location>`
- [ ] Selecting new city replaces previous selection
- [ ] UI updated to show single city (no list display)
- [ ] SelectedLocationsList widget deleted
- [ ] Search and selection work smoothly
- [ ] No lint errors
- [ ] Runs without crashes

## Review Guidance

- Verify only one city can be active at a time
- Test rapid city switching (no race conditions)
- Check UI clarity (obvious that only one city is selected)

## Activity Log

- 2025-12-18T08:24:50+0100 – system – lane=planned – Prompt created via /spec-kitty.tasks
- 2025-12-18T07:42:18Z – claude – shell_pid=68023 – lane=doing – Started WP02: Single City Model Refactor
- 2025-12-18T07:47:23Z – claude – shell_pid=68023 – lane=for_review – Completed WP02: All 7 subtasks implemented

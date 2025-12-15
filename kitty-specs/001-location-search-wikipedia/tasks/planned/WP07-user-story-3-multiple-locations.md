---
work_package_id: "WP07"
subtasks:
  - "T041"
  - "T042"
  - "T043"
  - "T044"
  - "T045"
title: "User Story 3: Multiple Locations"
phase: "Phase 2 - UI Implementation"
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
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP07-user-story-3-multiple-locations.md*

# Work Package Prompt: WP07 – User Story 3: Multiple Locations

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Support multiple selected locations with scrollable lists and state preservation.

**Success Criteria**:
- User can select multiple locations (no enforced limit, but UI handles many)
- Selected locations list is scrollable
- Duplicate locations prevented
- State persists during navigation (back from detail screen)
- UI performs well with 10+ locations

**User Story**: "As a user, I want to select multiple locations and see them all displayed as buttons, so I can compare different places."

## Context & Constraints

**Prerequisites**: WP05, WP06 complete (basic navigation working)

**References**:
- [spec.md](../../spec.md) - User Story US-003, Requirements FR-013 through FR-015
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle III (Performance)

**Constraints**:
- 60fps UI performance with many items
- State should not be lost during navigation
- Scrolling should be smooth

## Subtasks & Detailed Guidance

### Subtask T041 – Enhance SelectedLocationsList for scrolling

**Purpose**: Ensure list handles many locations smoothly.

**Steps**:
1. Verify ListView.builder is used (already implemented in T025)
2. Test with 10+ locations
3. Ensure smooth scrolling performance
4. Add scroll indicators if needed

**Files**: `lib/widgets/selected_locations_list.dart`

**Parallel?**: No (enhancement of existing widget)

**Verification**:
```dart
// Already implemented in T025, verify:
ListView.builder(
  itemCount: provider.selectedLocations.length,
  itemBuilder: (context, index) {
    // ... build each item
  },
)
```

---

### Subtask T042 – Prevent duplicate location selection

**Purpose**: Block adding the same location twice.

**Steps**:
1. Update LocationProvider.selectLocation() method
2. Check if location.id already in selectedLocations
3. Show SnackBar message: "Location already selected"
4. Don't add duplicate

**Files**: `lib/providers/location_provider.dart`

**Parallel?**: No (enhancement of existing provider)

**Example**:
```dart
void selectLocation(LocationSuggestion suggestion) {
  // ... existing selection logic ...

  // Check for duplicates
  if (_selectedLocations.any((loc) => loc.id == location.id)) {
    // Don't add, maybe log or show message
    return;
  }

  _selectedLocations.add(location);
  notifyListeners();
}
```

---

### Subtask T043 – Add duplicate selection feedback

**Purpose**: Inform user when trying to add duplicate.

**Steps**:
1. Update SuggestionList to show SnackBar on duplicate
2. Detect when selectLocation returns false/void without adding
3. Display message: "This location is already selected"

**Files**: `lib/widgets/suggestion_list.dart`

**Parallel?**: No (requires T042 complete)

**Example**:
```dart
onTap: () {
  final provider = Provider.of<LocationProvider>(context, listen: false);
  final isDuplicate = provider.selectedLocations
      .any((loc) => loc.id == suggestion.id);
  
  if (isDuplicate) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This location is already selected'),
        duration: Duration(seconds: 2),
      ),
    );
  } else {
    provider.selectLocation(suggestion);
    provider.clearSuggestions();
  }
},
```

---

### Subtask T044 – Verify state preservation during navigation

**Purpose**: Ensure selected locations persist when navigating back from detail screen.

**Steps**:
1. Navigate to LocationDetailScreen
2. Press back button
3. Verify selected locations still displayed
4. Verify provider state maintained

**Files**: All relevant files (verification task)

**Parallel?**: No (integration testing after T041-T043)

**Test Cases**:
- Select 3 locations
- Tap first location to view details
- Press back
- Verify all 3 locations still displayed

---

### Subtask T045 – Performance test with many locations

**Purpose**: Verify UI performs well with 10+ locations.

**Steps**:
1. Add 15-20 locations to selected list
2. Scroll through list
3. Verify 60fps performance (no lag)
4. Verify memory usage is reasonable
5. Test navigation with many locations

**Files**: All relevant files (performance testing)

**Parallel?**: No (integration testing after all enhancements)

**Performance Checklist**:
- [ ] Smooth scrolling with 20 locations
- [ ] No frame drops during scroll
- [ ] Navigation remains fast
- [ ] No memory leaks (check with DevTools)

## Test Strategy

No automated tests required per constitution.

**Manual Testing Checklist**:
- [ ] Add 1 location - displays correctly
- [ ] Add 10 locations - all displayed, smooth scrolling
- [ ] Add 20 locations - performance acceptable
- [ ] Try adding duplicate - prevented with message
- [ ] Remove locations - list updates correctly
- [ ] Navigate to detail - state preserved on back
- [ ] Search while locations selected - both lists visible
- [ ] Clear search - return to selected locations view

## Risks & Mitigations

**Risk**: Poor performance with many locations
- **Mitigation**: Use ListView.builder (lazy loading), test with large datasets

**Risk**: State lost during navigation
- **Mitigation**: Use Provider for state management (persists across screens)

**Risk**: Confusing UX when duplicate selected
- **Mitigation**: Show clear feedback with SnackBar

## Definition of Done Checklist

- [ ] SelectedLocationsList handles many locations smoothly
- [ ] Duplicate prevention implemented
- [ ] SnackBar feedback for duplicates
- [ ] State preservation verified
- [ ] Performance tested with 20+ locations
- [ ] All edge cases handled (empty, single, many)
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual testing checklist passed
- [ ] User Story US-003 acceptance criteria met
- [ ] tasks.md updated to mark WP07 complete

## Review Guidance

**Verify**:
- No performance degradation with many items
- Duplicate prevention logic correct
- State management working across navigation
- SnackBar messages are clear and helpful
- Scrolling is smooth (60fps)
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

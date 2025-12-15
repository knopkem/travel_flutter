---
work_package_id: "WP06"
subtasks:
  - "T032"
  - "T033"
  - "T034"
  - "T035"
  - "T036"
  - "T037"
  - "T038"
  - "T039"
  - "T040"
title: "User Story 2: View Location Information"
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
*Path: kitty-specs/001-location-search-wikipedia/tasks/planned/WP06-user-story-2-view-information.md*

# Work Package Prompt: WP06 – User Story 2: View Location Information

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Implement Wikipedia content detail screen with back navigation.

**Success Criteria**:
- Tapping location button navigates to detail screen
- Wikipedia content loads and displays
- Back button returns to home screen
- Thumbnail image displays if available
- Loading indicator shown while fetching
- Error message shown if content unavailable

**User Story**: "As a user, I want to tap a selected location button to view Wikipedia information about that location in a new screen with a back button."

## Context & Constraints

**Prerequisites**: WP05 complete (home screen navigation working)

**References**:
- [spec.md](../../spec.md) - User Story US-002, Requirements FR-008 through FR-012
- [contracts/wikipedia-api.md](../../contracts/wikipedia-api.md) - API response format
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle II (Modular Architecture)

**Constraints**:
- Load time < 3 seconds per constitution
- Handle missing articles gracefully
- Support back button and system back gesture

## Subtasks & Detailed Guidance

### Subtask T032 – Create LocationDetailScreen widget

**Purpose**: Detail screen container for Wikipedia content.

**Steps**:
1. Create `lib/screens/location_detail_screen.dart`
2. Accept Location parameter in constructor
3. Add AppBar with location displayName as title
4. Add back button in AppBar (automatic with MaterialApp)
5. Create Column layout for content sections
6. Wrap body in Consumer<WikipediaProvider>

**Files**: `lib/screens/location_detail_screen.dart`

**Parallel?**: No (foundational screen)

**Example structure**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/wikipedia_content_widget.dart';

class LocationDetailScreen extends StatefulWidget {
  final Location location;

  const LocationDetailScreen({
    super.key,
    required this.location,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch Wikipedia content on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WikipediaProvider>(context, listen: false)
          .fetchContent(widget.location.displayName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<WikipediaProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final content = provider.getContent(widget.location.displayName);
          if (content == null) {
            return const Center(child: Text('No content available'));
          }

          return WikipediaContentWidget(content: content);
        },
      ),
    );
  }
}
```

---

### Subtask T033 – Create WikipediaContentWidget

**Purpose**: Display Wikipedia article content with formatting.

**Steps**:
1. Create `lib/widgets/wikipedia_content_widget.dart`
2. Accept WikipediaContent parameter
3. Display title, thumbnail (if available), and extract
4. Use Card or Container for visual separation
5. Make content scrollable with SingleChildScrollView

**Files**: `lib/widgets/wikipedia_content_widget.dart`

**Parallel?**: Yes (independent widget)

**Example**:
```dart
import 'package:flutter/material.dart';
import '../models/models.dart';

class WikipediaContentWidget extends StatelessWidget {
  final WikipediaContent content;

  const WikipediaContentWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.thumbnailUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  content.thumbnailUrl!,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, size: 100);
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            content.extract,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
```

---

### Subtask T034 – Implement navigation from HomeScreen

**Purpose**: Connect location buttons to detail screen.

**Steps**:
1. Update SelectedLocationsList widget (already done in T025)
2. Verify Navigator.push works correctly
3. Test back navigation returns to home screen

**Files**: `lib/widgets/selected_locations_list.dart`

**Parallel?**: No (verification task after T032-T033)

---

### Subtask T035 – Add loading state for Wikipedia content

**Purpose**: Show progress while fetching Wikipedia data.

**Steps**:
1. Display CircularProgressIndicator during fetch
2. Show loading message: "Loading Wikipedia content..."
3. Disable interaction during loading

**Files**: `lib/screens/location_detail_screen.dart`

**Parallel?**: No (enhancement after T032)

---

### Subtask T036 – Handle Wikipedia fetch errors

**Purpose**: Gracefully handle article not found or network errors.

**Steps**:
1. Display error message from provider
2. Add retry button if fetch fails
3. Show user-friendly messages: "Article not found", "Network error"
4. Style error state with icon and color

**Files**: `lib/screens/location_detail_screen.dart`

**Parallel?**: No (enhancement after T032)

**Example error widget**:
```dart
if (provider.errorMessage != null) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          provider.errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            provider.fetchContent(widget.location.displayName);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
```

---

### Subtask T037 – Add thumbnail image handling

**Purpose**: Display Wikipedia article thumbnail if available.

**Steps**:
1. Check if thumbnailUrl is not null
2. Use Image.network with error handling
3. Add placeholder if image fails to load
4. Style image with rounded corners and shadows

**Files**: `lib/widgets/wikipedia_content_widget.dart`

**Parallel?**: No (enhancement after T033)

---

### Subtask T038 – Improve content formatting

**Purpose**: Enhance readability of Wikipedia content.

**Steps**:
1. Use appropriate Typography styles (headline, body)
2. Add spacing between sections
3. Add dividers or visual separators
4. Consider max width for readability on tablets

**Files**: `lib/widgets/wikipedia_content_widget.dart`

**Parallel?**: No (enhancement after T033)

---

### Subtask T039 – Add Wikipedia attribution

**Purpose**: Comply with Wikipedia content guidelines.

**Steps**:
1. Add footer text: "Content from Wikipedia"
2. Add link icon or external link indicator
3. Consider adding "Read more on Wikipedia" link (optional)

**Files**: `lib/widgets/wikipedia_content_widget.dart`

**Parallel?**: No (enhancement after T033)

**Example**:
```dart
const SizedBox(height: 24),
const Divider(),
Row(
  children: [
    const Icon(Icons.info_outline, size: 16),
    const SizedBox(width: 8),
    Text(
      'Content from Wikipedia',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ],
),
```

---

### Subtask T040 – Add detail screen documentation

**Purpose**: Document screen behavior and navigation.

**Steps**:
1. Add dartdoc comments to LocationDetailScreen
2. Document navigation parameters
3. Document lifecycle (when content is fetched)

**Files**: All detail screen files

**Parallel?**: No (requires all components complete)

## Test Strategy

No automated tests required per constitution.

**Manual Testing Checklist**:
- [ ] Tap location button - navigates to detail screen
- [ ] Wikipedia content loads successfully
- [ ] Thumbnail displays if available
- [ ] Back button returns to home screen
- [ ] Loading indicator appears during fetch
- [ ] Error message shown if article not found
- [ ] Retry button works after error
- [ ] System back gesture works
- [ ] Content is scrollable
- [ ] Image placeholder shown if thumbnail fails

## Risks & Mitigations

**Risk**: Wikipedia article not found for location name
- **Mitigation**: Parse location name to extract city/place name, handle 404 gracefully

**Risk**: Long load times frustrating users
- **Mitigation**: Show loading indicator immediately, cache content in provider

**Risk**: Image loading failures
- **Mitigation**: Use errorBuilder in Image.network, show placeholder

## Definition of Done Checklist

- [ ] LocationDetailScreen created
- [ ] WikipediaContentWidget created
- [ ] Navigation from home screen working
- [ ] Wikipedia content fetches and displays
- [ ] Loading state implemented
- [ ] Error handling implemented with retry
- [ ] Thumbnail image handling complete
- [ ] Content formatting enhanced
- [ ] Wikipedia attribution added
- [ ] All widgets documented
- [ ] `flutter analyze` shows zero warnings
- [ ] Manual testing checklist passed
- [ ] User Story US-002 acceptance criteria met
- [ ] tasks.md updated to mark WP06 complete

## Review Guidance

**Verify**:
- Navigation stack correct (can go back multiple times)
- Wikipedia content caching works (no refetch on back/forward)
- Error states are user-friendly
- Loading indicator doesn't block unnecessarily
- Content is readable and well-formatted
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.

# Implementation Plan: Location Search & Wikipedia Browser
*Path: kitty-specs/001-location-search-wikipedia/plan.md*

**Branch**: `001-location-search-wikipedia` | **Date**: 2025-12-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `kitty-specs/001-location-search-wikipedia/spec.md`

## Summary

Build a Flutter mobile app that enables travelers to search for cities worldwide, view them as selectable buttons, and access Wikipedia content for each location. The feature uses OpenStreetMap Nominatim for geocoding (free, no API key) and Wikipedia REST API for content retrieval. Implements Provider pattern for state management with debounced search to minimize API calls.

## Technical Context

**Language/Version**: Flutter 3.x (latest stable) with Dart 3.x (latest stable SDK)

**Primary Dependencies**:
- `provider` (^6.1.0 or latest) - State management
- `http` (^1.1.0 or latest) - HTTP client for API calls
- `flutter_lints` (latest) - Official linting rules

**Storage**: In-memory only (List of Location objects in Provider state). No persistence across app restarts for this phase.

**Testing**: Not required per constitution (testing on-demand only). No test infrastructure for this phase.

**Target Platform**: Mobile (iOS 12+ and Android 6.0+/API 23+)

**Project Type**: Single Flutter mobile app

**Performance Goals**:
- UI maintains 60fps during scrolling and navigation
- Search debounce: 300ms minimum
- API response handling: under 1 second for search, under 3 seconds for Wikipedia content
- Smooth navigation transitions between screens

**Constraints**:
- No API keys required (using free services)
- Nominatim API rate limit: 1 request/second (enforced by debouncing)
- In-memory storage only
- No offline capability (internet required)
- Material Design UI components (standard Flutter widgets)

**Scale/Scope**:
- 2 screens (main search + detail view)
- 3 main data models (Location, LocationSuggestion, WikipediaContent)
- 2 repositories (GeocodingRepository, WikipediaRepository)
- 2 providers (LocationProvider, WikipediaProvider)
- Expected usage: single user, multiple searches per session

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Modern Dependencies & Framework Adoption ✅
- **Status**: PASS
- Using Flutter 3.x and Dart 3.x (latest stable)
- Dependencies: provider (official recommendation), http (official HTTP package), flutter_lints (official)
- All packages are actively maintained with strong community support
- No deprecated packages

### Principle II: Modular Architecture ✅
- **Status**: PASS
- Clear separation: UI → Providers → Repositories → API clients
- Single responsibility: GeocodingRepository handles Nominatim, WikipediaRepository handles Wikipedia
- Minimal coupling: Providers depend on repositories via dependency injection
- Reusable components: Custom widgets for search field, suggestion list, location buttons

### Principle III: Quality-Driven Development (Testing on Demand) ✅
- **Status**: PASS
- No testing required for this feature (not explicitly requested in spec)
- Testing infrastructure will not be created
- Focus on clean code and documentation instead

### Principle IV: Comprehensive Documentation ✅
- **Status**: PASS - Commitment to document
- Dart doc comments (///) for all public APIs
- Inline documentation for complex logic (debouncing, API parsing)
- README.md in project root explaining app purpose and setup
- Code comments for API endpoints and data transformations

### Principle V: Code Quality & Established Patterns ✅
- **Status**: PASS
- Following Flutter/Dart official style guide
- Provider pattern (official recommendation for this complexity level)
- Consistent naming: camelCase for variables/functions, PascalCase for classes
- flutter_lints enabled for static analysis

### Flutter/Dart Technology Standards ✅
- **Status**: PASS
- State management: Provider (approved pattern)
- Navigation: Flutter Navigator (standard push/pop)
- No dependency injection framework needed (simple manual injection)
- Linting: flutter_lints enabled
- Performance: Debouncing for 60fps, optimized list rendering

### Development Workflow & Quality Gates ✅
- **Status**: PASS
- Following spec-kitty workflow
- Code will be formatted with `dart format`
- Flutter analyzer warnings will be addressed
- Documentation will accompany all code changes

**Overall Constitution Compliance**: ✅ PASS - All principles satisfied

## Project Structure

### Documentation (this feature)

```
kitty-specs/001-location-search-wikipedia/
├── plan.md              # This file
├── research.md          # Phase 0 output (API research, patterns)
├── data-model.md        # Phase 1 output (entities and relationships)
├── quickstart.md        # Phase 1 output (developer setup guide)
├── contracts/           # Phase 1 output (API contracts)
│   ├── nominatim-api.md
│   └── wikipedia-api.md
└── checklists/
    └── requirements.md  # Already created by /spec-kitty.specify
```

### Source Code (repository root)

```
lib/
├── main.dart                          # App entry point with Provider setup
├── screens/
│   ├── home_screen.dart              # Main search screen with location list
│   └── location_detail_screen.dart   # Wikipedia content display
├── widgets/
│   ├── search_field.dart             # Debounced text input with autocomplete
│   ├── suggestion_list.dart          # Geocoding results display
│   └── location_button.dart          # Selected location button widget
├── providers/
│   ├── location_provider.dart        # Manages selected locations list
│   └── wikipedia_provider.dart       # Manages Wikipedia content loading
├── repositories/
│   ├── geocoding_repository.dart     # Nominatim API client
│   └── wikipedia_repository.dart     # Wikipedia REST API client
└── models/
    ├── location.dart                 # Location entity
    ├── location_suggestion.dart      # Suggestion entity
    └── wikipedia_content.dart        # Wikipedia content entity

pubspec.yaml                          # Dependencies: provider, http, flutter_lints
README.md                             # Project documentation
analysis_options.yaml                 # flutter_lints configuration
```

**Structure Decision**: Standard Flutter single-app structure selected. This is a mobile-only application with no backend, so the simplified structure with lib/ as the primary source directory is appropriate. Following Flutter conventions for organizing by feature/layer (screens, widgets, providers, repositories, models).

## Complexity Tracking

*No constitutional violations - this section not applicable.*

---

## Phase 0: Research & Discovery

### Research Questions

1. **Nominatim API**: Geocoding endpoint, request format, response structure, rate limits
2. **Wikipedia REST API**: Content retrieval endpoint, page summary format, error handling
3. **Provider Pattern**: Best practices for managing search state and navigation
4. **Debouncing**: Flutter implementation for TextField with Timer or package
5. **Error Handling**: User-friendly error messages for network failures

### Research Artifacts Created

The following files will be created during Phase 0:

- `research.md` - Consolidated findings from API documentation and Flutter patterns
- Research logs in CSV format (if using research agent pattern)

---

## Phase 1: Design & Contracts

### Data Model

**Entities to be defined in `data-model.md`:**

1. **Location**
   - Attributes: id, name, country, displayName, latitude, longitude, osmId
   - Relationships: None (standalone entity)
   - State: Immutable once selected

2. **LocationSuggestion**
   - Attributes: name, country, displayName, latitude, longitude, osmId
   - Lifecycle: Temporary (exists only during search)
   - Converts to Location on selection

3. **WikipediaContent**
   - Attributes: title, summary, extract, thumbnailUrl, pageUrl
   - Relationships: Associated with Location (not stored, fetched on-demand)
   - State: Loaded, Loading, Error

### API Contracts

**Contracts to be defined in `/contracts/`:**

1. **`nominatim-api.md`**
   - Endpoint: `https://nominatim.openstreetmap.org/search`
   - Parameters: q (query), format=json, limit, addressdetails
   - Response schema: JSON array of place objects
   - Error cases: Empty results, rate limit exceeded

2. **`wikipedia-api.md`**
   - Endpoint: `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
   - Parameters: title (URL-encoded location name)
   - Response schema: JSON object with extract, thumbnail, content_urls
   - Error cases: Page not found, API unavailable

### Developer Quickstart

**`quickstart.md` will contain:**
- Prerequisites: Flutter SDK installation, IDE setup
- Clone and setup commands
- Running the app: `flutter run`
- Project structure overview
- Key files to modify for enhancements

---

## Next Steps

After this planning phase:

1. Run `/spec-kitty.research` to populate `research.md` with API documentation and patterns
2. Create `data-model.md` with detailed entity specifications
3. Document API contracts in `/contracts/`
4. Write `quickstart.md` for developer onboarding
5. Update agent context files with Flutter/Provider/APIs knowledge
6. Run `/spec-kitty.tasks` to break down into work packages
7. Run `/spec-kitty.implement` to begin development

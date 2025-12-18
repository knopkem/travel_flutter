# Implementation Plan: City POI Discovery & Detail View

**Branch**: `002-city-poi-discovery` | **Date**: 2025-12-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/002-city-poi-discovery/spec.md`

## Summary

This feature refactors the existing location search app from a multi-city selection model to a single active city experience with comprehensive POI (Point of Interest) discovery. When a user selects a city, the system progressively fetches nearby attractions from three free data sources (Wikipedia Geosearch, OpenStreetMap/Overpass, Wikidata), deduplicates results using coordinate proximity and name matching, and presents a unified list. Users can view full Wikipedia article content for cities and detailed information for each POI.

**Technical Approach**: Extend existing Flutter/Dart architecture with Provider state management. Refactor LocationProvider for single-city model. Add three new repository classes for POI data sources. Implement POIProvider with progressive fetching strategy (Wikipedia first, then parallel Overpass/Wikidata). Use in-memory caching only. Enhance WikipediaProvider to fetch full article content instead of summaries.

## Technical Context

**Language/Version**: Dart 3.x with Flutter 3.x SDK
**Primary Dependencies**: 
- provider ^6.1.0 (state management, already in use)
- http ^1.1.0 (HTTP client, already in use)
- flutter_lints (code quality, already in use)

**Storage**: In-memory only - No persistent storage (shared_preferences, SQLite, etc.)
**Testing**: flutter test with flutter_test package, mockito for mocking HTTP clients
**Target Platform**: Mobile (iOS/Android) via Flutter
**Project Type**: Mobile app with multiple screens and state management
**Performance Goals**: 
- First POIs visible within 2 seconds (Wikipedia Geosearch)
- Complete POI list within 5 seconds (all sources)
- City Wikipedia content loads within 3 seconds
- Smooth UI transitions with no freezes

**Constraints**:
- Respect API rate limits: 1 req/sec for Nominatim, 1 req/sec for Overpass, standard for Wikipedia/Wikidata
- 10-second timeout per API request
- POI search radius: 10km from city center
- Deduplication threshold: 50 meters coordinate proximity
- Display top 20-30 POIs initially (sorted by notability)

**Scale/Scope**: 
- Single user per device (no multi-user)
- Expected usage: 10-50 city searches per session
- POI count: 20-100 per city typically
- 4 new screens/widgets, 3 new repositories, 1 new provider, 2 enhanced existing providers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Constitution Status**: The constitution file is a template placeholder with no specific project constraints defined.

**Compliance Assessment**: ✅ PASS (No constitutional requirements to validate)

Since the constitution contains only template placeholders ([PROJECT_NAME], [PRINCIPLE_1_NAME], etc.) and no concrete principles, there are no constitutional constraints to check against this feature implementation.

**Action**: Proceed with planning phases. If project-specific principles are defined in the future, revisit this check.

## Project Structure

### Documentation (this feature)

```
kitty-specs/002-city-poi-discovery/
├── plan.md              # This file (implementation strategy)
├── research.md          # Phase 0: API research and deduplication strategies
├── data-model.md        # Phase 1: Entity definitions and relationships
├── quickstart.md        # Phase 1: Developer onboarding guide
├── contracts/           # Phase 1: API contract specifications
│   ├── overpass-api.md
│   ├── wikipedia-geosearch-api.md
│   └── wikidata-api.md
├── checklists/          # Quality validation checklists
│   └── requirements.md
├── spec.md              # Feature specification
└── tasks/               # Task management (Phase 2, created by /spec-kitty.tasks)
    ├── planned/
    ├── doing/
    ├── for_review/
    └── done/
```

### Source Code (repository root)

```
lib/
├── main.dart                              # App entry point (modify for single-city)
├── models/
│   ├── location.dart                      # MODIFY: Remove from multi-select context
│   ├── location_suggestion.dart           # KEEP: Still used for search
│   ├── wikipedia_content.dart             # ENHANCE: Add full content support
│   ├── poi.dart                           # NEW: Point of Interest model
│   └── models.dart                        # UPDATE: Export new models
├── repositories/
│   ├── geocoding_repository.dart          # KEEP: Interface unchanged
│   ├── nominatim_geocoding_repository.dart # KEEP: No changes needed
│   ├── wikipedia_repository.dart          # ENHANCE: Add full content fetching
│   ├── rest_wikipedia_repository.dart     # ENHANCE: Implement full content
│   ├── overpass_repository.dart           # NEW: OpenStreetMap POI data
│   ├── wikipedia_geosearch_repository.dart # NEW: Wikipedia POI data
│   ├── wikidata_repository.dart           # NEW: Wikidata POI data
│   └── repositories.dart                  # UPDATE: Export new repositories
├── providers/
│   ├── location_provider.dart             # REFACTOR: Single city model
│   ├── wikipedia_provider.dart            # ENHANCE: Full content caching
│   ├── poi_provider.dart                  # NEW: POI discovery & deduplication
│   └── providers.dart                     # UPDATE: Export POIProvider
├── screens/
│   ├── home_screen.dart                   # REFACTOR: Single city UI
│   ├── location_detail_screen.dart        # ENHANCE: Full Wikipedia content
│   ├── poi_list_screen.dart               # NEW: Display POI list
│   └── poi_detail_screen.dart             # NEW: Individual POI details
└── widgets/
    ├── search_field.dart                  # KEEP: Minor updates
    ├── suggestion_list.dart               # KEEP: Updates for single-select
    ├── selected_locations_list.dart       # REMOVE: No multi-select
    ├── wikipedia_content_widget.dart      # ENHANCE: Full content display
    ├── poi_list_item.dart                 # NEW: POI list tile
    └── poi_loading_indicator.dart         # NEW: Progressive loading UI

test/
├── models/
│   └── poi_test.dart                      # NEW: POI model tests
├── repositories/
│   ├── nominatim_geocoding_repository_test.dart  # KEEP: Existing
│   ├── nominatim_integration_test.dart           # KEEP: Existing
│   ├── overpass_repository_test.dart             # NEW
│   ├── wikipedia_geosearch_repository_test.dart  # NEW
│   └── wikidata_repository_test.dart             # NEW
└── providers/
    ├── location_provider_test.dart        # UPDATE: Single city tests
    ├── wikipedia_provider_test.dart       # UPDATE: Full content tests
    └── poi_provider_test.dart             # NEW: POI discovery tests
```

**Structure Decision**: Extending existing Flutter mobile app structure. The app already has a well-defined architecture with models, repositories, providers, and UI layers. We're adding new components (POI system) while refactoring existing ones (single city model). The repository pattern allows clean separation of API concerns, and Provider state management handles progressive loading naturally.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Parallel Work Analysis

*Include this section if multiple developers/agents will implement this feature*

### Dependency Graph

```
[Identify what must be built sequentially vs what can be done in parallel]
Example:
Foundation (Day 1) → Wave 1 (Days 2-3, parallel) → Wave 2 (Days 4-5, parallel) → Integration (Day 6)
```

### Work Distribution

- **Sequential work**: [What must be done first before parallel work can begin]
- **Parallel streams**: [Independent work that can be done simultaneously]
- **Agent assignments**: [Who owns which files/modules to avoid conflicts]

### Coordination Points

- **Sync schedule**: [When parallel workers merge their changes]
- **Integration tests**: [How to verify parallel work integrates correctly]

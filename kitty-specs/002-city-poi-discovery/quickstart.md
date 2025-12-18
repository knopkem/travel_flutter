# Developer Quickstart Guide

**Feature**: City POI Discovery & Detail View  
**Branch**: `002-city-poi-discovery`  
**Last Updated**: 2024

## Overview

This feature enhances the travel app with single-city selection, full Wikipedia content display, and comprehensive POI (Point of Interest) discovery from multiple sources (OpenStreetMap, Wikipedia Geosearch, Wikidata). It includes intelligent deduplication and progressive loading for optimal UX.

## Prerequisites

### Required Software
- **Flutter SDK**: 3.0+ ([Install Guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: 3.0+ (included with Flutter)
- **Git**: 2.x+ for version control
- **IDE**: VS Code with Flutter/Dart extensions (recommended) or Android Studio

### Verify Installation
```bash
flutter doctor -v
dart --version
git --version
```

All checks should pass. Fix any issues reported by `flutter doctor`.

## Project Setup

### 1. Clone and Navigate to Feature Branch

```bash
# If starting fresh
git clone <repository-url>
cd travel_flutter
git fetch --all
git worktree add .worktrees/002-city-poi-discovery 002-city-poi-discovery
cd .worktrees/002-city-poi-discovery

# If worktree already exists
cd .worktrees/002-city-poi-discovery
git pull origin 002-city-poi-discovery
```

### 2. Install Dependencies

```bash
flutter pub get
```

**Key Dependencies** (already in `pubspec.yaml`):
- `provider: ^6.1.0` - State management
- `http: ^1.1.0` - HTTP client for API calls
- `flutter_lints: ^2.0.0` - Code quality

No new external dependencies required for this feature.

### 3. Verify Setup

```bash
flutter analyze
flutter test
```

Both should complete without errors.

## Running the App

### Development Mode

```bash
# Run on connected device/emulator
flutter run

# Run with hot reload enabled (default)
flutter run -d <device_id>

# List available devices
flutter devices
```

### Testing POI Discovery

1. Launch the app
2. Search for a city (e.g., "Paris", "New York", "Tokyo")
3. Select a city from results
4. **City Details Screen**: Full Wikipedia article content loads (~2 seconds)
5. **POI Discovery**: POI list appears progressively (~5 seconds total)
   - Phase 1: Wikipedia Geosearch results (~2s)
   - Phase 2: OpenStreetMap + Wikidata results (~3s additional)
6. Tap any POI to view detailed information

### Key Screens
- `HomeScreen` - City search input
- `CitySearchScreen` - Search results (single selection)
- `CityDetailsScreen` - Full Wikipedia article + POI list
- `POIDetailScreen` - Individual POI information

## Architecture Overview

### Data Flow

```
User Input → LocationProvider (City Selection)
              ↓
         WikipediaProvider (Full Article Fetch)
              ↓
         POIProvider (Discovery & Deduplication)
              ↓ (parallel)
    ┌─────────┴──────────┐
    ↓                    ↓
Wikipedia Geosearch   Overpass + Wikidata
 (2 seconds)          (3 seconds)
    └─────────┬──────────┘
              ↓
      Deduplication (50m + 70% name similarity)
              ↓
         UI Update (Progressive)
```

### Project Structure

```
lib/
├── models/
│   ├── city.dart              # City entity (MODIFIED - single selection)
│   ├── poi.dart               # NEW - POI entity with sources
│   ├── poi_type.dart          # NEW - POI type enum
│   ├── poi_source.dart        # NEW - POI source enum
│   ├── wikipedia_content.dart # MODIFIED - full article support
│   └── article_section.dart   # NEW - article section model
│
├── providers/
│   ├── location_provider.dart # MODIFIED - single city model
│   ├── poi_provider.dart      # NEW - POI discovery orchestration
│   └── wikipedia_provider.dart # MODIFIED - full content fetching
│
├── repositories/
│   ├── poi_repository.dart           # NEW - base interface
│   ├── wikipedia_geosearch_repo.dart # NEW - Wikipedia Geosearch
│   ├── overpass_repository.dart      # NEW - OpenStreetMap
│   └── wikidata_repository.dart      # NEW - Wikidata SPARQL
│
├── screens/
│   ├── city_details_screen.dart      # MODIFIED - full content + POI list
│   └── poi_detail_screen.dart        # NEW - POI detail view
│
├── widgets/
│   ├── poi_list_item.dart            # NEW - POI list item
│   ├── poi_filter_chip.dart          # NEW - type filter chips
│   ├── article_section_widget.dart   # NEW - article section renderer
│   └── loading_indicator.dart        # MODIFIED - progressive loading
│
└── utils/
    ├── deduplication_utils.dart # NEW - POI deduplication logic
    ├── distance_calculator.dart # NEW - Haversine distance
    └── notability_scorer.dart   # NEW - POI notability scoring
```

## Common Development Tasks

### Add a New POI Source

1. Create repository in `lib/repositories/`:
```dart
class NewPOIRepository extends POIRepository {
  @override
  Future<List<POI>> fetchNearbyPOIs(City city) async {
    // Implement API call
  }
}
```

2. Register in `POIProvider`:
```dart
final _repositories = [
  WikipediaGeosearchRepository(),
  OverpassRepository(),
  WikidataRepository(),
  NewPOIRepository(), // Add here
];
```

3. Add source to enum in `lib/models/poi_source.dart`:
```dart
enum POISource {
  wikipediaGeosearch,
  overpass,
  wikidata,
  newSource, // Add here
}
```

### Adjust Deduplication Thresholds

Edit `lib/utils/deduplication_utils.dart`:
```dart
const double _proximityThresholdMeters = 50.0; // Change here
const double _nameSimilarityThreshold = 0.7;   // Change here
```

### Modify POI Type Categories

Edit `lib/models/poi_type.dart`:
```dart
enum POIType {
  museum,
  monument,
  landmark,
  park,
  // Add new types here
}
```

Then update mapping logic in repositories.

### Change Progressive Loading Timing

Edit `lib/providers/poi_provider.dart`:
```dart
Future<void> discoverPOIs(City city) async {
  // Phase 1: Fast sources
  await _fetchFromSource(wikipediaGeosearchRepo);
  notifyListeners(); // UI updates after ~2s
  
  // Phase 2: Slower sources (parallel)
  await Future.wait([
    _fetchFromSource(overpassRepo),
    _fetchFromSource(wikidataRepo),
  ]);
  notifyListeners(); // UI updates after ~5s total
}
```

## Running Tests

### Unit Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/utils/deduplication_utils_test.dart

# With coverage
flutter test --coverage
```

### Widget Tests
```bash
flutter test test/widgets/
```

### Integration Tests (if available)
```bash
flutter test integration_test/
```

## API Rate Limits & Caching

### Rate Limits
- **OpenStreetMap Overpass**: 1 request/second (enforced in code)
- **Wikipedia Geosearch**: No strict limit (reasonable use)
- **Wikidata SPARQL**: 60-second query timeout

### Caching Strategy
- **In-Memory Only**: No persistence across app restarts
- **Cache Duration**: Session-based (cleared on app close)
- **Cache Key**: `{cityId}-{source}` combination
- **Max Size**: ~10MB total (LRU eviction)

## Troubleshooting

### POIs Not Loading
1. Check internet connection
2. Verify API availability: https://overpass-api.de/api/status
3. Check logs for rate limit errors: `flutter logs`
4. Reduce search radius if timeout occurs

### Duplicate POIs Appearing
1. Verify deduplication thresholds in `deduplication_utils.dart`
2. Check coordinate precision in API responses
3. Review name normalization logic

### App Crashes on City Selection
1. Ensure Wikipedia content parsing handles missing fields
2. Check for null safety violations in models
3. Verify provider initialization in `main.dart`

### Slow Performance
1. Reduce Overpass query complexity (fewer tags)
2. Lower SPARQL result limit (currently 100)
3. Implement distance-based sorting to prioritize closer POIs
4. Consider reducing search radius from 10km

## Debugging Tips

### Enable Verbose Logging
```dart
// In poi_provider.dart
void _log(String message) {
  if (kDebugMode) {
    print('[POIProvider] $message');
  }
}
```

### Inspect API Responses
Use a proxy like Charles or Proxyman to view HTTP traffic:
1. Configure device proxy settings
2. Install SSL certificate
3. Monitor requests to:
   - `overpass-api.de`
   - `en.wikipedia.org/w/api.php`
   - `query.wikidata.org/sparql`

### Test with Mock Data
```dart
// In test setup
final mockPOIs = [
  POI(
    id: 'test-1',
    name: 'Test Museum',
    type: POIType.museum,
    latitude: 40.7128,
    longitude: -74.0060,
    sources: [POISource.wikipediaGeosearch],
  ),
];
when(mockRepository.fetchNearbyPOIs(any))
    .thenAnswer((_) async => mockPOIs);
```

## Next Steps

After setup:
1. **Read**: [Implementation Plan](plan.md) for detailed design
2. **Review**: [API Contracts](contracts/) for endpoint specifications
3. **Explore**: [Data Model](data-model.md) for entity relationships
4. **Execute**: Follow task breakdown from `/spec-kitty.tasks` command

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider State Management](https://pub.dev/packages/provider)
- [OpenStreetMap Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API)
- [Wikipedia API Documentation](https://www.mediawiki.org/wiki/API:Main_page)
- [Wikidata SPARQL Guide](https://www.wikidata.org/wiki/Wikidata:SPARQL_tutorial)

## Contributing

1. Create feature branch from `002-city-poi-discovery`
2. Make changes with descriptive commits
3. Run `flutter analyze` and `flutter test` before pushing
4. Submit pull request with clear description
5. Ensure CI passes all checks

## Support

For questions or issues:
- Check existing documentation in `kitty-specs/002-city-poi-discovery/`
- Review specification in `spec.md`
- Consult implementation plan in `plan.md`
- Reach out to project maintainer

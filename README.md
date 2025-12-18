# Travel Flutter App - Location Search & Wikipedia Browser

A Flutter mobile application that enables users to search for geographic locations using OpenStreetMap's Nominatim service and view relevant Wikipedia content for selected locations.

## Features

### 🔍 Location Search
- Real-time location search powered by OpenStreetMap Nominatim API
- Display of location suggestions with formatted addresses
- Visual feedback for duplicate locations when attempting to add the same place twice

### 📍 Multiple Location Management
- Add and manage multiple selected locations
- Persistent storage of selected locations
- Remove locations from your list
- View detailed information for each saved location

### 📖 Wikipedia Integration
- Automatic fetching of Wikipedia article summaries for selected locations
- Display of article extracts with descriptions
- Caching mechanism to reduce redundant API calls
- Graceful handling of locations without Wikipedia articles

### ⚡ Performance & Reliability
- Rate limit handling (1 request per second for Nominatim)
- Comprehensive error handling with user-friendly messages
- Debug logging for troubleshooting
- Network timeout management (10-second timeouts)

## Getting Started

### Prerequisites
- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- iOS Simulator / Android Emulator or physical device

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd travel_flutter/.worktrees/001-location-search-wikipedia
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Dependencies
This project uses the following key dependencies:
- `provider ^6.1.0` - State management
- `http ^1.1.0` - HTTP client for API calls
- `flutter_lints` - Code quality and linting

## Architecture

The app follows a layered architecture pattern:

### Models Layer (`lib/models/`)
- **Location**: Represents a geographic location with coordinates and address details
- **LocationSuggestion**: Search result model with place ID and display name
- **WikipediaContent**: Wikipedia article content with extract and URL

### Repository Layer (`lib/repositories/`)
- **NominatimGeocodingRepository**: Handles geocoding via OpenStreetMap Nominatim API
  - Rate limiting (1 req/sec)
  - Location search and coordinate lookup
- **RestWikipediaRepository**: Fetches Wikipedia content via Wikipedia REST API v1
  - Article summary retrieval
  - 404 handling for missing articles

### Provider Layer (`lib/providers/`)
- **LocationProvider**: Manages location search and selection state
  - Search functionality
  - Selected locations list
  - Duplicate detection
- **WikipediaProvider**: Manages Wikipedia content caching
  - Content fetching and caching
  - Loading state management

### UI Layer (`lib/screens/` and `lib/widgets/`)
- **HomeScreen**: Main screen with search and selected locations
- **LocationDetailScreen**: Detailed view for a specific location with Wikipedia content
- **SearchField**: Location search input widget
- **SuggestionList**: Search results display
- **SelectedLocationsList**: List of saved locations
- **WikipediaContentWidget**: Wikipedia article display

## API Dependencies

### OpenStreetMap Nominatim API
- **Purpose**: Geocoding and location search
- **Endpoint**: `https://nominatim.openstreetmap.org`
- **Rate Limit**: 1 request per second
- **Documentation**: https://nominatim.org/release-docs/latest/api/Search/

### Wikipedia REST API v1
- **Purpose**: Article summary retrieval
- **Endpoint**: `https://en.wikipedia.org/api/rest_v1`
- **Rate Limit**: None specified
- **Documentation**: https://en.wikipedia.org/api/rest_v1/

## Development

### Code Quality
Run linter and formatter:
```bash
flutter analyze
dart format lib/
```

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── location.dart
│   ├── location_suggestion.dart
│   └── wikipedia_content.dart
├── repositories/             # API integrations
│   ├── nominatim_geocoding_repository.dart
│   └── rest_wikipedia_repository.dart
├── providers/                # State management
│   ├── location_provider.dart
│   └── wikipedia_provider.dart
├── screens/                  # Full-screen views
│   ├── home_screen.dart
│   └── location_detail_screen.dart
└── widgets/                  # Reusable components
    ├── search_field.dart
    ├── suggestion_list.dart
    ├── selected_locations_list.dart
    └── wikipedia_content_widget.dart
```

## Error Handling

The app includes comprehensive error handling for:
- Network connectivity issues
- API timeouts (10-second limit)
- Rate limiting (HTTP 429 responses)
- Missing Wikipedia articles (HTTP 404)
- Invalid API responses
- Malformed JSON

All errors display user-friendly messages in the UI while logging detailed information via `debugPrint()` for development troubleshooting.

## License

This project is part of a larger travel app development effort.

## Contributing

This is a feature branch implementation. For contribution guidelines, refer to the main repository documentation.


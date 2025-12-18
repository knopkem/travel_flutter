# Developer Quickstart: Location Search & Wikipedia Browser
*Path: kitty-specs/001-location-search-wikipedia/quickstart.md*

**Feature**: Location Search & Wikipedia Browser
**Date**: 2025-12-12
**Target Audience**: Developers setting up and working on this feature

---

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software
- **Flutter SDK**: Version 3.x or later ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: Version 3.x or later (included with Flutter)
- **IDE**: VS Code or Android Studio with Flutter/Dart plugins
- **Git**: For version control

### Verify Installation
```bash
flutter --version
dart --version
git --version
```

Expected output should show Flutter 3.x and Dart 3.x.

---

## Project Setup

### 1. Clone Repository and Navigate to Feature Branch

```bash
# Navigate to feature worktree (if not already there)
cd .worktrees/001-location-search-wikipedia

# Verify you're on the correct branch
git branch --show-current
# Should output: 001-location-search-wikipedia
```

### 2. Install Dependencies

```bash
# Install Flutter packages
flutter pub get

# Verify installation
flutter pub deps
```

**Key Dependencies**:
- `provider`: State management
- `http`: HTTP client for API calls
- `flutter_lints`: Linting rules

### 3. Verify Flutter Setup

```bash
# Check for issues with Flutter installation
flutter doctor

# Run analyzer to check for errors
flutter analyze
```

Fix any issues reported by `flutter doctor` (Android SDK, iOS tooling, etc.).

---

## Running the App

### Development Mode

**On Physical Device or Emulator**:
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run with hot reload (default)
flutter run
```

**Quick Commands**:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit
- Press `o` to toggle platform (iOS/Android)

### Debug vs Release Mode

**Debug Mode** (default):
```bash
flutter run
```
- Includes debugging information
- Slower performance
- Enables hot reload

**Release Mode**:
```bash
flutter run --release
```
- Optimized performance
- No debugging tools
- Use for testing real-world performance

---

## Project Structure Overview

```
lib/
├── main.dart                          # App entry point
│
├── screens/                           # Full-screen views
│   ├── home_screen.dart              # Main search + location list
│   └── location_detail_screen.dart   # Wikipedia content display
│
├── widgets/                           # Reusable UI components
│   ├── search_field.dart             # Debounced text input
│   ├── suggestion_list.dart          # Autocomplete dropdown
│   └── location_button.dart          # Selected location button
│
├── providers/                         # State management (Provider pattern)
│   ├── location_provider.dart        # Manages selected locations
│   └── wikipedia_provider.dart       # Manages Wikipedia content
│
├── repositories/                      # Data layer (API clients)
│   ├── geocoding_repository.dart     # Nominatim API client
│   └── wikipedia_repository.dart     # Wikipedia API client
│
└── models/                            # Data classes
    ├── location.dart                 # Location entity
    ├── location_suggestion.dart      # Search suggestion entity
    └── wikipedia_content.dart        # Wikipedia content entity
```

### File Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/Functions: `camelCase`
- Constants: `lowerCamelCase` or `SCREAMING_SNAKE_CASE`

---

## Development Workflow

### 1. Create a New Feature/Fix

```bash
# Make sure you're on the feature branch
git branch --show-current

# Create your changes in appropriate files
# Follow the structure: models → repositories → providers → widgets → screens
```

### 2. Code Formatting

```bash
# Format all Dart files
dart format .

# Format specific file
dart format lib/main.dart
```

### 3. Static Analysis

```bash
# Run linter and analyzer
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

### 4. Testing Changes

```bash
# Run the app
flutter run

# Test on multiple devices if possible
flutter run -d android
flutter run -d ios
```

---

## Key Files to Modify

### Adding a New Widget
1. Create file in `lib/widgets/`
2. Follow Flutter widget naming: `SomethingWidget`
3. Export public widgets from files
4. Import in screens where needed

### Modifying State Management
1. Providers in `lib/providers/`
2. Extend `ChangeNotifier`
3. Call `notifyListeners()` after state changes
4. Inject repositories via constructor

### Adding API Calls
1. Repositories in `lib/repositories/`
2. Each repository handles one external service
3. Return typed data (models)
4. Throw meaningful exceptions

### Creating New Screens
1. Files in `lib/screens/`
2. Use `Scaffold` as base
3. Navigate with `Navigator.push()` / `Navigator.pop()`
4. Access providers with `context.watch()` or `context.read()`

---

## Common Commands

### Package Management
```bash
# Add new package
flutter pub add package_name

# Remove package
flutter pub remove package_name

# Update packages
flutter pub upgrade
```

### Build Commands
```bash
# Build APK (Android)
flutter build apk

# Build app bundle (Android - for Play Store)
flutter build appbundle

# Build iOS (requires Mac)
flutter build ios
```

### Cleaning Build
```bash
# Clean build artifacts
flutter clean

# Reinstall dependencies
flutter pub get
```

---

## Debugging Tips

### Common Issues

**Hot Reload Not Working**:
- Try hot restart (`R` in terminal)
- Check for syntax errors
- Restart app completely if needed

**Import Errors**:
- Run `flutter pub get`
- Check `pubspec.yaml` for correct package names
- Verify file paths are correct

**API Not Responding**:
- Check internet connection
- Verify API endpoints in repositories
- Check User-Agent header for Nominatim
- Look at console logs for error messages

### Debug Console
```dart
// Print debug messages
print('Debug message: $variableName');
debugPrint('Debug only message');

// Log from providers
print('LocationProvider: Added location ${location.name}');
```

### Flutter DevTools
```bash
# Launch DevTools (in browser)
flutter pub global activate devtools
flutter pub global run devtools
```

Access at: http://localhost:9100

---

## API Integration Notes

### Nominatim API
- **Base URL**: `https://nominatim.openstreetmap.org`
- **Rate Limit**: 1 request/second
- **Required Header**: User-Agent: "TravelFlutterApp/1.0"
- **Implementation**: See `lib/repositories/geocoding_repository.dart`

### Wikipedia API
- **Base URL**: `https://en.wikipedia.org/api/rest_v1`
- **Rate Limit**: 200 requests/second (no concerns)
- **No Auth Required**
- **Implementation**: See `lib/repositories/wikipedia_repository.dart`

**Testing APIs Manually**:
```bash
# Test Nominatim
curl "https://nominatim.openstreetmap.org/search?q=Paris&format=json&limit=5" \
  -H "User-Agent: TravelFlutterApp/1.0"

# Test Wikipedia
curl "https://en.wikipedia.org/api/rest_v1/page/summary/Paris"
```

---

## Code Quality Guidelines

### Following Constitution
- Use latest stable packages from pub.dev
- Modular architecture (separation of concerns)
- No tests required (testing on-demand only)
- Document all public APIs with `///` comments
- Follow flutter_lints rules

### Documentation Standards
```dart
/// Fetches location suggestions from Nominatim API.
///
/// [query] The search text entered by user.
/// Returns a list of [LocationSuggestion] objects.
/// Throws [Exception] if network request fails.
Future<List<LocationSuggestion>> search(String query) async {
  // Implementation
}
```

### Error Handling
```dart
try {
  final suggestions = await repository.search(query);
  return suggestions;
} on SocketException {
  throw Exception('No internet connection');
} catch (e) {
  throw Exception('Search failed: $e');
}
```

---

## Next Steps After Setup

1. **Explore the codebase**: Read through existing files in order: models → repositories → providers → screens
2. **Review API contracts**: Check `contracts/nominatim-api.md` and `contracts/wikipedia-api.md`
3. **Run the app**: Use `flutter run` to see current implementation
4. **Check tasks**: Review `tasks.md` (when created) for implementation work packages
5. **Start implementing**: Follow work packages in priority order

---

## Getting Help

### Documentation
- **Flutter Docs**: https://docs.flutter.dev/
- **Provider Package**: https://pub.dev/packages/provider
- **Nominatim API**: https://nominatim.org/release-docs/latest/api/
- **Wikipedia API**: https://en.wikipedia.org/api/rest_v1/

### Command Reference
```bash
# Most useful commands
flutter pub get          # Install dependencies
flutter run              # Run app
flutter analyze          # Check for errors
dart format .            # Format code
flutter clean            # Clean build
```

---

## Ready to Code! 🚀

Your development environment is now set up. Follow the work packages in `tasks.md` (created by `/spec-kitty.tasks`) to implement this feature step by step.

**Questions or Issues?**
- Review the [plan.md](plan.md) for technical context
- Check [data-model.md](data-model.md) for entity specifications
- Read API contracts in [contracts/](contracts/)

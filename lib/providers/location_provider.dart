import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Manages location search state and single active city selection.
///
/// This provider handles:
/// - Search query execution against geocoding API
/// - Location suggestions for autocomplete dropdown
/// - Single active city selection (replaces previous selection)
/// - Loading and error states
///
/// The provider uses [GeocodingRepository] to fetch location data and
/// maintains separation between search suggestions (temporary) and
/// the selected city (persistent).
///
/// Usage in widgets:
/// ```dart
/// // Listen to changes with Consumer
/// Consumer<LocationProvider>(
///   builder: (context, provider, child) {
///     if (provider.isLoading) {
///       return CircularProgressIndicator();
///     }
///     return ListView(
///       children: provider.suggestions.map((s) =>
///         ListTile(
///           title: Text(s.displayName),
///           onTap: () => provider.selectLocation(s),
///         )
///       ).toList(),
///     );
///   },
/// )
///
/// // Call methods without listening
/// Provider.of<LocationProvider>(context, listen: false)
///   .searchLocations('Berlin');
/// ```
class LocationProvider extends ChangeNotifier {
  /// Primary repository for geocoding API calls (Google Places when available)
  GeocodingRepository _primaryRepository;

  /// Fallback repository for geocoding (Nominatim when Google Places unavailable)
  final GeocodingRepository _fallbackRepository;

  /// Current Google Places API key (nullable)
  String? _googlePlacesApiKey;

  /// Current search suggestions (temporary, cleared on new search)
  List<LocationSuggestion> _suggestions = [];

  /// Currently selected city (persistent during session)
  /// Only one city can be active at a time; selecting a new city replaces the previous one
  Location? _selectedCity;

  /// Loading state for async operations
  bool _isLoading = false;

  /// Error message from last failed operation
  String? _errorMessage;

  /// Error message from GPS operations (shown in GPS button state)
  String? _gpsError;

  /// Creates a [LocationProvider] with primary and fallback repositories.
  ///
  /// [primaryRepository] is typically Google Places Autocomplete (when API key available)
  /// [fallbackRepository] is typically Nominatim (free, no API key needed)
  LocationProvider(this._primaryRepository, this._fallbackRepository);

  // Getters

  /// Current list of search suggestions.
  ///
  /// These are temporary results from the most recent search query.
  /// Cleared when a new search starts or when [clearSuggestions] is called.
  List<LocationSuggestion> get suggestions => _suggestions;

  /// Currently selected city.
  ///
  /// Persists during the app session. Returns null if no city is selected.
  /// A new city selection replaces the previous one.
  Location? get selectedCity => _selectedCity;

  /// Updates the Google Places API key for location search
  void updateGooglePlacesApiKey(String? apiKey,
      {void Function()? onRequestMade}) {
    _googlePlacesApiKey = apiKey;
    // Update the primary repository with the new API key if it's a Google Places repository
    if (_primaryRepository is GooglePlacesAutocompleteRepository &&
        apiKey != null &&
        apiKey.isNotEmpty) {
      _primaryRepository =
          (_primaryRepository as GooglePlacesAutocompleteRepository)
              .withApiKey(apiKey);
    }
  }

  /// Whether a city is currently selected.
  bool get hasSelectedCity => _selectedCity != null;

  /// Whether an async operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Error message from the last failed operation, or null if no error.
  String? get errorMessage => _errorMessage;

  /// GPS error message for display in GPS button, or null if no error.
  String? get gpsError => _gpsError;

  // Methods

  /// Searches for locations matching the query.
  ///
  /// Uses Google Places Autocomplete if API key is available, otherwise falls
  /// back to Nominatim (free service). Automatically handles fallback if
  /// primary repository fails.
  ///
  /// Clears previous suggestions and error state before searching.
  /// Updates [isLoading], [suggestions], and [errorMessage] accordingly.
  /// Notifies listeners when state changes.
  ///
  /// If [query] is empty, clears suggestions without making an API call.
  ///
  /// Example:
  /// ```dart
  /// await provider.searchLocations('Paris');
  /// // suggestions now contains Paris, France and other matches
  /// ```
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
      // Try primary repository (Google Places) if API key is available
      if (_googlePlacesApiKey != null && _googlePlacesApiKey!.isNotEmpty) {
        try {
          _suggestions = await _primaryRepository.searchLocations(query);
          _errorMessage = null;
        } catch (e) {
          debugPrint(
              'LocationProvider: Primary repository failed, trying fallback: $e');
          // Fall back to Nominatim on error
          _suggestions = await _fallbackRepository.searchLocations(query);
          _errorMessage = null;
        }
      } else {
        // Use fallback repository (Nominatim) when no API key
        _suggestions = await _fallbackRepository.searchLocations(query);
        _errorMessage = null;
      }
    } catch (e) {
      debugPrint(
          'LocationProvider: All repositories failed for query "$query": $e');
      _suggestions = [];
      _errorMessage = 'Failed to search locations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a city, replacing any previously selected city.
  ///
  /// Converts the [LocationSuggestion] to a [Location] and sets it as
  /// the active city. Any previously selected city is replaced.
  ///
  /// If [onCityChanged] callback is provided, it will be called when
  /// the city changes. This is useful for clearing related data (e.g., POIs).
  ///
  /// This method does not make additional API calls; it uses the data
  /// already present in the suggestion (which includes coordinates).
  ///
  /// Example:
  /// ```dart
  /// final suggestion = suggestions.first;
  /// provider.selectCity(
  ///   suggestion,
  ///   onCityChanged: () => poiProvider.clear(),
  /// );
  /// // Previous city (if any) is now replaced
  /// ```
  void selectCity(
    LocationSuggestion suggestion, {
    VoidCallback? onCityChanged,
  }) {
    // Always clear related data to force refresh
    if (onCityChanged != null) {
      onCityChanged();
    }

    // Convert suggestion to Location using the built-in method
    _selectedCity = suggestion.toLocation();
    notifyListeners();
  }

  /// Clears the currently selected city.
  ///
  /// Sets the selected city to null and notifies listeners.
  ///
  /// Example:
  /// ```dart
  /// provider.clearCity();
  /// ```
  void clearCity() {
    _selectedCity = null;
    notifyListeners();
  }

  /// Clears all search suggestions.
  ///
  /// This is typically called when the user selects a location or
  /// when the search UI is dismissed. Does not affect [selectedLocations].
  ///
  /// Example:
  /// ```dart
  /// provider.clearSuggestions();
  /// ```
  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  /// Shows a permission explanation dialog before requesting location access.
  ///
  /// This dialog explains why the app needs location access and provides
  /// an "Allow" button that triggers the permission request. Returns true
  /// if the user accepted, false if they dismissed the dialog.
  Future<bool> showLocationPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('Enable Location'),
            ],
          ),
          content: const Text(
            'This app needs your location to discover nearby attractions automatically. '
            'Your location data is only used to find points of interest near you and is never stored or shared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Fetches the user's current GPS location and sets it as the selected city.
  ///
  /// This method:
  /// 1. Shows permission explanation dialog if permissions not yet requested
  /// 2. Checks if location services are enabled
  /// 3. Requests location permissions if needed
  /// 4. Gets current GPS position (30 second timeout)
  /// 5. Attempts reverse geocoding to get city name
  /// 6. Falls back to coordinate-only mode if reverse geocoding fails
  /// 7. Sets the location as selected city (triggers POI auto-fetch)
  ///
  /// GPS errors are stored in [gpsError] for display in the GPS button.
  ///
  /// Example:
  /// ```dart
  /// await provider.fetchCurrentLocation(context);
  /// if (provider.hasSelectedCity) {
  ///   print('Location set: ${provider.selectedCity!.displayName}');
  /// }
  /// ```
  Future<void> fetchCurrentLocation(BuildContext context) async {
    _isLoading = true;
    _gpsError = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
            'Location services are disabled. Please enable them in settings.');
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // Show explanation dialog if permission was never requested
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          final userAccepted = await showLocationPermissionDialog(context);
          if (!userAccepted) {
            throw Exception(
                'Location permission is required to use this feature.');
          }
        }

        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
              'Location permission denied. Tap the GPS button to try again.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Please enable it in app settings.',
        );
      }

      // Try to get last known position first (instant on iOS)
      Position? position = await Geolocator.getLastKnownPosition();

      // If no cached position, get current position with platform-specific settings
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          // Use medium accuracy for faster initial fix on iOS
          desiredAccuracy: LocationAccuracy.medium,
          // iOS can take longer for initial GPS fix, especially in cold start
          timeLimit: const Duration(seconds: 60),
        );
      }

      debugPrint('GPS position: ${position.latitude}, ${position.longitude}');

      // Attempt reverse geocoding to get location name
      // Always use Nominatim for reverse geocoding since:
      // 1. It's free and doesn't require API keys
      // 2. Google Geocoding API is separate from Places API and requires separate enablement
      // 3. Reverse geocoding is infrequent (only for GPS location detection)
      LocationSuggestion? suggestion;
      try {
        suggestion = await _fallbackRepository.reverseGeocode(
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        debugPrint('Reverse geocode failed: $e');
      }

      // Create location object
      Location location;
      if (suggestion != null) {
        // Use resolved location name
        location = suggestion.toLocation();
        debugPrint('Reverse geocoded to: ${location.displayName}');
      } else {
        // Fall back to coordinate-only mode
        location = Location.fromCoordinates(
          position.latitude,
          position.longitude,
        );
        debugPrint('Using coordinate-only location');
      }

      // Set as selected city (this will trigger POI fetch in UI)
      _selectedCity = location;
      _gpsError = null;
    } catch (e) {
      debugPrint('LocationProvider: GPS fetch failed: $e');

      // Store user-friendly error message for GPS button
      if (e.toString().contains('Location services are disabled')) {
        _gpsError = 'GPS is turned off';
      } else if (e.toString().contains('permission')) {
        _gpsError = 'Location permission denied';
      } else if (e.toString().contains('TimeoutException')) {
        _gpsError = 'GPS signal timeout';
      } else {
        _gpsError = 'Could not get location';
      }

      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the location from map center coordinates.
  ///
  /// This method:
  /// 1. Takes latitude/longitude from the map center
  /// 2. Attempts reverse geocoding to get location name
  /// 3. Falls back to coordinate-only mode if reverse geocoding fails
  /// 4. Sets the location as selected city (triggers POI auto-fetch)
  ///
  /// Example:
  /// ```dart
  /// await provider.setLocationFromMapCenter(48.8566, 2.3522);
  /// ```
  Future<void> setLocationFromMapCenter(
      double latitude, double longitude) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Attempt reverse geocoding to get location name
      // Always use Nominatim for reverse geocoding (free, no API key needed)
      LocationSuggestion? suggestion;
      try {
        suggestion = await _fallbackRepository.reverseGeocode(
          latitude,
          longitude,
        );
      } catch (e) {
        debugPrint('Reverse geocode failed: $e');
      }

      // Create location object
      Location location;
      if (suggestion != null) {
        // Use resolved location name
        location = suggestion.toLocation();
        debugPrint('Reverse geocoded map center to: ${location.displayName}');
      } else {
        // Fall back to coordinate-only mode
        location = Location.fromCoordinates(
          latitude,
          longitude,
        );
        debugPrint('Using coordinate-only location for map center');
      }

      // Set as selected city (this will trigger POI fetch in UI)
      _selectedCity = location;
    } catch (e) {
      debugPrint('LocationProvider: Set from map center failed: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Repository disposal is handled by its owner (typically main.dart)
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Manages location search state and selected locations list.
///
/// This provider handles:
/// - Search query execution against geocoding API
/// - Location suggestions for autocomplete dropdown
/// - Selected locations list (persistent during session)
/// - Loading and error states
/// - Duplicate prevention
///
/// The provider uses [GeocodingRepository] to fetch location data and
/// maintains separation between search suggestions (temporary) and
/// selected locations (persistent).
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
  /// Repository for geocoding API calls
  final GeocodingRepository _repository;

  /// Current search suggestions (temporary, cleared on new search)
  List<LocationSuggestion> _suggestions = [];

  /// Selected locations list (persistent during session)
  final List<Location> _selectedLocations = [];

  /// Loading state for async operations
  bool _isLoading = false;

  /// Error message from last failed operation
  String? _errorMessage;

  /// Creates a [LocationProvider] with the specified repository.
  ///
  /// The repository is typically injected via dependency injection
  /// (e.g., from MultiProvider setup in main.dart).
  LocationProvider(this._repository);

  // Getters

  /// Current list of search suggestions.
  ///
  /// These are temporary results from the most recent search query.
  /// Cleared when a new search starts or when [clearSuggestions] is called.
  List<LocationSuggestion> get suggestions => _suggestions;

  /// List of locations selected by the user.
  ///
  /// Persists during the app session. Locations are added via
  /// [selectLocation] and removed via [removeLocation].
  List<Location> get selectedLocations => _selectedLocations;

  /// Whether an async operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Error message from the last failed operation, or null if no error.
  String? get errorMessage => _errorMessage;

  // Methods

  /// Searches for locations matching the query.
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
      _suggestions = await _repository.searchLocations(query);
      _errorMessage = null;
    } catch (e) {
      _suggestions = [];
      _errorMessage = 'Failed to search locations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a selected location to the list.
  ///
  /// Converts the [LocationSuggestion] to a [Location] and adds it to
  /// [selectedLocations]. Prevents duplicates based on location ID.
  ///
  /// This method does not make additional API calls; it uses the data
  /// already present in the suggestion (which includes coordinates).
  ///
  /// Example:
  /// ```dart
  /// final suggestion = suggestions.first;
  /// provider.selectLocation(suggestion);
  /// // suggestion is now converted to Location and added to selectedLocations
  /// ```
  void selectLocation(LocationSuggestion suggestion) {
    // Convert suggestion to Location using the built-in method
    final location = suggestion.toLocation();

    // Prevent duplicates based on ID
    if (!_selectedLocations.any((loc) => loc.id == location.id)) {
      _selectedLocations.add(location);
      notifyListeners();
    }
  }

  /// Removes a location from the selected list.
  ///
  /// Removes the location with the specified [locationId] from
  /// [selectedLocations] and notifies listeners.
  ///
  /// Example:
  /// ```dart
  /// provider.removeLocation('123456');
  /// ```
  void removeLocation(String locationId) {
    _selectedLocations.removeWhere((loc) => loc.id == locationId);
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

  @override
  void dispose() {
    // Repository disposal is handled by its owner (typically main.dart)
    super.dispose();
  }
}

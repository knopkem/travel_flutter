import 'package:flutter/foundation.dart';
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
  /// Repository for geocoding API calls
  final GeocodingRepository _repository;

  /// Current search suggestions (temporary, cleared on new search)
  List<LocationSuggestion> _suggestions = [];

  /// Currently selected city (persistent during session)
  /// Only one city can be active at a time; selecting a new city replaces the previous one
  Location? _selectedCity;

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

  /// Currently selected city.
  ///
  /// Persists during the app session. Returns null if no city is selected.
  /// A new city selection replaces the previous one.
  Location? get selectedCity => _selectedCity;

  /// Whether a city is currently selected.
  bool get hasSelectedCity => _selectedCity != null;

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
      debugPrint('LocationProvider: Search failed for query "$query": $e');
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
  /// This method does not make additional API calls; it uses the data
  /// already present in the suggestion (which includes coordinates).
  ///
  /// Example:
  /// ```dart
  /// final suggestion = suggestions.first;
  /// provider.selectCity(suggestion);
  /// // Previous city (if any) is now replaced
  /// ```
  void selectCity(LocationSuggestion suggestion) {
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

  @override
  void dispose() {
    // Repository disposal is handled by its owner (typically main.dart)
    super.dispose();
  }
}

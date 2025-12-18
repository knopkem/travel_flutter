import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Manages Wikipedia content loading state and caching.
///
/// This provider handles:
/// - Fetching Wikipedia article summaries
/// - Caching content by title to avoid redundant API calls
/// - Loading and error states
/// - Content retrieval for display
///
/// The provider uses [WikipediaRepository] to fetch article data and
/// maintains an in-memory cache of loaded content indexed by title.
///
/// Usage in widgets:
/// ```dart
/// // Listen to changes with Consumer
/// Consumer<WikipediaProvider>(
///   builder: (context, provider, child) {
///     if (provider.isLoading) {
///       return CircularProgressIndicator();
///     }
///     final content = provider.getContent('Paris');
///     if (content == null) {
///       return Text('Content not loaded');
///     }
///     return Column(
///       children: [
///         Text(content.title),
///         Text(content.extract),
///       ],
///     );
///   },
/// )
///
/// // Trigger content fetch
/// Provider.of<WikipediaProvider>(context, listen: false)
///   .fetchContent('Paris');
/// ```
class WikipediaProvider extends ChangeNotifier {
  /// Repository for Wikipedia API calls
  final WikipediaRepository _repository;

  /// Cache of loaded content indexed by article title
  final Map<String, WikipediaContent> _content = {};

  /// Loading state for async operations
  bool _isLoading = false;

  /// Error message from last failed operation
  String? _errorMessage;

  /// Creates a [WikipediaProvider] with the specified repository.
  ///
  /// The repository is typically injected via dependency injection
  /// (e.g., from MultiProvider setup in main.dart).
  WikipediaProvider(this._repository);

  // Getters

  /// Map of all cached Wikipedia content indexed by article title.
  ///
  /// Use [getContent] for safer access to individual articles.
  Map<String, WikipediaContent> get content => _content;

  /// Whether an async operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Error message from the last failed operation, or null if no error.
  String? get errorMessage => _errorMessage;

  // Methods

  /// Fetches Wikipedia content for the given article title.
  ///
  /// If content for [title] is already cached, returns immediately without
  /// making an API call. Otherwise, fetches from Wikipedia API and caches
  /// the result.
  ///
  /// Updates [isLoading] and [errorMessage] during the operation.
  /// Notifies listeners when state changes.
  ///
  /// Example:
  /// ```dart
  /// await provider.fetchContent('Paris');
  /// final content = provider.getContent('Paris');
  /// // content now contains Wikipedia summary for Paris
  /// ```
  Future<void> fetchContent(String title) async {
    // Return immediately if already cached
    if (_content.containsKey(title)) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final wikiContent = await _repository.fetchSummary(title);
      _content[title] = wikiContent;
      _errorMessage = null;
    } catch (e) {
      debugPrint('WikipediaProvider: Failed to fetch content for "$title": $e');
      _errorMessage = 'Failed to fetch Wikipedia content: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gets cached content for the given title.
  ///
  /// Returns the [WikipediaContent] if already loaded via [fetchContent],
  /// or null if not yet loaded or if the fetch failed.
  ///
  /// Example:
  /// ```dart
  /// final content = provider.getContent('Paris');
  /// if (content != null) {
  ///   print(content.extract);
  /// }
  /// ```
  WikipediaContent? getContent(String title) {
    return _content[title];
  }

  /// Clears all cached Wikipedia content.
  ///
  /// This frees memory and forces fresh API calls on subsequent
  /// [fetchContent] requests. Typically used when resetting app state
  /// or clearing user data.
  ///
  /// Example:
  /// ```dart
  /// provider.clearCache();
  /// ```
  void clearCache() {
    _content.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // Repository disposal is handled by its owner (typically main.dart)
    super.dispose();
  }
}

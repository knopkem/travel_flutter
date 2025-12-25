import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Manages Wikipedia content loading state and caching.
///
/// This provider handles:
/// - Fetching Wikipedia article summaries and full content
/// - Two-tier caching: summaries and full articles
/// - Loading and error states
/// - Content retrieval for display
///
/// The provider uses [WikipediaRepository] to fetch article data and
/// maintains an in-memory cache of loaded content indexed by title.
///
/// Caching strategy:
/// - Summary cached on first fetch (quick preview)
/// - Full article cached separately when explicitly requested
/// - Both cached for session lifetime (memory only)
///
/// Usage in widgets:
/// ```dart
/// // Fetch summary first for quick display
/// await provider.fetchContent('Paris');
///
/// // Then fetch full article when user wants more
/// await provider.fetchFullArticle('Paris');
///
/// // Access cached content
/// final content = provider.getContent('Paris');
/// if (content?.isFullArticle ?? false) {
///   // Render full article with sections
/// } else {
///   // Show summary only
/// }
/// ```
class WikipediaProvider extends ChangeNotifier {
  /// Repository for Wikipedia API calls
  final WikipediaRepository _repository;

  /// Cache of loaded content indexed by "lang:title" key
  final Map<String, WikipediaContent> _content = {};

  /// Current language code for Wikipedia API requests
  String _languageCode = 'en';

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

  /// Map of all cached Wikipedia content indexed by "lang:title" key.
  ///
  /// Use [getContent] for safer access to individual articles.
  Map<String, WikipediaContent> get content => _content;

  /// Whether an async operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Error message from the last failed operation, or null if no error.
  String? get errorMessage => _errorMessage;

  /// Current language code being used for API requests.
  String get languageCode => _languageCode;

  /// Generate cache key from language and title
  String _cacheKey(String title) => '$_languageCode:$title';

  // Methods

  /// Fetches Wikipedia summary content for the given article title.
  ///
  /// If content for [title] is already cached (summary or full article),
  /// returns immediately without making an API call. Otherwise, fetches
  /// summary from Wikipedia API and caches the result.
  ///
  /// For full article content with sections, use [fetchFullArticle].
  ///
  /// Updates [isLoading] and [errorMessage] during the operation.
  /// Notifies listeners when state changes.
  ///
  /// Example:
  /// ```dart
  /// await provider.fetchContent('Paris');
  /// final content = provider.getContent('Paris');
  /// // content contains summary preview for Paris
  /// ```
  Future<void> fetchContent(String title) async {
    final key = _cacheKey(title);
    // Return immediately if already cached (summary or full)
    if (_content.containsKey(key)) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final wikiContent = await _repository.fetchSummary(title);
      _content[key] = wikiContent;
      _errorMessage = null;
    } catch (e) {
      debugPrint(
          'WikipediaProvider: Failed to fetch content for "$title" ($_languageCode): $e');
      _errorMessage = 'Unable to load content. Please check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches full Wikipedia article content with sections.
  ///
  /// If full article for [title] is already cached, returns immediately.
  /// If only summary is cached, upgrades it to full article. Otherwise,
  /// fetches complete article from Wikipedia API and caches it.
  ///
  /// Full articles include:
  /// - All content from summary (title, extract, thumbnail)
  /// - Complete article HTML
  /// - Parsed sections for navigation
  ///
  /// Updates [isLoading] and [errorMessage] during the operation.
  /// Notifies listeners when state changes.
  ///
  /// Example:
  /// ```dart
  /// await provider.fetchFullArticle('Paris');
  /// final content = provider.getContent('Paris');
  /// print('Article has ${content?.sections?.length ?? 0} sections');
  /// ```
  Future<void> fetchFullArticle(String title) async {
    final key = _cacheKey(title);
    // Return immediately if full article already cached
    final existing = _content[key];
    if (existing?.isFullArticle ?? false) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fullArticle = await _repository.fetchFullArticle(title);
      _content[key] = fullArticle;
      _errorMessage = null;
    } catch (e) {
      debugPrint(
        'WikipediaProvider: Failed to fetch full article for "$title" ($_languageCode): $e',
      );
      _errorMessage = 'Unable to load full article. Please try again later.';
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
    return _content[_cacheKey(title)];
  }

  /// Sets the language code for Wikipedia API requests.
  ///
  /// The [languageCode] should be a valid ISO 639-1 language code
  /// (e.g., 'en' for English, 'de' for German, 'fr' for French).
  ///
  /// This affects which language version of Wikipedia is queried.
  /// Should be called before fetching content when using local language
  /// content is enabled.
  ///
  /// Example:
  /// ```dart
  /// provider.setLanguageCode('de');
  /// await provider.fetchContent('Dresden');
  /// ```
  void setLanguageCode(String languageCode) {
    _languageCode = languageCode;
    _repository.setLanguageCode(languageCode);
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

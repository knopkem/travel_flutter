/// Represents Wikipedia article content for a location.
///
/// This model holds summary information fetched from the Wikipedia REST API
/// when the user views details for a selected location. Content is loaded
/// on-demand and cached during the detail screen lifetime.
///
/// State transitions:
/// - Loading: Initial state when screen opens
/// - Loaded: Content successfully fetched
/// - Error: API failure or page not found
///
/// Example:
/// ```dart
/// final content = WikipediaContent.fromJson({
///   'title': 'Paris',
///   'extract': 'Paris is the capital of France...',
///   'extract_html': '<p>Paris is the capital...</p>',
///   'thumbnail': {
///     'source': 'https://upload.wikimedia.org/...'
///   },
///   'content_urls': {
///     'desktop': {
///       'page': 'https://en.wikipedia.org/wiki/Paris'
///     }
///   }
/// });
/// ```
class WikipediaContent {
  /// Wikipedia page title (e.g., "Paris")
  final String title;

  /// Plain text summary (first paragraph/extract)
  final String summary;

  /// Optional HTML formatted extract for rich text display
  final String? extractHtml;

  /// Optional thumbnail image URL
  ///
  /// If null, no image should be displayed. Some locations may not have
  /// thumbnail images in Wikipedia.
  final String? thumbnailUrl;

  /// Full Wikipedia article URL
  ///
  /// Can be used to open the complete article in an external browser.
  final String pageUrl;

  /// Creates a new [WikipediaContent] instance.
  ///
  /// [title], [summary], and [pageUrl] are required.
  /// [extractHtml] and [thumbnailUrl] are optional.
  const WikipediaContent({
    required this.title,
    required this.summary,
    this.extractHtml,
    this.thumbnailUrl,
    required this.pageUrl,
  });

  /// Creates [WikipediaContent] from a Wikipedia REST API JSON response.
  ///
  /// Expected JSON structure from the /page/summary/{title} endpoint:
  /// ```json
  /// {
  ///   "title": "Paris",
  ///   "extract": "Paris is the capital...",
  ///   "extract_html": "<p>Paris is the capital...</p>",
  ///   "thumbnail": {
  ///     "source": "https://..."
  ///   },
  ///   "content_urls": {
  ///     "desktop": {
  ///       "page": "https://en.wikipedia.org/wiki/Paris"
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Handles missing optional fields gracefully (thumbnail, extract_html).
  factory WikipediaContent.fromJson(Map<String, dynamic> json) {
    final contentUrls = json['content_urls'] as Map<String, dynamic>;
    final desktopUrls = contentUrls['desktop'] as Map<String, dynamic>;

    return WikipediaContent(
      title: json['title'] as String,
      summary: json['extract'] as String,
      extractHtml: json['extract_html'] as String?,
      thumbnailUrl:
          (json['thumbnail'] as Map<String, dynamic>?)?['source'] as String?,
      pageUrl: desktopUrls['page'] as String,
    );
  }

  @override
  String toString() =>
      'WikipediaContent(title: $title, hasImage: ${thumbnailUrl != null})';
}

import 'article_section.dart';

/// Represents Wikipedia article content for a location.
///
/// This model holds both summary and full article content fetched from
/// the Wikipedia REST API. Content is loaded on-demand and cached.
///
/// Two fetching modes:
/// - Summary: Quick preview with first paragraph (from /page/summary endpoint)
/// - Full article: Complete article with sections (from /page/mobile-html endpoint)
///
/// State transitions:
/// - Loading: Initial state when screen opens
/// - Summary loaded: Quick preview available
/// - Full article loaded: Complete content with sections available
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

  /// Full article HTML content (null if only summary fetched)
  ///
  /// Contains the complete article HTML from the mobile-html endpoint.
  /// Used for rendering the full article with all sections.
  final String? fullContent;

  /// Article sections parsed from full content (null if only summary fetched)
  ///
  /// Structured list of sections for navigation and progressive rendering.
  /// Empty list means the article has no sections (very short article).
  final List<ArticleSection>? sections;

  /// Timestamp when the content was fetched
  ///
  /// Used for cache invalidation and displaying data freshness to users.
  final DateTime fetchedAt;

  /// Whether this is a full article or just a summary
  ///
  /// - true: Full article with sections has been fetched
  /// - false: Only summary/extract is available
  bool get isFullArticle => fullContent != null;

  /// Creates a new [WikipediaContent] instance.
  ///
  /// [title], [summary], [pageUrl], and [fetchedAt] are required.
  /// [extractHtml], [thumbnailUrl], [fullContent], and [sections] are optional.
  const WikipediaContent({
    required this.title,
    required this.summary,
    this.extractHtml,
    this.thumbnailUrl,
    required this.pageUrl,
    this.fullContent,
    this.sections,
    required this.fetchedAt,
  });

  /// Creates [WikipediaContent] from a Wikipedia REST API summary JSON response.
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
      fetchedAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields (for adding full content to existing summary).
  ///
  /// Used when upgrading from summary to full article:
  /// ```dart
  /// final fullArticle = summaryContent.copyWith(
  ///   fullContent: htmlContent,
  ///   sections: parsedSections,
  /// );
  /// ```
  WikipediaContent copyWith({
    String? title,
    String? summary,
    String? extractHtml,
    String? thumbnailUrl,
    String? pageUrl,
    String? fullContent,
    List<ArticleSection>? sections,
    DateTime? fetchedAt,
  }) {
    return WikipediaContent(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      extractHtml: extractHtml ?? this.extractHtml,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pageUrl: pageUrl ?? this.pageUrl,
      fullContent: fullContent ?? this.fullContent,
      sections: sections ?? this.sections,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  String toString() =>
      'WikipediaContent(title: $title, hasImage: ${thumbnailUrl != null}, isFullArticle: $isFullArticle, sectionCount: ${sections?.length ?? 0})';
}

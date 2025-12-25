import '../models/models.dart';

/// Repository interface for Wikipedia content operations.
///
/// Implementations of this interface provide access to Wikipedia article
/// summaries and full content. Results are returned as [WikipediaContent] objects.
///
/// Two fetch modes:
/// - [fetchSummary]: Quick preview with first paragraph
/// - [fetchFullArticle]: Complete article with all sections
///
/// Example usage:
/// ```dart
/// final repository = RestWikipediaRepository();
/// try {
///   // Quick summary first
///   final summary = await repository.fetchSummary('Paris');
///   print('Summary: ${summary.summary}');
///
///   // Then fetch full article if needed
///   final fullArticle = await repository.fetchFullArticle('Paris');
///   print('Sections: ${fullArticle.sections?.length}');
/// } catch (e) {
///   print('Failed to fetch content: $e');
/// } finally {
///   repository.dispose();
/// }
/// ```
abstract class WikipediaRepository {
  /// Fetches the summary for a Wikipedia article by [title].
  ///
  /// Returns a [WikipediaContent] object containing the article's title,
  /// summary text, optional thumbnail image, and page URL.
  ///
  /// The [title] parameter should be the location name (e.g., "Paris",
  /// "London"). The title will be URL-encoded automatically.
  ///
  /// Throws an [Exception] if:
  /// - Network request fails
  /// - Article not found (404)
  /// - API returns an error status code
  /// - Response cannot be parsed
  ///
  /// Example:
  /// ```dart
  /// final content = await repository.fetchSummary('Berlin');
  /// print('Article: ${content.title}');
  /// print('${content.summary.substring(0, 100)}...');
  /// ```
  Future<WikipediaContent> fetchSummary(String title);

  /// Fetches the full article content for a Wikipedia article by [title].
  ///
  /// Returns a [WikipediaContent] object containing the complete article HTML
  /// and parsed sections for navigation. Includes all the summary fields plus
  /// full content and sections.
  ///
  /// The [title] parameter should be the location name (e.g., "Paris",
  /// "London"). The title will be URL-encoded automatically.
  ///
  /// This method fetches significantly more data than [fetchSummary], so it
  /// should be called only when the user explicitly wants the full article.
  ///
  /// Throws an [Exception] if:
  /// - Network request fails
  /// - Article not found (404)
  /// - API returns an error status code
  /// - Response cannot be parsed
  ///
  /// Example:
  /// ```dart
  /// final content = await repository.fetchFullArticle('Berlin');
  /// print('Article has ${content.sections?.length} sections');
  /// for (final section in content.sections ?? []) {
  ///   print('${' ' * (section.level - 2)}${section.title}');
  /// }
  /// ```
  Future<WikipediaContent> fetchFullArticle(String title);

  /// Sets the language code for Wikipedia API requests.
  ///
  /// The [languageCode] should be a valid ISO 639-1 language code
  /// (e.g., 'en' for English, 'de' for German, 'fr' for French).
  ///
  /// This affects which language version of Wikipedia is queried.
  /// For example, setting 'de' will query de.wikipedia.org instead of
  /// en.wikipedia.org.
  ///
  /// Example:
  /// ```dart
  /// repository.setLanguageCode('de'); // Use German Wikipedia
  /// final content = await repository.fetchSummary('Berlin');
  /// ```
  void setLanguageCode(String languageCode);

  /// Releases resources used by this repository.
  ///
  /// Call this method when the repository is no longer needed to close
  /// HTTP connections and free resources.
  void dispose();
}

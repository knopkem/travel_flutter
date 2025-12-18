import '../models/models.dart';

/// Repository interface for Wikipedia content operations.
///
/// Implementations of this interface provide access to Wikipedia article
/// summaries and content. Results are returned as [WikipediaContent] objects.
///
/// Example usage:
/// ```dart
/// final repository = RestWikipediaRepository();
/// try {
///   final content = await repository.fetchSummary('Paris');
///   print('Title: ${content.title}');
///   print('Summary: ${content.summary}');
///   if (content.thumbnailUrl != null) {
///     print('Image: ${content.thumbnailUrl}');
///   }
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

  /// Releases resources used by this repository.
  ///
  /// Call this method when the repository is no longer needed to close
  /// HTTP connections and free resources.
  void dispose();
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'wikipedia_repository.dart';

/// Implementation of [WikipediaRepository] using Wikipedia REST API.
///
/// This repository:
/// - Fetches article summaries from Wikipedia's REST API v1
/// - Handles network errors and missing articles gracefully
/// - Returns formatted content with title, summary, and optional thumbnail
/// - Uses a 10-second timeout for requests
///
/// The Wikipedia REST API is free and doesn't require authentication.
/// It provides quick access to article summaries without parsing full HTML.
///
/// Usage:
/// ```dart
/// final repository = RestWikipediaRepository();
/// try {
///   final content = await repository.fetchSummary('Paris');
///   print('Title: ${content.title}');
///   print('Summary: ${content.summary}');
///   print('Full article: ${content.pageUrl}');
///   if (content.thumbnailUrl != null) {
///     print('Image available: ${content.thumbnailUrl}');
///   }
/// } catch (e) {
///   print('Error: $e');
/// } finally {
///   repository.dispose();
/// }
/// ```
///
/// **Error Handling**: This implementation provides user-friendly error
/// messages for common failures (404, network issues, timeouts).
class RestWikipediaRepository implements WikipediaRepository {
  final http.Client _client;
  String _languageCode = 'en';

  /// Creates a new Wikipedia REST API repository.
  ///
  /// Optionally provide a custom [client] for testing purposes.
  /// If not provided, a default HTTP client will be created.
  RestWikipediaRepository({http.Client? client})
      : _client = client ?? http.Client();

  /// Get the base URL with current language code
  String get _baseUrl => 'https://$_languageCode.wikipedia.org/api/rest_v1';

  /// Set the language code for API requests (e.g., 'de' for German)
  @override
  void setLanguageCode(String languageCode) {
    _languageCode = languageCode;
  }

  @override
  Future<WikipediaContent> fetchSummary(String title) async {
    // URL-encode the title to handle spaces and special characters
    final encodedTitle = Uri.encodeComponent(title);
    final uri = Uri.parse('$_baseUrl/page/summary/$encodedTitle');

    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': 'TravelFlutterApp/1.0'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return WikipediaContent.fromJson(data);
      } else if (response.statusCode == 404) {
        debugPrint('Wikipedia article not found: $title (HTTP 404)');
        throw Exception(
          'No Wikipedia article found for "$title". The article may not exist or the title may be misspelled.',
        );
      } else {
        debugPrint('Wikipedia API error: HTTP ${response.statusCode}');
        throw Exception('Wikipedia API error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      debugPrint('Wikipedia network error: $e');
      throw Exception('Network error: Unable to connect to Wikipedia');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('Wikipedia request timeout after 10 seconds');
        throw Exception('Request timeout: Wikipedia took too long to respond');
      }
      debugPrint('Wikipedia unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<WikipediaContent> fetchFullArticle(String title) async {
    // First fetch summary for metadata (thumbnail, summary text)
    final summary = await fetchSummary(title);

    // Then fetch full HTML content
    final encodedTitle = Uri.encodeComponent(title);
    final uri = Uri.parse('$_baseUrl/page/mobile-html/$encodedTitle');

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'TravelFlutterApp/1.0'}).timeout(
        const Duration(seconds: 15),
      ); // Longer timeout for full content

      if (response.statusCode == 200) {
        final html = response.body;
        final sections = _parseSections(html);

        return summary.copyWith(
          fullContent: html,
          sections: sections,
          fetchedAt: DateTime.now(),
        );
      } else if (response.statusCode == 404) {
        debugPrint('Wikipedia full article not found: $title (HTTP 404)');
        throw Exception(
          'No Wikipedia article found for "$title". The article may not exist or the title may be misspelled.',
        );
      } else {
        debugPrint('Wikipedia API error: HTTP ${response.statusCode}');
        throw Exception('Wikipedia API error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      debugPrint('Wikipedia network error: $e');
      throw Exception('Network error: Unable to connect to Wikipedia');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('Wikipedia request timeout after 15 seconds');
        throw Exception('Request timeout: Wikipedia took too long to respond');
      }
      debugPrint('Wikipedia unexpected error: $e');
      rethrow;
    }
  }

  /// Parses HTML to extract article sections (h2, h3 tags)
  ///
  /// This is a simple parser that looks for heading tags and extracts
  /// content between them. For more robust parsing, consider using
  /// an HTML parser package like 'html' or 'beautiful_soup'.
  List<ArticleSection> _parseSections(String html) {
    final sections = <ArticleSection>[];

    // Simple regex-based parsing for headings
    // This captures h2 and h3 tags with their content
    final headingPattern = RegExp(
      r'<h([23])[^>]*>(.*?)</h\1>',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = headingPattern.allMatches(html);
    if (matches.isEmpty) {
      return sections; // No sections found
    }

    final matchList = matches.toList();
    for (int i = 0; i < matchList.length; i++) {
      final match = matchList[i];
      final level = int.parse(match.group(1)!);
      final title = _stripHtmlTags(match.group(2)!);

      // Extract content between this heading and the next one
      final startIndex = match.end;
      final endIndex =
          i < matchList.length - 1 ? matchList[i + 1].start : html.length;

      final content = html.substring(startIndex, endIndex).trim();

      // Skip empty sections and navigation/metadata sections
      if (content.isNotEmpty &&
          !_isMetadataSection(title) &&
          title.isNotEmpty) {
        sections.add(
          ArticleSection(title: title, content: content, level: level),
        );
      }
    }

    return sections;
  }

  /// Strips HTML tags from a string
  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  /// Checks if a section title is metadata (not article content)
  bool _isMetadataSection(String title) {
    final lowercaseTitle = title.toLowerCase();
    return lowercaseTitle.contains('references') ||
        lowercaseTitle.contains('external links') ||
        lowercaseTitle.contains('see also') ||
        lowercaseTitle.contains('notes') ||
        lowercaseTitle.contains('bibliography') ||
        lowercaseTitle.contains('further reading');
  }

  @override
  void dispose() {
    _client.close();
  }
}

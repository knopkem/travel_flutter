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
  final String _baseUrl = 'https://en.wikipedia.org/api/rest_v1';

  /// Creates a new Wikipedia REST API repository.
  ///
  /// Optionally provide a custom [client] for testing purposes.
  /// If not provided, a default HTTP client will be created.
  RestWikipediaRepository({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<WikipediaContent> fetchSummary(String title) async {
    // URL-encode the title to handle spaces and special characters
    final encodedTitle = Uri.encodeComponent(title);
    final uri = Uri.parse('$_baseUrl/page/summary/$encodedTitle');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'TravelFlutterApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return WikipediaContent.fromJson(data);
      } else if (response.statusCode == 404) {
        debugPrint('Wikipedia article not found: $title (HTTP 404)');
        throw Exception(
            'No Wikipedia article found for "$title". The article may not exist or the title may be misspelled.');
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
  void dispose() {
    _client.close();
  }
}

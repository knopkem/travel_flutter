import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/poi.dart';

/// Service for interacting with OpenAI API for POI guidance filtering
class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxDailyRequests = 50;

  final http.Client _client;

  OpenAIService({http.Client? client}) : _client = client ?? http.Client();

  /// Validates an OpenAI API key by making a simple API call
  ///
  /// Returns true if the key is valid, false otherwise.
  /// Throws an exception if there's a network error.
  Future<bool> validateApiKey(String apiKey) async {
    if (apiKey.isEmpty) return false;

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(_timeout);

      return response.statusCode == 200;
    } on http.ClientException {
      throw Exception('Network error while validating API key');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('API request timed out');
      }
      return false;
    }
  }

  /// Filters POIs based on user guidance text using OpenAI
  ///
  /// Sends POI data (id, name, description) to GPT-4o-mini and asks it to
  /// return IDs of POIs that match the guidance theme/keywords.
  ///
  /// Returns a list of POI IDs that match the guidance.
  /// Throws an exception if the API call fails or daily limit is reached.
  ///
  /// For large POI lists, automatically batches requests to avoid context limits.

  Future<List<String>> filterPOIsByGuidance(
    List<POI> pois,
    String guidance,
    String apiKey,
    String model,
    int batchSize,
  ) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    if (pois.isEmpty) {
      return [];
    }

    // Split into batches if needed
    if (pois.length <= batchSize) {
      return _filterBatch(pois, guidance, apiKey, model);
    }

    // Process in batches and merge results
    final List<String> allMatchingIds = [];
    final batches = <List<POI>>[];

    for (var i = 0; i < pois.length; i += batchSize) {
      final end = (i + batchSize < pois.length) ? i + batchSize : pois.length;
      batches.add(pois.sublist(i, end));
    }

    // Process batches (could be parallelized but doing sequentially to avoid rate limits)
    for (final batch in batches) {
      try {
        final batchResults = await _filterBatch(batch, guidance, apiKey, model);
        allMatchingIds.addAll(batchResults);
      } catch (e) {
        // If one batch fails, continue with others
        debugPrint('Batch failed: $e');
      }
    }

    return allMatchingIds;
  }

  /// Filter a single batch of POIs
  Future<List<String>> _filterBatch(
    List<POI> pois,
    String guidance,
    String apiKey,
    String model,
  ) async {
    // Prepare POI data for the API (truncate descriptions to save tokens)
    final poisData = pois.map((poi) {
      return {
        'id': poi.id,
        'name': poi.name,
        'type': poi.type.displayName,
        'description': poi.description != null
            ? (poi.description!.length > 80
                ? '${poi.description!.substring(0, 80)}...'
                : poi.description!)
            : '',
      };
    }).toList();

    final prompt = '''
Filter POIs matching theme: "$guidance"

POIs:
${jsonEncode(poisData)}

Return ONLY a JSON array of matching IDs: ["id1", "id2"]
''';

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You filter tourist attractions by theme. Respond with valid JSON array only.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
              'temperature': 0.3,
              'max_tokens': 300,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 429) {
        throw Exception(
            'OpenAI API rate limit reached. Please try again later.');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'OpenAI API error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String?;

      if (content == null || content.isEmpty) {
        throw Exception('Empty response from OpenAI');
      }

      // Parse the JSON array from the response
      // Sometimes the model might wrap it in markdown code blocks, so clean it
      String cleanContent = content.trim();
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.substring(7);
      }
      if (cleanContent.startsWith('```')) {
        cleanContent = cleanContent.substring(3);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.substring(0, cleanContent.length - 3);
      }
      cleanContent = cleanContent.trim();

      try {
        final matchingIds = (jsonDecode(cleanContent) as List)
            .map((id) => id.toString())
            .toList();

        return matchingIds;
      } catch (parseError) {
        // JSON parsing failed - return empty to show all POIs
        throw Exception('AI response was invalid. Showing all attractions.');
      }
    } on http.ClientException {
      throw Exception('Network error. Showing all attractions.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out. Showing all attractions.');
      }
      rethrow;
    }
  }

  /// Get the maximum daily requests allowed
  static int get maxDailyRequests => _maxDailyRequests;

  void dispose() {
    _client.close();
  }
}

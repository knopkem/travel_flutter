import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'geocoding_repository.dart';

/// Implementation of [GeocodingRepository] using OpenStreetMap Nominatim API.
///
/// This repository:
/// - Searches for locations using the Nominatim geocoding service
/// - Enforces rate limiting (1 request per second) as required by Nominatim
/// - Handles network errors and API failures gracefully
/// - Returns up to 10 location suggestions per search
///
/// The Nominatim service is free and doesn't require API keys, but has a
/// rate limit of 1 request per second which this implementation respects.
///
/// Usage:
/// ```dart
/// final repository = NominatimGeocodingRepository();
/// try {
///   final suggestions = await repository.searchLocations('Paris');
///   print('Found ${suggestions.length} suggestions');
///   for (final suggestion in suggestions) {
///     print('- ${suggestion.displayName}');
///   }
/// } catch (e) {
///   print('Error: $e');
/// } finally {
///   repository.dispose();
/// }
/// ```
///
/// **Rate Limiting**: This implementation automatically delays requests to
/// ensure compliance with Nominatim's 1 request/second limit.
class NominatimGeocodingRepository implements GeocodingRepository {
  final http.Client _client;
  final String _baseUrl = 'https://nominatim.openstreetmap.org';
  DateTime? _lastRequestTime;

  /// Creates a new Nominatim geocoding repository.
  ///
  /// Optionally provide a custom [client] for testing purposes.
  /// If not provided, a default HTTP client will be created.
  NominatimGeocodingRepository({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<LocationSuggestion>> searchLocations(String query) async {
    // Rate limiting: ensure at least 1 second between requests
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed.inMilliseconds < 1000) {
        await Future.delayed(
            Duration(milliseconds: 1000 - elapsed.inMilliseconds));
      }
    }
    _lastRequestTime = DateTime.now();

    // Build the search URL with query parameters
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '10',
      'addressdetails': '1',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'TravelFlutterApp/1.0',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) =>
                LocationSuggestion.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 429) {
        throw Exception(
            'Rate limit exceeded. Please wait a moment and try again.');
      } else {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }
    } on http.ClientException {
      throw Exception('Network error: Unable to connect to geocoding service');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
            'Request timeout: Geocoding service took too long to respond');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}

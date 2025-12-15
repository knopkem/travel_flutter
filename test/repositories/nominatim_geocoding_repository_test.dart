import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:travel_flutter_app/repositories/nominatim_geocoding_repository.dart';
import 'package:travel_flutter_app/models/location_suggestion.dart';

void main() {
  group('NominatimGeocodingRepository', () {
    test('searchLocations returns list of suggestions on success', () async {
      // Mock HTTP client that returns successful response
      final mockClient = MockClient((request) async {
        // Verify User-Agent header and email parameter are set properly
        expect(request.headers['User-Agent'], contains('TravelFlutterApp/1.0'));
        expect(request.headers['User-Agent'], contains('Flutter'));
        expect(request.url.queryParameters['email'], isNotNull);
        expect(request.url.queryParameters['email'],
            contains('@')); // Email format

        // Return mock Nominatim response
        final mockResponse = [
          {
            'osm_id': 240109189,
            'display_name': 'Berlin, Germany',
            'lat': '52.5200066',
            'lon': '13.404954',
            'address': {
              'city': 'Berlin',
              'country': 'Germany',
            }
          },
          {
            'osm_id': 62422,
            'display_name': 'Paris, France',
            'lat': '48.8566101',
            'lon': '2.3514992',
            'address': {
              'city': 'Paris',
              'country': 'France',
            }
          }
        ];

        return http.Response(json.encode(mockResponse), 200);
      });

      final repository = NominatimGeocodingRepository(client: mockClient);
      final results = await repository.searchLocations('Berlin');

      expect(results, isA<List<LocationSuggestion>>());
      expect(results.length, 2);
      expect(results[0].name, 'Berlin');
      expect(results[0].country, 'Germany');
      expect(results[1].name, 'Paris');

      repository.dispose();
    });

    test('searchLocations handles 418 error (blocked User-Agent)', () async {
      // Mock HTTP client that returns 418 status
      final mockClient = MockClient((request) async {
        return http.Response('Error: blocked', 418);
      });

      final repository = NominatimGeocodingRepository(client: mockClient);

      expect(
        () => repository.searchLocations('Berlin'),
        throwsA(predicate((e) =>
            e.toString().contains('Service unavailable') ||
            e.toString().contains('check your internet connection'))),
      );

      repository.dispose();
    });

    test('searchLocations handles 429 rate limit error', () async {
      // Mock HTTP client that returns 429 status
      final mockClient = MockClient((request) async {
        return http.Response('Too many requests', 429);
      });

      final repository = NominatimGeocodingRepository(client: mockClient);

      expect(
        () => repository.searchLocations('Berlin'),
        throwsA(predicate((e) => e.toString().contains('Rate limit exceeded'))),
      );

      repository.dispose();
    });

    test('searchLocations handles network errors', () async {
      // Mock HTTP client that throws ClientException
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      final repository = NominatimGeocodingRepository(client: mockClient);

      expect(
        () => repository.searchLocations('Berlin'),
        throwsA(predicate((e) =>
            e.toString().contains('Network error') ||
            e.toString().contains('Unable to connect'))),
      );

      repository.dispose();
    });

    test('searchLocations handles malformed JSON', () async {
      // Mock HTTP client that returns invalid JSON
      final mockClient = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final repository = NominatimGeocodingRepository(client: mockClient);

      expect(
        () => repository.searchLocations('Berlin'),
        throwsA(isA<FormatException>()),
      );

      repository.dispose();
    });

    test('searchLocations respects rate limiting (1 req/sec)', () async {
      int requestCount = 0;
      final stopwatch = Stopwatch()..start();

      // Mock HTTP client that tracks requests
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(json.encode([]), 200);
      });

      final repository = NominatimGeocodingRepository(client: mockClient);

      // Make two requests
      await repository.searchLocations('Berlin');
      await repository.searchLocations('Paris');

      stopwatch.stop();

      // Second request should be delayed by ~1 second
      expect(requestCount, 2);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(900));

      repository.dispose();
    });

    test('searchLocations handles empty results', () async {
      // Mock HTTP client that returns empty array
      final mockClient = MockClient((request) async {
        return http.Response(json.encode([]), 200);
      });

      final repository = NominatimGeocodingRepository(client: mockClient);
      final results = await repository.searchLocations('NonexistentPlace');

      expect(results, isEmpty);

      repository.dispose();
    });
  });
}

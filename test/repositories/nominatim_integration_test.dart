import 'package:flutter_test/flutter_test.dart';
import 'package:travel_flutter_app/repositories/nominatim_geocoding_repository.dart';

/// Integration test to verify real API calls work.
/// Run with: flutter test test/repositories/nominatim_integration_test.dart
void main() {
  group('NominatimGeocodingRepository Integration Tests', () {
    test('Real API call should work with proper headers', () async {
      // Create repository with real HTTP client
      final repository = NominatimGeocodingRepository();

      try {
        // Make actual API call to Nominatim
        final results = await repository.searchLocations('Berlin');

        // Verify we got results
        expect(results, isNotEmpty);
        expect(results.first.name, contains('Berlin'));

        // Test passes - API working correctly
        expect(results.length, greaterThan(0));
      } finally {
        repository.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}

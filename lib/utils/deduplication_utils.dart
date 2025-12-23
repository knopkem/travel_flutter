import '../models/poi.dart';
import 'distance_calculator.dart';

/// Proximity threshold for duplicate detection (meters)
const double proximityThresholdMeters = 50.0;

/// Name similarity threshold for duplicate detection (0.0 to 1.0)
const double nameSimilarityThreshold = 0.7;

/// Deduplicate POIs using proximity and name similarity
/// Returns a list of unique POIs with merged sources where duplicates were found
List<POI> deduplicatePOIs(List<POI> pois) {
  if (pois.isEmpty) return [];
  if (pois.length == 1) return pois;

  final result = <POI>[];
  final processed = <int>{};

  for (int i = 0; i < pois.length; i++) {
    if (processed.contains(i)) continue;

    final current = pois[i];
    final duplicates = <POI>[current];
    processed.add(i);

    // Find all duplicates of current POI
    for (int j = i + 1; j < pois.length; j++) {
      if (processed.contains(j)) continue;

      final candidate = pois[j];

      // Phase 1: Check proximity
      final distance = calculateDistance(
        current.latitude,
        current.longitude,
        candidate.latitude,
        candidate.longitude,
      );

      if (distance > proximityThresholdMeters) continue;

      // Phase 2: Check name similarity
      final similarity = calculateNameSimilarity(current.name, candidate.name);

      if (similarity >= nameSimilarityThreshold) {
        duplicates.add(candidate);
        processed.add(j);
      }
    }

    // Merge all duplicates
    result.add(duplicates.length == 1 ? current : POI.merge(duplicates));
  }

  return result;
}

/// Calculate name similarity using normalized Levenshtein distance
/// Returns a value between 0.0 (completely different) and 1.0 (identical)
double calculateNameSimilarity(String name1, String name2) {
  final s1 = name1.toLowerCase().trim();
  final s2 = name2.toLowerCase().trim();

  if (s1 == s2) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;

  final distance = _levenshteinDistance(s1, s2);
  final maxLength = s1.length > s2.length ? s1.length : s2.length;

  return 1.0 - (distance / maxLength);
}

/// Calculate Levenshtein distance between two strings
int _levenshteinDistance(String s1, String s2) {
  final len1 = s1.length;
  final len2 = s2.length;

  // Create a 2D array to store distances
  final matrix = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));

  // Initialize first row and column
  for (int i = 0; i <= len1; i++) {
    matrix[i][0] = i;
  }
  for (int j = 0; j <= len2; j++) {
    matrix[0][j] = j;
  }

  // Fill the matrix
  for (int i = 1; i <= len1; i++) {
    for (int j = 1; j <= len2; j++) {
      final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
      matrix[i][j] = [
        matrix[i - 1][j] + 1, // deletion
        matrix[i][j - 1] + 1, // insertion
        matrix[i - 1][j - 1] + cost, // substitution
      ].reduce((a, b) => a < b ? a : b);
    }
  }

  return matrix[len1][len2];
}

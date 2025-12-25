/// Utility functions for the TravelPal app.
///
/// This barrel file exports all utility functions for convenient importing.
/// Instead of importing individual utility files, use:
/// ```dart
/// import 'package:travel_flutter_app/utils/utils.dart';
/// ```
///
/// Available utilities:
/// - [calculateDistance]: Haversine formula for geographic distances
/// - [deduplicatePOIs]: Remove duplicate POIs using proximity and name matching
/// - [calculateNameSimilarity]: Normalized Levenshtein distance
/// - [calculateNotabilityScore]: Score POIs based on attributes
library;

export 'distance_calculator.dart';
export 'deduplication_utils.dart';
export 'notability_scorer.dart';

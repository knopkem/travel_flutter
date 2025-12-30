/// Utility functions for formatting values.
library;

/// Formats a distance in meters to a human-readable string.
///
/// Distances less than 1000m are shown as meters (e.g., "750m").
/// Distances >= 1000m are shown as kilometers with one decimal (e.g., "1.5 km").
///
/// Example:
/// ```dart
/// formatDistance(750);   // "750m"
/// formatDistance(1500);  // "1.5 km"
/// formatDistance(2000);  // "2.0 km"
/// ```
String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()}m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

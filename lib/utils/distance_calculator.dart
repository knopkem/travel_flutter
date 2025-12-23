import 'dart:math';

/// Calculate the great-circle distance between two points using the Haversine formula
/// Returns distance in meters
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  // Validate inputs
  if (lat1 < -90 || lat1 > 90) {
    throw ArgumentError('lat1 must be between -90 and 90');
  }
  if (lat2 < -90 || lat2 > 90) {
    throw ArgumentError('lat2 must be between -90 and 90');
  }
  if (lon1 < -180 || lon1 > 180) {
    throw ArgumentError('lon1 must be between -180 and 180');
  }
  if (lon2 < -180 || lon2 > 180) {
    throw ArgumentError('lon2 must be between -180 and 180');
  }

  const earthRadiusMeters = 6371000.0;

  // Convert to radians
  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final deltaPhi = (lat2 - lat1) * pi / 180;
  final deltaLambda = (lon2 - lon1) * pi / 180;

  // Haversine formula
  final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
      cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusMeters * c;
}

import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';

/// Represents a cluster of POIs of the same type
class POICluster {
  final POIType type;
  final List<POI> pois;
  final LatLng center;

  POICluster({
    required this.type,
    required this.pois,
    required this.center,
  });

  int get count => pois.length;

  /// Returns true if this is a cluster (more than 1 POI)
  bool get isCluster => pois.length > 1;
}

/// Utility for clustering POIs on the map
class POIClusterManager {
  /// Minimum zoom level at which clustering is applied
  /// Above this zoom, all POIs are shown individually
  static const double minClusterZoom = 14.0;

  /// Clusters POIs by type based on proximity
  ///
  /// [pois] - List of POIs to cluster
  /// [zoom] - Current map zoom level (higher = more zoomed in)
  /// [clusterRadiusMeters] - Cluster radius in meters (default 800m)
  ///
  /// Returns a list of POICluster objects, where each cluster contains
  /// either a single POI or multiple POIs of the same type that are close together.
  static List<POICluster> clusterPOIs(List<POI> pois, double zoom,
      {int clusterRadiusMeters = 800}) {
    // If zoomed in enough, don't cluster - show all individual POIs
    if (zoom >= minClusterZoom) {
      return pois
          .map((poi) => POICluster(
                type: poi.type,
                pois: [poi],
                center: LatLng(poi.latitude, poi.longitude),
              ))
          .toList();
    }

    // Convert meters to degrees (approximate at equator: 1 degree ≈ 111km)
    final baseClusterRadiusDegrees = clusterRadiusMeters / 111000.0;

    // Calculate cluster radius based on zoom level
    // Lower zoom = larger radius = more aggressive clustering
    final clusterRadius = baseClusterRadiusDegrees * math.pow(2, (13 - zoom));

    // Group POIs by type first
    final Map<POIType, List<POI>> poisByType = {};
    for (final poi in pois) {
      poisByType.putIfAbsent(poi.type, () => []).add(poi);
    }

    final List<POICluster> clusters = [];

    // Cluster each type separately
    for (final entry in poisByType.entries) {
      final type = entry.key;
      final typePois = List<POI>.from(entry.value);

      // Use simple greedy clustering algorithm
      while (typePois.isNotEmpty) {
        // Start a new cluster with the first POI
        final seed = typePois.removeAt(0);
        final clusterPois = <POI>[seed];
        double sumLat = seed.latitude;
        double sumLng = seed.longitude;

        // Find all POIs within cluster radius
        final toRemove = <int>[];
        for (int i = 0; i < typePois.length; i++) {
          final poi = typePois[i];
          final dLat = poi.latitude - seed.latitude;
          final dLng = poi.longitude - seed.longitude;
          final distance = math.sqrt(dLat * dLat + dLng * dLng);

          if (distance <= clusterRadius) {
            clusterPois.add(poi);
            sumLat += poi.latitude;
            sumLng += poi.longitude;
            toRemove.add(i);
          }
        }

        // Remove clustered POIs (in reverse order to maintain indices)
        for (final index in toRemove.reversed) {
          typePois.removeAt(index);
        }

        // Calculate cluster center as average of all POI positions
        final centerLat = sumLat / clusterPois.length;
        final centerLng = sumLng / clusterPois.length;

        clusters.add(POICluster(
          type: type,
          pois: clusterPois,
          center: LatLng(centerLat, centerLng),
        ));
      }
    }

    return clusters;
  }
}

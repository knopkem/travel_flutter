/// Categorical types for Points of Interest
enum POIType {
  monument,
  museum,
  landmark,
  religiousSite,
  park,
  viewpoint,
  touristAttraction,
  historicSite,
  square,
  other;

  /// Returns a user-friendly display name for this POI type
  String get displayName {
    switch (this) {
      case POIType.monument:
        return 'Monument';
      case POIType.museum:
        return 'Museum';
      case POIType.landmark:
        return 'Landmark';
      case POIType.religiousSite:
        return 'Religious Site';
      case POIType.park:
        return 'Park';
      case POIType.viewpoint:
        return 'Viewpoint';
      case POIType.touristAttraction:
        return 'Tourist Attraction';
      case POIType.historicSite:
        return 'Historic Site';
      case POIType.square:
        return 'Square';
      case POIType.other:
        return 'Other';
    }
  }
}

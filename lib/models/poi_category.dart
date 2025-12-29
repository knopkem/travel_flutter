/// Categories for grouping POI types
enum POICategory {
  attraction,
  commercial;

  /// Returns a user-friendly display name for this POI category
  String get displayName {
    switch (this) {
      case POICategory.attraction:
        return 'Attractions';
      case POICategory.commercial:
        return 'Commercial';
    }
  }
}

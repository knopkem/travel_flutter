import 'poi_category.dart';

/// Categorical types for Points of Interest
enum POIType {
  // Attraction types
  monument,
  museum,
  religiousSite,
  park,
  viewpoint,
  touristAttraction,
  historicSite,
  other,

  // Commercial types
  restaurant,
  cafe,
  bakery,
  supermarket,
  hardwareStore,
  pharmacy,
  gasStation,
  hotel,
  bar,
  fastFood;

  /// Returns the category this POI type belongs to
  POICategory get category {
    switch (this) {
      case POIType.monument:
      case POIType.museum:
      case POIType.religiousSite:
      case POIType.park:
      case POIType.viewpoint:
      case POIType.touristAttraction:
      case POIType.historicSite:
      case POIType.other:
        return POICategory.attraction;
      case POIType.restaurant:
      case POIType.cafe:
      case POIType.bakery:
      case POIType.supermarket:
      case POIType.hardwareStore:
      case POIType.pharmacy:
      case POIType.gasStation:
      case POIType.hotel:
      case POIType.bar:
      case POIType.fastFood:
        return POICategory.commercial;
    }
  }

  /// Returns a user-friendly display name for this POI type
  String get displayName {
    switch (this) {
      case POIType.monument:
        return 'Monument';
      case POIType.museum:
        return 'Museum';
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
      case POIType.other:
        return 'Other';
      case POIType.restaurant:
        return 'Restaurant';
      case POIType.cafe:
        return 'Café';
      case POIType.bakery:
        return 'Bakery';
      case POIType.supermarket:
        return 'Supermarket';
      case POIType.hardwareStore:
        return 'Hardware Store';
      case POIType.pharmacy:
        return 'Pharmacy';
      case POIType.gasStation:
        return 'Gas Station';
      case POIType.hotel:
        return 'Hotel';
      case POIType.bar:
        return 'Bar';
      case POIType.fastFood:
        return 'Fast Food';
    }
  }
}

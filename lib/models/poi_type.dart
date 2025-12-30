import 'package:flutter/material.dart';

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

  /// Returns the icon for this POI type
  IconData get icon {
    switch (this) {
      case POIType.monument:
        return Icons.account_balance;
      case POIType.museum:
        return Icons.museum;
      case POIType.religiousSite:
        return Icons.church;
      case POIType.park:
        return Icons.park;
      case POIType.viewpoint:
        return Icons.landscape;
      case POIType.touristAttraction:
        return Icons.attractions;
      case POIType.historicSite:
        return Icons.castle;
      case POIType.restaurant:
        return Icons.restaurant;
      case POIType.cafe:
        return Icons.local_cafe;
      case POIType.bakery:
        return Icons.bakery_dining;
      case POIType.supermarket:
        return Icons.shopping_cart;
      case POIType.hardwareStore:
        return Icons.hardware;
      case POIType.pharmacy:
        return Icons.local_pharmacy;
      case POIType.gasStation:
        return Icons.local_gas_station;
      case POIType.hotel:
        return Icons.hotel;
      case POIType.bar:
        return Icons.local_bar;
      case POIType.fastFood:
        return Icons.fastfood;
      case POIType.other:
        return Icons.place;
    }
  }

  /// Returns the color for this POI type
  Color get color {
    switch (this) {
      case POIType.monument:
        return Colors.brown;
      case POIType.museum:
        return Colors.purple;
      case POIType.religiousSite:
        return Colors.blue;
      case POIType.park:
        return Colors.green;
      case POIType.viewpoint:
        return Colors.orange;
      case POIType.touristAttraction:
        return Colors.pink;
      case POIType.historicSite:
        return Colors.amber;
      case POIType.restaurant:
        return Colors.red;
      case POIType.cafe:
        return const Color(0xFFA1887F); // Colors.brown[300]
      case POIType.bakery:
        return const Color(0xFFFFB74D); // Colors.orange[300]
      case POIType.supermarket:
        return const Color(0xFF1976D2); // Colors.blue[700]
      case POIType.hardwareStore:
        return Colors.deepOrange;
      case POIType.pharmacy:
        return const Color(0xFF388E3C); // Colors.green[700]
      case POIType.gasStation:
        return const Color(0xFFFBC02D); // Colors.yellow[700]
      case POIType.hotel:
        return Colors.indigo;
      case POIType.bar:
        return const Color(0xFF7B1FA2); // Colors.purple[700]
      case POIType.fastFood:
        return const Color(0xFFD32F2F); // Colors.red[700]
      case POIType.other:
        return Colors.grey;
    }
  }
}

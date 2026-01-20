import 'package:uuid/uuid.dart';
import 'poi_type.dart';

/// Represents a single item in a shopping list
class ShoppingItem {
  final String id;
  final String text;
  final bool isChecked;

  ShoppingItem({
    String? id,
    required this.text,
    this.isChecked = false,
  }) : id = id ?? const Uuid().v4();

  /// Create a copy with modified fields
  ShoppingItem copyWith({
    String? id,
    String? text,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isChecked': isChecked,
    };
  }

  /// Create from JSON
  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
    );
  }
}

/// Represents a tracked POI location for a brand reminder
class TrackedLocation {
  final String poiId;
  final String poiName;
  final double latitude;
  final double longitude;

  TrackedLocation({
    required this.poiId,
    required this.poiName,
    required this.latitude,
    required this.longitude,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'poiId': poiId,
      'poiName': poiName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create from JSON
  factory TrackedLocation.fromJson(Map<String, dynamic> json) {
    return TrackedLocation(
      poiId: json['poiId'] as String,
      poiName: json['poiName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// Represents a shopping reminder for a brand
class Reminder {
  final String id;
  final String brandName;
  final List<TrackedLocation> locations;
  final String originalPoiId;
  final String originalPoiName;
  final POIType poiType;
  final double latitude;
  final double longitude;
  final List<ShoppingItem> items;
  final DateTime createdAt;

  Reminder({
    String? id,
    required this.brandName,
    List<TrackedLocation>? locations,
    String? originalPoiId,
    String? originalPoiName,
    required this.poiType,
    double? latitude,
    double? longitude,
    required this.items,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        locations = locations ?? [],
        originalPoiId = originalPoiId ??
            (locations != null && locations.isNotEmpty
                ? locations.first.poiId
                : ''),
        originalPoiName = originalPoiName ??
            (locations != null && locations.isNotEmpty
                ? locations.first.poiName
                : ''),
        latitude = latitude ??
            (locations != null && locations.isNotEmpty
                ? locations.first.latitude
                : 0.0),
        longitude = longitude ??
            (locations != null && locations.isNotEmpty
                ? locations.first.longitude
                : 0.0),
        createdAt = createdAt ?? DateTime.now();

  /// Check if all shopping items are checked
  bool get allItemsChecked {
    if (items.isEmpty) return false;
    return items.every((item) => item.isChecked);
  }

  /// Create a copy with modified fields
  Reminder copyWith({
    String? id,
    String? brandName,
    List<TrackedLocation>? locations,
    String? originalPoiId,
    String? originalPoiName,
    POIType? poiType,
    double? latitude,
    double? longitude,
    List<ShoppingItem>? items,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      brandName: brandName ?? this.brandName,
      locations: locations ?? this.locations,
      originalPoiId: originalPoiId ?? this.originalPoiId,
      originalPoiName: originalPoiName ?? this.originalPoiName,
      poiType: poiType ?? this.poiType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brandName': brandName,
      'locations': locations.map((loc) => loc.toJson()).toList(),
      'originalPoiId': originalPoiId,
      'originalPoiName': originalPoiName,
      'poiType': poiType.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      brandName: json['brandName'] as String,
      locations: json['locations'] != null
          ? (json['locations'] as List<dynamic>)
              .map((loc) =>
                  TrackedLocation.fromJson(loc as Map<String, dynamic>))
              .toList()
          : [],
      originalPoiId: json['originalPoiId'] as String,
      originalPoiName: json['originalPoiName'] as String,
      poiType: POIType.values.firstWhere(
        (type) => type.toString().split('.').last == json['poiType'],
        orElse: () => POIType.other,
      ),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      items: (json['items'] as List<dynamic>)
          .map((item) => ShoppingItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

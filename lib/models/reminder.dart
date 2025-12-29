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

/// Represents a shopping reminder for a brand
class Reminder {
  final String id;
  final String brandName;
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
    required this.originalPoiId,
    required this.originalPoiName,
    required this.poiType,
    required this.latitude,
    required this.longitude,
    required this.items,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
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

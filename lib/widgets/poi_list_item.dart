import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';

/// Individual POI list item widget
///
/// Displays a single POI with:
/// - Type icon on the left
/// - POI name (bold)
/// - Distance from city (gray text)
/// - Right chevron for navigation
class POIListItem extends StatelessWidget {
  final POI poi;
  final VoidCallback? onTap;

  const POIListItem({super.key, required this.poi, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${poi.name}, ${poi.type.displayName}, ${_formatDistance(poi.distanceFromCity)} away',
      hint: 'Tap to view details',
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getTypeColor(poi.type),
            child: Icon(_getTypeIcon(poi.type), color: Colors.white, size: 20),
          ),
          title: Text(
            poi.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDistance(poi.distanceFromCity),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  poi.type.displayName,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  IconData _getTypeIcon(POIType type) {
    switch (type) {
      case POIType.museum:
        return Icons.museum;
      case POIType.monument:
        return Icons.account_balance;
      case POIType.landmark:
        return Icons.place;
      case POIType.park:
        return Icons.park;
      case POIType.viewpoint:
        return Icons.landscape;
      case POIType.religiousSite:
        return Icons.church;
      case POIType.historicSite:
        return Icons.history_edu;
      case POIType.square:
        return Icons.grid_view;
      case POIType.touristAttraction:
        return Icons.star;
      case POIType.other:
        return Icons.location_city;
    }
  }

  Color _getTypeColor(POIType type) {
    switch (type) {
      case POIType.museum:
        return Colors.purple;
      case POIType.monument:
        return Colors.amber[700]!;
      case POIType.landmark:
        return Colors.red;
      case POIType.park:
        return Colors.green;
      case POIType.viewpoint:
        return Colors.blue;
      case POIType.religiousSite:
        return Colors.indigo;
      case POIType.historicSite:
        return Colors.brown;
      case POIType.square:
        return Colors.teal;
      case POIType.touristAttraction:
        return Colors.orange;
      case POIType.other:
        return Colors.grey;
    }
  }
}

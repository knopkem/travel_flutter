import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';
import '../providers/reminder_provider.dart';
import '../utils/brand_matcher.dart';

/// Individual POI list item widget
///
/// Displays a single POI with:
/// - Type icon on the left (with shopping cart badge if tagged)
/// - POI name (bold)
/// - Distance from city (gray text)
class POIListItem extends StatelessWidget {
  final POI poi;
  final VoidCallback? onTap;

  const POIListItem({
    super.key,
    required this.poi,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, reminderProvider, child) {
        final brandName = BrandMatcher.extractBrand(poi.name);
        final hasReminder = brandName != null &&
            reminderProvider.hasReminderForBrand(brandName);

        return Semantics(
          label:
              '${poi.name}, ${poi.type.displayName}, ${_formatDistance(poi.distanceFromCity)} away',
          hint: 'Tap to view details',
          button: true,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: _getTypeColor(poi.type),
                    child: Icon(_getTypeIcon(poi.type),
                        color: Colors.white, size: 20),
                  ),
                  if (hasReminder)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                poi.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              onTap: onTap,
            ),
          ),
        );
      },
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
      case POIType.park:
        return Icons.park;
      case POIType.viewpoint:
        return Icons.landscape;
      case POIType.religiousSite:
        return Icons.church;
      case POIType.historicSite:
        return Icons.history_edu;
      case POIType.touristAttraction:
        return Icons.star;
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
        return Icons.location_city;
    }
  }

  Color _getTypeColor(POIType type) {
    switch (type) {
      case POIType.museum:
        return Colors.purple;
      case POIType.monument:
        return Colors.amber[700]!;
      case POIType.park:
        return Colors.green;
      case POIType.viewpoint:
        return Colors.blue;
      case POIType.religiousSite:
        return Colors.indigo;
      case POIType.historicSite:
        return Colors.brown;
      case POIType.touristAttraction:
        return Colors.orange;
      case POIType.restaurant:
        return Colors.red;
      case POIType.cafe:
        return Colors.brown[300]!;
      case POIType.bakery:
        return Colors.orange[300]!;
      case POIType.supermarket:
        return Colors.blue[700]!;
      case POIType.hardwareStore:
        return Colors.deepOrange;
      case POIType.pharmacy:
        return Colors.green[700]!;
      case POIType.gasStation:
        return Colors.yellow[700]!;
      case POIType.hotel:
        return Colors.indigo[300]!;
      case POIType.bar:
        return Colors.purple[700]!;
      case POIType.fastFood:
        return Colors.red[700]!;
      case POIType.other:
        return Colors.grey;
    }
  }
}

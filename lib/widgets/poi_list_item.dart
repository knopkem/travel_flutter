import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../providers/reminder_provider.dart';
import '../utils/brand_matcher.dart';
import '../utils/format_utils.dart';

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
              '${poi.name}, ${poi.type.displayName}, ${formatDistance(poi.distanceFromCity)} away',
          hint: 'Tap to view details',
          button: true,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: poi.type.color,
                    child: Icon(poi.type.icon, color: Colors.white, size: 20),
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
                    formatDistance(poi.distanceFromCity),
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
}

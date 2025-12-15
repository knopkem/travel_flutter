import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../screens/location_detail_screen.dart';

/// Displays selected locations as interactive cards.
///
/// This widget shows all locations the user has selected during
/// the current session. Each location is displayed as a card with:
/// - Location name and coordinates
/// - Remove button to unselect
/// - Tap gesture to view details
///
/// The list automatically updates when locations are added or removed
/// via the [LocationProvider].
///
/// Features:
/// - Scrollable list of location cards
/// - Remove button (X icon) on each card
/// - Tap to navigate to detail screen
/// - Shows coordinates for reference
/// - Empty state message when no selections
///
/// Example:
/// ```dart
/// Consumer<LocationProvider>(
///   builder: (context, provider, child) {
///     if (provider.selectedLocations.isNotEmpty) {
///       return const SelectedLocationsList();
///     }
///     return const SizedBox.shrink();
///   },
/// )
/// ```
class SelectedLocationsList extends StatelessWidget {
  const SelectedLocationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, child) {
        if (provider.selectedLocations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No locations selected',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Search and select locations to view their information',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.selectedLocations.length,
          itemBuilder: (context, index) {
            final location = provider.selectedLocations[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.place, color: Colors.blue, size: 32),
                title: Text(
                  location.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${location.name}, ${location.country}\n'
                  'Lat: ${location.latitude.toStringAsFixed(4)}, '
                  'Lon: ${location.longitude.toStringAsFixed(4)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Remove location',
                  onPressed: () {
                    provider.removeLocation(location.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed ${location.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LocationDetailScreen(location: location),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

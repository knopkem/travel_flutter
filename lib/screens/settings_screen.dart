import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi_type.dart';
import '../providers/settings_provider.dart';

/// Settings screen for customizing app preferences
///
/// Currently supports:
/// - POI Type Interests: Drag-and-drop ranking of POI types
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (settingsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              _buildInterestsSection(context, settingsProvider),
              _buildDistanceSection(context, settingsProvider),
              // Future sections can be added here
              // _buildAppearanceSection(context, settingsProvider),
              // _buildPrivacySection(context, settingsProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInterestsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.favorite_border),
      title: const Text(
        'Interests',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('Customize your POI preferences'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drag to reorder by preference',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                    onPressed: () => _showResetDialog(context, settingsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPoiTypeList(context, settingsProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPoiTypeList(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final poiOrder = settingsProvider.poiTypeOrder;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: poiOrder.length,
      onReorder: (oldIndex, newIndex) {
        final updatedOrder = List<POIType>.from(poiOrder);
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = updatedOrder.removeAt(oldIndex);
        updatedOrder.insert(newIndex, item);
        settingsProvider.updatePoiOrder(updatedOrder);
      },
      itemBuilder: (context, index) {
        final type = poiOrder[index];
        return _buildPoiTypeItem(context, type, index + 1, key: ValueKey(type));
      },
    );
  }

  Widget _buildPoiTypeItem(
    BuildContext context,
    POIType type,
    int rank, {
    required Key key,
  }) {
    return Card(
      key: key,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Row(
          children: [
            Icon(
              _getTypeIcon(type),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              _getTypeName(type),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.drag_handle,
          color: Colors.grey[400],
        ),
      ),
    );
  }
Widget _buildDistanceSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final distanceKm = (settingsProvider.poiSearchDistance / 1000).round();
    
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.near_me),
      title: const Text(
        'Search Distance',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('Current: $distanceKm km'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_searching, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'POI Search Radius: $distanceKm km',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('1 km'),
                  Expanded(
                    child: Slider(
                      value: settingsProvider.poiSearchDistance.toDouble(),
                      min: 1000,
                      max: 10000,
                      divisions: 9,
                      label: '$distanceKm km',
                      onChanged: (value) {
                        settingsProvider.updatePoiDistance(value.round());
                      },
                    ),
                  ),
                  const Text('10 km'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Larger distances may take longer to fetch results',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  
  void _showResetDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will restore the default POI type ordering. Your custom preferences will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settingsProvider.resetPoiOrder();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(POIType type) {
    switch (type) {
      case POIType.monument:
        return Icons.account_balance;
      case POIType.museum:
        return Icons.museum;
      case POIType.landmark:
        return Icons.location_city;
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
      case POIType.square:
        return Icons.location_on;
      case POIType.other:
        return Icons.place;
    }
  }

  String _getTypeName(POIType type) {
    switch (type) {
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

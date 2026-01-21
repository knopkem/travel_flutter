import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poi_category.dart';
import '../../models/poi_type.dart';
import '../../models/poi_source.dart';
import '../../providers/settings_provider.dart';

/// Settings screen for POI Discovery configuration
/// Includes: Data Sources, POI Types, Interests, and Search Distance
class PoiDiscoverySettingsScreen extends StatelessWidget {
  const PoiDiscoverySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POI Discovery'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (settingsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _buildProvidersSection(context, settingsProvider),
              const Divider(height: 1),
              _buildAttractionTypesSection(context, settingsProvider),
              const Divider(height: 1),
              _buildCommercialTypesSection(context, settingsProvider),
              const Divider(height: 1),
              _buildAttractionInterestsSection(context, settingsProvider),
              const Divider(height: 1),
              _buildCommercialInterestsSection(context, settingsProvider),
              const Divider(height: 1),
              _buildDistanceSection(context, settingsProvider),
              const Divider(height: 1),
              _buildClusterRadiusSection(context, settingsProvider),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _showDisableAllProvidersDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable POI Discovery?'),
        content: const Text(
          'You are about to disable all POI data sources. This will prevent the app from discovering points of interest near locations.\n\nYou can re-enable sources at any time in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Disable All'),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final enabledCount = settingsProvider.enabledPoiSources.length;
    final totalCount = POISource.values.length;

    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.cloud_sync),
      title: const Text(
        'POI Data Sources',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('$enabledCount of $totalCount sources enabled'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settingsProvider.allProvidersDisabled)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[900], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All data sources are disabled. POI discovery is inactive.',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Enable or disable POI data sources',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 12),
              ...POISource.values.map((source) {
                final isEnabled = settingsProvider.isProviderEnabled(source);
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: SwitchListTile(
                    value: isEnabled,
                    onChanged: (source.requiresApiKey &&
                            !settingsProvider.hasValidGooglePlacesKey)
                        ? null
                        : (value) async {
                            if (!value && enabledCount == 1 && isEnabled) {
                              final confirmed =
                                  await _showDisableAllProvidersDialog(context);
                              if (confirmed == true) {
                                await settingsProvider.updateProviderEnabled(
                                    source, value);
                              }
                            } else {
                              await settingsProvider.updateProviderEnabled(
                                  source, value);
                            }
                          },
                    title: Row(
                      children: [
                        Icon(
                          source.icon,
                          size: 20,
                          color: isEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          source.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isEnabled ? null : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (source.requiresApiKey &&
                            !settingsProvider.hasValidGooglePlacesKey)
                          Text(
                            'Configure API key in API Keys settings to enable',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Use Local Content'),
                subtitle: Text(
                  'Fetch content in the location\'s language (e.g., German for German cities)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                value: settingsProvider.useLocalContent,
                onChanged: (value) {
                  settingsProvider.updateUseLocalContent(value);
                },
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Default POI Category'),
                subtitle: Text(
                  'Choose which category of points of interest to show by default',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              RadioListTile<POICategory>(
                title: const Text('Attractions'),
                subtitle: const Text('Museums, monuments, viewpoints'),
                value: POICategory.attraction,
                groupValue: settingsProvider.defaultPoiCategory,
                onChanged: (POICategory? value) {
                  if (value != null) {
                    settingsProvider.updateDefaultPoiCategory(value);
                  }
                },
              ),
              RadioListTile<POICategory>(
                title: const Text('Commercial'),
                subtitle: const Text('Restaurants, shops, services'),
                value: POICategory.commercial,
                groupValue: settingsProvider.defaultPoiCategory,
                onChanged: (POICategory? value) {
                  if (value != null) {
                    settingsProvider.updateDefaultPoiCategory(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset All'),
                    onPressed: () async {
                      await settingsProvider.resetPoiProviders();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All POI sources enabled'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttractionTypesSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final poiOrder = settingsProvider.attractionPoiOrder;
    final enabledCount = poiOrder.where((entry) => entry.$2).length;
    final totalCount = poiOrder.length;

    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.attractions),
      title: const Text(
        'Attraction Types',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('$enabledCount of $totalCount types enabled'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settingsProvider.allAttractionPoiTypesDisabled)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'At least one attraction type must be enabled for discovery.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'Museums, monuments, parks, and tourist sites',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ...poiOrder.map((entry) {
                final type = entry.$1;
                final enabled = entry.$2;
                return CheckboxListTile(
                  value: enabled,
                  onChanged: (value) {
                    if (value != null) {
                      settingsProvider.updateAttractionPoiTypeEnabled(
                          type, value);
                    }
                  },
                  title: Text(type.displayName),
                  secondary: Icon(type.icon),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await settingsProvider.resetAttractionPoiOrder();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All attraction types enabled'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Enable All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommercialTypesSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final poiOrder = settingsProvider.commercialPoiOrder;
    final enabledCount = poiOrder.where((entry) => entry.$2).length;
    final totalCount = poiOrder.length;

    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.store),
      title: const Text(
        'Commercial Types',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('$enabledCount of $totalCount types enabled'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settingsProvider.allCommercialPoiTypesDisabled)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'At least one commercial type must be enabled for discovery.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'Restaurants, cafés, supermarkets, and services',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ...poiOrder.map((entry) {
                final type = entry.$1;
                final enabled = entry.$2;
                return CheckboxListTile(
                  value: enabled,
                  onChanged: (value) {
                    if (value != null) {
                      settingsProvider.updateCommercialPoiTypeEnabled(
                          type, value);
                    }
                  },
                  title: Text(type.displayName),
                  secondary: Icon(type.icon),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await settingsProvider.resetCommercialPoiOrder();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All commercial types enabled'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Enable All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttractionInterestsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.star),
      title: const Text(
        'Attraction Interests',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('Rank your attraction preferences'),
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
                    onPressed: () => _showResetAttractionInterestsDialog(
                        context, settingsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AttractionPoiTypeList(settingsProvider: settingsProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommercialInterestsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.favorite),
      title: const Text(
        'Commercial Interests',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('Rank your commercial preferences'),
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
                    onPressed: () => _showResetCommercialInterestsDialog(
                        context, settingsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CommercialPoiTypeList(settingsProvider: settingsProvider),
            ],
          ),
        ),
      ],
    );
  }

  void _showResetAttractionInterestsDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Attraction Interests?'),
        content: const Text(
          'This will restore the default attraction interest ordering. Your custom preferences will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settingsProvider.resetAttractionPoiOrder();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attraction interests reset to defaults'),
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

  void _showResetCommercialInterestsDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Commercial Interests?'),
        content: const Text(
          'This will restore the default commercial interest ordering. Your custom preferences will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settingsProvider.resetCommercialPoiOrder();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Commercial interests reset to defaults'),
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

  Widget _buildDistanceSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final distanceKm = (settingsProvider.poiSearchDistance / 1000).round();

    return ExpansionTile(
      initiallyExpanded: false,
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
                      max: 50000,
                      divisions: 49,
                      label: '$distanceKm km',
                      onChanged: (value) {
                        settingsProvider.updatePoiDistance(value.round());
                      },
                    ),
                  ),
                  const Text('50 km'),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClusterRadiusSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final radiusMeters = settingsProvider.clusterRadiusMeters.clamp(200, 2000);

    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.workspaces_outlined),
      title: const Text(
        'Map Clustering',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('Cluster radius: $radiusMeters m'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_work, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cluster Radius: $radiusMeters meters',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('200 m'),
                  Expanded(
                    child: Slider(
                      value: radiusMeters.toDouble(),
                      min: 200,
                      max: 2000,
                      divisions: 18,
                      label: '$radiusMeters m',
                      onChanged: (value) {
                        settingsProvider
                            .updateClusterRadiusMeters(value.round());
                      },
                    ),
                  ),
                  const Text('2 km'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'POIs of the same type within this distance will be grouped together when zoomed out on the map',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttractionPoiTypeList extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _AttractionPoiTypeList({required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    final poiOrder = settingsProvider.attractionPoiOrder;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: poiOrder.length,
      onReorder: (oldIndex, newIndex) {
        final updatedOrder = List<(POIType, bool)>.from(poiOrder);
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = updatedOrder.removeAt(oldIndex);
        updatedOrder.insert(newIndex, item);
        settingsProvider.updateAttractionPoiOrder(updatedOrder);
      },
      itemBuilder: (context, index) {
        final entry = poiOrder[index];
        return _PoiTypeItem(
          key: ValueKey(entry.$1),
          type: entry.$1,
          rank: index + 1,
          index: index,
        );
      },
    );
  }
}

class _CommercialPoiTypeList extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const _CommercialPoiTypeList({required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    final poiOrder = settingsProvider.commercialPoiOrder;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: poiOrder.length,
      onReorder: (oldIndex, newIndex) {
        final updatedOrder = List<(POIType, bool)>.from(poiOrder);
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = updatedOrder.removeAt(oldIndex);
        updatedOrder.insert(newIndex, item);
        settingsProvider.updateCommercialPoiOrder(updatedOrder);
      },
      itemBuilder: (context, index) {
        final entry = poiOrder[index];
        return _PoiTypeItem(
          key: ValueKey(entry.$1),
          type: entry.$1,
          rank: index + 1,
          index: index,
        );
      },
    );
  }
}

class _PoiTypeItem extends StatelessWidget {
  final POIType type;
  final int rank;
  final int index;

  const _PoiTypeItem({
    required super.key,
    required this.type,
    required this.rank,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              type.icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              type.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

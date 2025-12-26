import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';
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
              _buildAIGuidanceSection(context, settingsProvider),
              _buildProvidersSection(context, settingsProvider),
              _buildPoiTypesSection(context, settingsProvider),
              _buildInterestsSection(context, settingsProvider),
              _buildDistanceSection(context, settingsProvider),
              _buildAboutSection(context),
            ],
          );
        },
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
                    onChanged: (value) async {
                      // Check if this is the last enabled provider being turned off
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
                          _getProviderIcon(source),
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
                    subtitle: Text(
                      _getProviderDescription(source),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
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

  Widget _buildPoiTypesSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final poiOrder = settingsProvider.poiTypeOrder;
    final enabledCount = poiOrder.where((entry) => entry.$2).length;
    final totalCount = poiOrder.length;

    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.category),
      title: const Text(
        'POI Types',
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
              if (settingsProvider.allPoiTypesDisabled)
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
                          'At least one POI type must be enabled for discovery to work.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'Enable or disable specific POI types',
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
                      settingsProvider.updatePoiTypeEnabled(type, value);
                    }
                  },
                  title: Text(type.displayName),
                  secondary: Icon(_getTypeIcon(type)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await settingsProvider.resetPoiOrder();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All POI types enabled'),
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

  Widget _buildAIGuidanceSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return _AIGuidanceSettings(settingsProvider: settingsProvider);
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
                    onPressed: () =>
                        _showResetDialog(context, settingsProvider),
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
      buildDefaultDragHandles: false, // Disable default drag handles
      itemCount: poiOrder.length,
      onReorder: (oldIndex, newIndex) {
        final updatedOrder = List<(POIType, bool)>.from(poiOrder);
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = updatedOrder.removeAt(oldIndex);
        updatedOrder.insert(newIndex, item);
        settingsProvider.updatePoiOrder(updatedOrder);
      },
      itemBuilder: (context, index) {
        final entry = poiOrder[index];
        return _buildPoiTypeItem(context, entry.$1, index + 1, index,
            key: ValueKey(entry.$1));
      },
    );
  }

  Widget _buildPoiTypeItem(
    BuildContext context,
    POIType type,
    int rank,
    int index, {
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
    }
  }

  IconData _getProviderIcon(POISource source) {
    switch (source) {
      case POISource.wikipediaGeosearch:
        return Icons.article;
      case POISource.overpass:
        return Icons.map;
      case POISource.wikidata:
        return Icons.storage;
    }
  }

  String _getProviderDescription(POISource source) {
    switch (source) {
      case POISource.wikipediaGeosearch:
        return 'Articles about notable places';
      case POISource.overpass:
        return 'Tourist attractions from OpenStreetMap';
      case POISource.wikidata:
        return 'Structured knowledge base';
    }
  }

  Widget _buildAboutSection(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.info_outline),
      title: const Text(
        'About',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('App info, licenses & attributions'),
      children: [
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: const Text('LocationPal'),
          subtitle: const Text('Version 1.0.0'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Open Source Licenses'),
          subtitle: const Text('View third-party software licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'LocationPal',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 LocationPal',
            );
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Attributions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildAttributionItem(
                context,
                'Wikipedia',
                'Content licensed under CC BY-SA 3.0',
                'https://wikipedia.org',
              ),
              const SizedBox(height: 8),
              _buildAttributionItem(
                context,
                'OpenStreetMap',
                'Map data © OpenStreetMap contributors, ODbL',
                'https://openstreetmap.org',
              ),
              const SizedBox(height: 8),
              _buildAttributionItem(
                context,
                'Wikidata',
                'Data available under CC0 1.0',
                'https://wikidata.org',
              ),
              const SizedBox(height: 8),
              _buildAttributionItem(
                context,
                'Nominatim',
                'Geocoding service by OpenStreetMap',
                'https://nominatim.org',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttributionItem(
    BuildContext context,
    String name,
    String description,
    String url,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AIGuidanceSettings extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const _AIGuidanceSettings({required this.settingsProvider});

  @override
  State<_AIGuidanceSettings> createState() => _AIGuidanceSettingsState();
}

class _AIGuidanceSettingsState extends State<_AIGuidanceSettings> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isValidating = false;
  String? _validationMessage;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    // Check if key exists on init
    _isValid = widget.settingsProvider.hasValidOpenAIKey;
    if (_isValid) {
      _validationMessage = 'API key configured';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter an API key';
        _isValid = false;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationMessage = null;
    });

    try {
      await widget.settingsProvider.updateOpenAIApiKey(apiKey);
      setState(() {
        _isValid = true;
        _validationMessage = 'API key validated and saved';
        _apiKeyController.clear();
      });
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMessage = 'Invalid API key: $e';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _removeKey() async {
    await widget.settingsProvider.removeOpenAIApiKey();
    setState(() {
      _isValid = false;
      _validationMessage = null;
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      leading: Icon(
        Icons.auto_awesome,
        color: _isValid ? Colors.green : null,
      ),
      title: const Text(
        'AI Guidance',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(_isValid
          ? 'API key configured - Filter POIs with AI'
          : 'Configure OpenAI API key for semantic filtering'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Use AI to filter attractions by themes like "romantic", "kid-friendly", or "historical".',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Model:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _OpenAIModels.models.any((m) =>
                              m.id == widget.settingsProvider.openaiModel)
                          ? widget.settingsProvider.openaiModel
                          : 'gpt-4o-mini',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _OpenAIModels.models.map((model) {
                        return DropdownMenuItem(
                          value: model.id,
                          child: Text('${model.name} ${model.priceIndicator}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          // Defer the update to avoid rebuilding during onChange
                          Future.microtask(() {
                            widget.settingsProvider.updateOpenAIModel(value);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Batch Size:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: [25, 50, 100, 150, 500, 1000]
                              .contains(widget.settingsProvider.aiBatchSize)
                          ? widget.settingsProvider.aiBatchSize
                          : 500,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 25, child: Text('25 (fastest)')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                        DropdownMenuItem(value: 150, child: Text('150')),
                        DropdownMenuItem(value: 500, child: Text('500')),
                        DropdownMenuItem(
                            value: 1000, child: Text('1000 (slowest)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          Future.microtask(() {
                            widget.settingsProvider.updateAIBatchSize(value);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'POIs per API request. Smaller = faster but more requests.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              if (_isValid)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationMessage ?? 'API key configured',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI API Key',
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                if (_validationMessage != null)
                  Card(
                    color: _isValid ? Colors.green.shade50 : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(
                            _isValid ? Icons.check_circle : Icons.error,
                            color: _isValid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationMessage!,
                              style: TextStyle(
                                color: _isValid
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (_isValid)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _removeKey,
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isValidating ? null : _validateAndSave,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isValidating ? 'Validating...' : 'Validate & Save',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Get your API key from platform.openai.com • 50 requests/day limit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// OpenAI model information
class _OpenAIModelInfo {
  final String id;
  final String name;
  final String priceIndicator;

  const _OpenAIModelInfo({
    required this.id,
    required this.name,
    required this.priceIndicator,
  });
}

/// Available OpenAI models with pricing
class _OpenAIModels {
  static const List<_OpenAIModelInfo> models = [
    _OpenAIModelInfo(
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      priceIndicator: r'$',
    ),
    _OpenAIModelInfo(
      id: 'gpt-4o',
      name: 'GPT-4o',
      priceIndicator: r'$$',
    ),
    _OpenAIModelInfo(
      id: 'gpt-4-turbo',
      name: 'GPT-4 Turbo',
      priceIndicator: r'$$$',
    ),
    _OpenAIModelInfo(
      id: 'gpt-3.5-turbo',
      name: 'GPT-3.5 Turbo',
      priceIndicator: r'$',
    ),
    _OpenAIModelInfo(
      id: 'o1-mini',
      name: 'O1 Mini',
      priceIndicator: r'$$',
    ),
    _OpenAIModelInfo(
      id: 'o1',
      name: 'O1',
      priceIndicator: r'$$$$',
    ),
  ];
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi_category.dart';
import '../models/poi_type.dart';
import '../models/poi_source.dart';
import '../models/poi.dart';
import '../providers/settings_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/location_provider.dart';
import '../services/location_monitor_service.dart';
import '../services/notification_service.dart';
import '../services/geofence_strategy_manager.dart';
import '../utils/permission_dialog_helper.dart';
import '../utils/battery_optimization_helper.dart';
import 'reminders_overview_screen.dart';

/// Settings screen for customizing app preferences
///
/// Currently supports:
/// - POI Type Interests: Drag-and-drop ranking of POI types
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = 'Loading...';
  bool _isTogglingBackgroundLocation = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                  _buildGooglePlacesSection(context, settingsProvider),
                  _buildProvidersSection(context, settingsProvider),
                  _buildRemindersSection(context, settingsProvider),
                  _buildPoiTypesSection(context, settingsProvider),
                  _buildInterestsSection(context, settingsProvider),
                  _buildDistanceSection(context, settingsProvider),
                  _buildAboutSection(context),
                ],
              );
            },
          ),
        ),
        // Loading overlay when toggling background location
        if (_isTogglingBackgroundLocation)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Updating background location service...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProvidersSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final enabledCount = settingsProvider.enabledPoiSources.length;
    final totalCount = POISource.values.length;

    return ExpansionTile(
      initiallyExpanded: false,
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
                            'Configure API key below to enable',
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

  Widget _buildRemindersSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return Consumer<ReminderProvider>(
      builder: (context, reminderProvider, child) {
        final hasReminders = reminderProvider.hasReminders;

        return ExpansionTile(
          initiallyExpanded: hasReminders,
          leading: const Icon(Icons.shopping_cart),
          title: const Text(
            'Shopping Reminders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: hasReminders
              ? Text('${reminderProvider.reminders.length} active reminders')
              : const Text('No active reminders'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasReminders) ...[
                    SwitchListTile(
                      title: const Text('Background Location'),
                      subtitle: Text(
                        'Check your location periodically to send reminders when near tagged stores',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: settingsProvider.backgroundLocationEnabled,
                      onChanged: _isTogglingBackgroundLocation
                          ? null
                          : (value) async {
                              setState(() {
                                _isTogglingBackgroundLocation = true;
                              });

                              try {
                                await settingsProvider
                                    .updateBackgroundLocationEnabled(value);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? 'Background location enabled'
                                            : 'Background location disabled',
                                      ),
                                      backgroundColor:
                                          value ? Colors.green : null,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isTogglingBackgroundLocation = false;
                                  });
                                }
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Dwell Time'),
                      subtitle: Text(
                        'Time to stay near a location before notification',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: DropdownButton<int>(
                        value: settingsProvider.dwellTimeMinutes,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 min')),
                          DropdownMenuItem(value: 2, child: Text('2 min')),
                          DropdownMenuItem(value: 3, child: Text('3 min')),
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 10, child: Text('10 min')),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            await settingsProvider
                                .updateDwellTimeMinutes(value);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Dwell time set to $value minutes'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Proximity Radius',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${settingsProvider.proximityRadiusMeters}m',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Distance from location to trigger notification',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: settingsProvider.proximityRadiusMeters
                                .toDouble(),
                            min: 50,
                            max: 500,
                            divisions: 9,
                            label: '${settingsProvider.proximityRadiusMeters}m',
                            onChanged: (value) async {
                              await settingsProvider
                                  .updateProximityRadiusMeters(value.round());
                            },
                            onChangeEnd: (value) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Proximity radius set to ${value.round()}m',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '50m',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '500m',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Geofence strategy status indicator
                    StreamBuilder<GeofenceStrategy>(
                      stream: GeofenceStrategyManager().strategyStream,
                      initialData: GeofenceStrategyManager().currentStrategy,
                      builder: (context, snapshot) {
                        final strategyManager = GeofenceStrategyManager();
                        final strategy =
                            snapshot.data ?? GeofenceStrategy.native;
                        final isNative = strategy == GeofenceStrategy.native;
                        final fallbackReason = strategyManager.fallbackReason;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isNative ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isNative
                                  ? Colors.green[200]!
                                  : Colors.orange[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isNative ? Icons.check_circle : Icons.info,
                                color: isNative
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Using: ${strategyManager.getStrategyDescription()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isNative
                                            ? Colors.green[900]
                                            : Colors.orange[900],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (!isNative &&
                                        fallbackReason != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Reason: $fallbackReason',
                                        style: TextStyle(
                                          color: Colors.orange[800],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Battery optimization status card
                    FutureBuilder<bool>(
                      future: BatteryOptimizationHelper
                          .isIgnoringBatteryOptimizations(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final isOptimized = !snapshot.data!;
                        if (!isOptimized) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.battery_alert,
                                    color: Colors.orange[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Battery Optimization Active',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Battery optimization may prevent location reminders from working reliably in the background. Tap below to disable it for this app.',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.settings, size: 18),
                                  label: const Text('Fix Battery Settings'),
                                  onPressed: () async {
                                    final result =
                                        await BatteryOptimizationHelper
                                            .requestBatteryOptimizationExemption(
                                                context);
                                    if (result && context.mounted) {
                                      setState(() {}); // Refresh to hide banner
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Battery optimization disabled successfully',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('Manage Shopping Reminders'),
                      subtitle:
                          const Text('View and edit all your shopping lists'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RemindersOverviewScreen(),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Tag commercial POIs (stores, restaurants, etc.) with shopping lists. '
                        'You\'ll receive notifications when you\'re near any location of the tagged brand.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading:
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                      title: const Text('How to create a reminder'),
                      subtitle: const Text(
                        '1. Find a commercial POI (e.g., supermarket)\n'
                        '2. Tap to view details\n'
                        '3. Tap "Add Shopping Reminder"\n'
                        '4. Add items to your list',
                      ),
                      dense: true,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.bug_report, color: Colors.orange),
                    title: const Text('Test Background Monitoring'),
                    subtitle: const Text(
                        'Create a test reminder at your current location'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _createTestReminder(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Create a test reminder at the current GPS location for debugging background monitoring
  Future<void> _createTestReminder(BuildContext context) async {
    final reminderProvider =
        Provider.of<ReminderProvider>(context, listen: false);
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Check if this is the first reminder
    final isFirstReminder = !reminderProvider.hasReminders;

    if (isFirstReminder) {
      final permissionsGranted = await _requestAllPermissions(context);
      if (!permissionsGranted) return;
    }

    if (!mounted) return;

    // Try to use the currently selected city location first (to match displayed location)
    double latitude;
    double longitude;

    if (locationProvider.selectedCity != null) {
      // Use the selected city coordinates (may be rounded for GPS locations)
      latitude = locationProvider.selectedCity!.latitude;
      longitude = locationProvider.selectedCity!.longitude;
      debugPrint('Using selected city location: $latitude, $longitude');
    } else {
      // Fall back to fetching current GPS position
      Position? position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Getting location...'),
            duration: Duration(seconds: 2),
          ),
        );

        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to get location: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      latitude = position.latitude;
      longitude = position.longitude;
      debugPrint('Using fresh GPS position: $latitude, $longitude');
    }

    if (!mounted) return;

    // Create a test POI at current location
    final testPoi = POI(
      id: 'test_poi_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Test Location',
      type: POIType.supermarket,
      latitude: latitude,
      longitude: longitude,
      distanceFromCity: 0,
      sources: [POISource.googlePlaces],
      notabilityScore: 50,
      discoveredAt: DateTime.now(),
      description:
          'Test POI for background monitoring at coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    );

    // Default shopping items for testing
    final testItems = [
      'Test Item 1',
      'Test Item 2',
      'Check notification works',
    ];

    // Create the reminder
    final success =
        await reminderProvider.addReminderForTestPoi(testPoi, testItems);
    if (!mounted) return;

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Test reminder created at ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Enable background location monitoring in settings
      if (isFirstReminder) {
        await settingsProvider.updateBackgroundLocationEnabled(true);

        // Request battery optimization exemption on Android
        if (!mounted) return;
        await BatteryOptimizationHelper.requestBatteryOptimizationExemption(
            context);
      }
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content:
              Text(reminderProvider.error ?? 'Failed to create test reminder'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Request all permissions required for reminders
  Future<bool> _requestAllPermissions(BuildContext context) async {
    if (!mounted) return false;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final locationService = LocationMonitorService();

    // Step 1: Check and request foreground location permission
    bool foregroundGranted = await locationService.hasPermission();
    if (!mounted) return false;

    if (!foregroundGranted) {
      final allowedForeground =
          await PermissionDialogHelper.showForegroundLocationRationale(context);
      if (!allowedForeground) return false;

      foregroundGranted = await locationService.requestForegroundPermission();
      if (!mounted) return false;

      if (!foregroundGranted) {
        PermissionDialogHelper.showErrorWithMessenger(
          scaffoldMessenger,
          'Location permission is required for reminders.',
        );
        return false;
      }
    }

    // Step 2: Check and request background location permission
    bool backgroundGranted = await locationService.hasBackgroundPermission();
    if (!mounted) return false;

    if (!backgroundGranted) {
      final allowedBg =
          await PermissionDialogHelper.showBackgroundLocationRationale(context);
      if (!allowedBg) return false;

      backgroundGranted = await locationService.requestBackgroundPermission();
      if (!mounted) return false;

      if (!backgroundGranted) {
        PermissionDialogHelper.showErrorWithMessenger(
          scaffoldMessenger,
          'Background location permission is required for reminders. Please select "Allow all the time" in the permission dialog.',
        );
        return false;
      }
    }

    // Step 3: Check and request notification permission
    final notificationService = NotificationService();

    final allowedNotif =
        await PermissionDialogHelper.showNotificationRationale(context);
    if (!allowedNotif) return false;

    final notifGranted = await notificationService.requestPermission();
    if (!mounted) return false;

    if (!notifGranted) {
      PermissionDialogHelper.showErrorWithMessenger(
        scaffoldMessenger,
        'Notification permission is required for reminders',
      );
      return false;
    }

    return true;
  }

  Widget _buildPoiTypesSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return Column(
      children: [
        _buildAttractionTypesSection(context, settingsProvider),
        _buildCommercialTypesSection(context, settingsProvider),
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

  Widget _buildAIGuidanceSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return _AIGuidanceSettings(settingsProvider: settingsProvider);
  }

  Widget _buildGooglePlacesSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return _GooglePlacesSettings(settingsProvider: settingsProvider);
  }

  Widget _buildInterestsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return Column(
      children: [
        _buildAttractionInterestsSection(context, settingsProvider),
        _buildCommercialInterestsSection(context, settingsProvider),
      ],
    );
  }

  Widget _buildAttractionInterestsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return ExpansionTile(
      initiallyExpanded: false,
      leading: const Icon(Icons.attractions),
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
              _buildAttractionPoiTypeList(context, settingsProvider),
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
      leading: const Icon(Icons.store),
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
              _buildCommercialPoiTypeList(context, settingsProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttractionPoiTypeList(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
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
        return _buildPoiTypeItem(context, entry.$1, index + 1, index,
            key: ValueKey(entry.$1));
      },
    );
  }

  Widget _buildCommercialPoiTypeList(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
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
          subtitle: Text('Version $_version'),
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
              applicationVersion: _version,
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
      final isValid = await widget.settingsProvider.updateOpenAIApiKey(apiKey);
      if (isValid) {
        setState(() {
          _isValid = true;
          _validationMessage = 'API key validated and saved';
          _apiKeyController.clear();
        });
      } else {
        setState(() {
          _isValid = false;
          _validationMessage =
              'Invalid API key. Please check your key and try again.';
        });
      }
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

class _GooglePlacesSettings extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const _GooglePlacesSettings({required this.settingsProvider});

  @override
  State<_GooglePlacesSettings> createState() => _GooglePlacesSettingsState();
}

class _GooglePlacesSettingsState extends State<_GooglePlacesSettings> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isValidating = false;
  String? _validationMessage;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _isValid = widget.settingsProvider.hasValidGooglePlacesKey;
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
      final isValid =
          await widget.settingsProvider.updateGooglePlacesApiKey(apiKey);
      if (isValid) {
        setState(() {
          _isValid = true;
          _validationMessage =
              'API key saved! Other POI providers have been auto-disabled (you can re-enable them if needed).';
          _apiKeyController.clear();
        });

        // Show snackbar for better visibility
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Google Places enabled. Other providers auto-disabled.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isValid = false;
          _validationMessage =
              'Invalid API key format. Keys should start with "AIza" and be 30-50 characters.';
        });
      }
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMessage = 'Validation error: $e';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _removeKey() async {
    await widget.settingsProvider.removeGooglePlacesApiKey();
    setState(() {
      _isValid = false;
      _validationMessage = null;
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestCount = widget.settingsProvider.googlePlacesRequestCount;

    return ExpansionTile(
      initiallyExpanded: false,
      leading: Icon(
        Icons.place,
        color: _isValid ? Colors.green : null,
      ),
      title: const Text(
        'Google Places',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(_isValid
          ? 'API key configured - Premium POI data'
          : 'Configure API key for rich place data'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Google Places provides rich POI data including ratings, reviews, and photos.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.paid, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a paid API. Google provides \$200/month free credit. Monitor usage in Google Cloud Console.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_isValid) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationMessage ?? 'API key configured',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Requests this month: $requestCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Google Places API Key',
                    hintText: 'AIza...',
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
                      'Get your API key from console.cloud.google.com and enable Places API',
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

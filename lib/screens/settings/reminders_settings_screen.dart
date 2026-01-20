import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/poi_type.dart';
import '../../models/poi_source.dart';
import '../../models/poi.dart';
import '../../providers/settings_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_monitor_service.dart';
import '../../services/notification_service.dart';
import '../../services/geofence_strategy_manager.dart';
import '../../utils/permission_dialog_helper.dart';
import '../../utils/battery_optimization_helper.dart';
import '../reminders_overview_screen.dart';

/// Settings screen for Shopping Reminders configuration
class RemindersSettingsScreen extends StatefulWidget {
  const RemindersSettingsScreen({super.key});

  @override
  State<RemindersSettingsScreen> createState() =>
      _RemindersSettingsScreenState();
}

class _RemindersSettingsScreenState extends State<RemindersSettingsScreen> {
  bool _isTogglingBackgroundLocation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      settingsProvider.refreshBackgroundLocationSetting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Shopping Reminders'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: Consumer2<SettingsProvider, ReminderProvider>(
            builder: (context, settingsProvider, reminderProvider, child) {
              final hasReminders = reminderProvider.hasReminders;

              return ListView(
                children: [
                  if (hasReminders) ...[
                    _buildActiveRemindersSection(
                        context, settingsProvider, reminderProvider),
                    const Divider(height: 1),
                    _buildLocationSettingsSection(context, settingsProvider),
                    const Divider(height: 1),
                    _buildGeofenceStatusSection(context),
                    const Divider(height: 1),
                  ] else ...[
                    _buildNoRemindersSection(context),
                    const Divider(height: 1),
                  ],
                  _buildTestSection(context),
                ],
              );
            },
          ),
        ),
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

  Widget _buildActiveRemindersSection(
    BuildContext context,
    SettingsProvider settingsProvider,
    ReminderProvider reminderProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, size: 24),
              const SizedBox(width: 12),
              Text(
                '${reminderProvider.reminders.length} Active Reminders',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Manage Shopping Reminders'),
            subtitle: const Text('View and edit all your shopping lists'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RemindersOverviewScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSettingsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 24),
              SizedBox(width: 12),
              Text(
                'Location Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: Text(
              'Show notifications when near stores with shopping reminders',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            value: settingsProvider.notificationsEnabled,
            onChanged: (value) async {
              await settingsProvider.updateNotificationsEnabled(value);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? 'Notifications enabled'
                          : 'Notifications disabled',
                    ),
                    backgroundColor: value ? Colors.green : null,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
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
                            backgroundColor: value ? Colors.green : null,
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
          const SizedBox(height: 16),
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
                  await settingsProvider.updateDwellTimeMinutes(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dwell time set to $value minutes'),
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
                  value: settingsProvider.proximityRadiusMeters.toDouble(),
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
        ],
      ),
    );
  }

  Widget _buildGeofenceStatusSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, size: 24),
              SizedBox(width: 12),
              Text(
                'System Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<GeofenceStrategy>(
            stream: GeofenceStrategyManager().strategyStream,
            initialData: GeofenceStrategyManager().currentStrategy,
            builder: (context, snapshot) {
              final strategyManager = GeofenceStrategyManager();
              final strategy = snapshot.data ?? GeofenceStrategy.native;
              final isNative = strategy == GeofenceStrategy.native;
              final fallbackReason = strategyManager.fallbackReason;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isNative ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isNative ? Colors.green[200]! : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isNative ? Icons.check_circle : Icons.info,
                      color: isNative ? Colors.green[700] : Colors.orange[700],
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
                          if (!isNative && fallbackReason != null) ...[
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
          FutureBuilder<bool>(
            future: BatteryOptimizationHelper.isIgnoringBatteryOptimizations(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final isOptimized = !snapshot.data!;
              if (!isOptimized) {
                return const SizedBox.shrink();
              }

              return Container(
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
                          final result = await BatteryOptimizationHelper
                              .requestBatteryOptimizationExemption(context);
                          if (result && context.mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
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
        ],
      ),
    );
  }

  Widget _buildNoRemindersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_cart, size: 24),
              SizedBox(width: 12),
              Text(
                'No Active Reminders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tag commercial POIs (stores, restaurants, etc.) with shopping lists. '
            'You\'ll receive notifications when you\'re near any location of the tagged brand.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blue[700]),
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
      ),
    );
  }

  Widget _buildTestSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 24, color: Colors.orange),
              SizedBox(width: 12),
              Text(
                'Testing & Debug',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.add_location, color: Colors.orange),
            title: const Text('Test Background Monitoring'),
            subtitle:
                const Text('Create a test reminder at your current location'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _createTestReminder(context),
          ),
        ],
      ),
    );
  }

  Future<void> _createTestReminder(BuildContext context) async {
    final reminderProvider =
        Provider.of<ReminderProvider>(context, listen: false);
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final isFirstReminder = !reminderProvider.hasReminders;

    if (isFirstReminder) {
      final permissionsGranted = await _requestAllPermissions(context);
      if (!permissionsGranted) return;
    }

    if (!mounted) return;

    double latitude;
    double longitude;

    if (locationProvider.selectedCity != null) {
      latitude = locationProvider.selectedCity!.latitude;
      longitude = locationProvider.selectedCity!.longitude;
      debugPrint('Using selected city location: $latitude, $longitude');
    } else {
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

    final testItems = [
      'Test Item 1',
      'Test Item 2',
      'Check notification works',
    ];

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

      if (isFirstReminder) {
        await settingsProvider.updateBackgroundLocationEnabled(true);

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

  Future<bool> _requestAllPermissions(BuildContext context) async {
    if (!mounted) return false;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final locationService = LocationMonitorService();

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
}

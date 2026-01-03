import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'providers/reminder_provider.dart';
import 'repositories/repositories.dart';
import 'screens/tab_navigation_screen.dart';
import 'screens/poi_detail_screen.dart';
import 'screens/reminders_overview_screen.dart';
import 'services/openai_service.dart';
import 'services/notification_service.dart';
import 'services/location_monitor_service.dart';
import 'services/dwell_time_tracker.dart';
import 'utils/settings_service.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global POI provider reference for deep linking
POIProvider? _poiProviderRef;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('=== App starting ===');

  // Initialize LocationMonitorService early to set up geofence handler
  // This ensures the method call handler is ready before any geofence events
  debugPrint('Initializing LocationMonitorService...');
  final locationMonitor = LocationMonitorService();
  debugPrint('LocationMonitorService initialized: $locationMonitor');

  // Clear stale dwell times from previous runs to ensure fresh state
  debugPrint('Clearing stale dwell times...');
  await DwellTimeTracker().clearAll();
  debugPrint('Dwell times cleared');

  // Initialize settings services
  final settingsService = SettingsService();
  final settingsProvider = SettingsProvider(settingsService: settingsService);
  await settingsProvider.initialize();

  // Initialize notification service with deep linking
  final notificationService = NotificationService();
  await notificationService.initialize(
    onNotificationTapped: (poiId) {
      // Navigate to POI detail screen using global navigator key
      debugPrint('Notification tapped for POI: $poiId');
      _handleNotificationTap(poiId);
    },
  );

  runApp(
    MultiProvider(
      providers: [
        // SettingsProvider must come first as it's used by other providers
        ChangeNotifierProvider.value(
          value: settingsProvider,
        ),
        ChangeNotifierProxyProvider<SettingsProvider, LocationProvider>(
          create: (context) {
            final settings = context.read<SettingsProvider>();
            return LocationProvider(
              GooglePlacesAutocompleteRepository(
                apiKey: settings.googlePlacesApiKey,
                onRequestMade: settings.incrementGooglePlacesRequestCount,
              ),
              NominatimGeocodingRepository(),
            );
          },
          update: (context, settings, locationProvider) {
            locationProvider?.updateGooglePlacesApiKey(
              settings.googlePlacesApiKey,
              onRequestMade: settings.incrementGooglePlacesRequestCount,
            );
            return locationProvider ??
                LocationProvider(
                  GooglePlacesAutocompleteRepository(
                    apiKey: settings.googlePlacesApiKey,
                    onRequestMade: settings.incrementGooglePlacesRequestCount,
                  ),
                  NominatimGeocodingRepository(),
                );
          },
        ),
        ChangeNotifierProvider(
          create: (_) => WikipediaProvider(
            RestWikipediaRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MapNavigationProvider(),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, POIProvider>(
          create: (context) {
            final settings = context.read<SettingsProvider>();
            return POIProvider(
              googlePlacesRepo: GooglePlacesRepository(
                apiKey: settings.googlePlacesApiKey,
                onRequestMade: settings.incrementGooglePlacesRequestCount,
              ),
            );
          },
          update: (_, settings, poiProvider) {
            poiProvider?.updateSettings(settings);
            return poiProvider ??
                POIProvider(
                  googlePlacesRepo: GooglePlacesRepository(
                    apiKey: settings.googlePlacesApiKey,
                    onRequestMade: settings.incrementGooglePlacesRequestCount,
                  ),
                );
          },
        ),
        ChangeNotifierProvider(
          create: (context) => AIGuidanceProvider(
            openaiService: OpenAIService(),
            settingsService: settingsService,
            settingsProvider: settingsProvider,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReminderProvider()..initialize(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Handle notification tap to navigate to POI detail screen or show reminder
void _handleNotificationTap(String payload) {
  // Wait a bit for app to be ready if launched from background
  Future.delayed(const Duration(milliseconds: 500), () async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('Navigator context not available for deep linking');
      return;
    }

    // Try to get the reminder by ID first (for geofence notifications)
    final reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
    final reminders = reminderProvider.reminders;
    final reminder = reminders.where((r) => r.id == payload).firstOrNull;
    
    if (reminder != null) {
      // Found a reminder - show dialog with shopping list
      debugPrint('Showing shopping list for reminder: ${reminder.brandName}');
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Shopping List - ${reminder.brandName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re near ${reminder.brandName}!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (reminder.items.isEmpty)
                  const Text('No items in shopping list')
                else
                  ...reminder.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.text)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CLOSE'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navigate to reminders screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RemindersOverviewScreen(),
                  ),
                );
              },
              child: const Text('VIEW ALL REMINDERS'),
            ),
          ],
        ),
      );
      return;
    }

    // Fallback: try to find POI by ID (for legacy notifications)
    if (_poiProviderRef == null) {
      debugPrint('POI provider not available for deep linking');
      return;
    }

    final poi = _poiProviderRef!.findById(payload);
    if (poi == null) {
      debugPrint('POI/Reminder not found for deep linking: $payload');
      // Show a snackbar if navigator is available
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find the store. Try searching for it.'),
        ),
      );
      return;
    }

    // Navigate to POI detail screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => POIDetailScreen(poi: poi),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Capture POI provider reference for deep linking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _poiProviderRef = Provider.of<POIProvider>(context, listen: false);
    });

    return MaterialApp(
      title: 'LocationPal',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TabNavigationScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'providers/reminder_provider.dart';
import 'repositories/repositories.dart';
import 'screens/tab_navigation_screen.dart';
import 'screens/poi_detail_screen.dart';
import 'services/openai_service.dart';
import 'services/notification_service.dart';
import 'services/background_service_manager.dart';
import 'utils/settings_service.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global POI provider reference for deep linking
POIProvider? _poiProviderRef;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service for Android
  await BackgroundServiceManager.initialize();

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

/// Handle notification tap to navigate to POI detail screen
void _handleNotificationTap(String poiId) {
  // Wait a bit for app to be ready if launched from background
  Future.delayed(const Duration(milliseconds: 500), () {
    if (_poiProviderRef == null) {
      debugPrint('POI provider not available for deep linking');
      return;
    }

    final poi = _poiProviderRef!.findById(poiId);
    if (poi == null) {
      debugPrint('POI not found for deep linking: $poiId');
      // Show a snackbar if navigator is available
      final context = navigatorKey.currentContext;
      if (context != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find the store. Try searching for it.'),
          ),
        );
      }
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

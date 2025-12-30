import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'providers/reminder_provider.dart';
import 'repositories/repositories.dart';
import 'screens/tab_navigation_screen.dart';
import 'services/openai_service.dart';
import 'services/notification_service.dart';
import 'utils/settings_service.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings services
  final settingsService = SettingsService();
  final settingsProvider = SettingsProvider(settingsService: settingsService);
  await settingsProvider.initialize();

  // Initialize notification service with deep linking
  final notificationService = NotificationService();
  await notificationService.initialize(
    onNotificationTapped: (poiId) {
      // Navigate to POI detail screen
      // This will be handled by the navigator in TabNavigationScreen
      debugPrint('Notification tapped for POI: $poiId');
      // TODO: Implement deep link navigation
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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

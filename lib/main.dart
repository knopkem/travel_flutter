import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'repositories/repositories.dart';
import 'screens/tab_navigation_screen.dart';
import 'services/openai_service.dart';
import 'utils/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings services
  final settingsService = SettingsService();
  final settingsProvider = SettingsProvider(settingsService: settingsService);
  await settingsProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocationProvider(
            NominatimGeocodingRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WikipediaProvider(
            RestWikipediaRepository(),
          ),
        ),
        ChangeNotifierProvider.value(
          value: settingsProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => MapNavigationProvider(),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, POIProvider>(
          create: (_) => POIProvider(),
          update: (_, settings, poiProvider) {
            poiProvider?.updateSettings(settings);
            return poiProvider ?? POIProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (context) => AIGuidanceProvider(
            openaiService: OpenAIService(),
            settingsService: settingsService,
            settingsProvider: settingsProvider,
          ),
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
      title: 'TravelPal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TabNavigationScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'repositories/repositories.dart';
import 'screens/tab_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings provider
  final settingsProvider = SettingsProvider();
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
      title: 'Travel Flutter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TabNavigationScreen(),
    );
  }
}

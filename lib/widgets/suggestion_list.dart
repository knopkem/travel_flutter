import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

/// Displays location search suggestions in a scrollable list.
///
/// This widget shows the results from the geocoding API as an
/// interactive list. When a user taps a suggestion, it becomes
/// the active city, replacing any previously selected city.
///
/// The list automatically updates when search results change via
/// the [LocationProvider].
///
/// Features:
/// - Displays up to 10 suggestions from the API
/// - Shows location icon and full display name
/// - Clears suggestions after selection
/// - Dismisses keyboard on tap
/// - Navigates to city detail screen automatically
/// - Shows "No results" message when empty after search
///
/// Example:
/// ```dart
/// Consumer<LocationProvider>(
///   builder: (context, provider, child) {
///     if (provider.suggestions.isNotEmpty) {
///       return const SuggestionList();
///     }
///     return const SizedBox.shrink();
///   },
/// )
/// ```
class SuggestionList extends StatelessWidget {
  const SuggestionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, child) {
        if (provider.suggestions.isEmpty && !provider.isLoading) {
          return const Center(
            child: Text(
              'No locations found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = provider.suggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blue),
              title: Text(suggestion.displayName),
              subtitle: Text('${suggestion.name}, ${suggestion.country}'),
              onTap: () {
                // Dismiss keyboard
                FocusScope.of(context).unfocus();

                // Get POI provider to clear on city change
                final poiProvider = Provider.of<POIProvider>(
                  context,
                  listen: false,
                );

                // Select city (replaces any previous selection and clears POIs)
                provider.selectCity(
                  suggestion,
                  onCityChanged: () => poiProvider.clear(),
                );

                // Clear suggestions
                provider.clearSuggestions();

                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected ${suggestion.name}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );

                // Navigate to location detail screen
                final location = suggestion.toLocation();
                Navigator.pushNamed(
                  context,
                  '/location-detail',
                  arguments: location,
                );
              },
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

/// Displays location search suggestions in a scrollable list.
///
/// This widget shows the results from the geocoding API as an
/// interactive list. When a user taps a suggestion, it is converted
/// to a [Location] and added to the selected locations list.
///
/// The list automatically updates when search results change via
/// the [LocationProvider].
///
/// Features:
/// - Displays up to 10 suggestions from the API
/// - Shows location icon and full display name
/// - Clears suggestions after selection
/// - Dismisses keyboard on tap
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
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

                // Select location and clear suggestions
                provider.selectLocation(suggestion);
                provider.clearSuggestions();

                // Show confirmation snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${suggestion.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

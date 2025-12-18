import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/search_field.dart';
import '../widgets/suggestion_list.dart';
import '../widgets/selected_locations_list.dart';

/// Main screen for location search and selection.
///
/// This screen provides the primary user interface for searching
/// locations and managing the selected locations list. It integrates:
/// - [SearchField] for text input with debouncing
/// - [SuggestionList] for displaying search results
/// - [SelectedLocationsList] for showing selected locations
///
/// The screen layout adapts based on the current state:
/// - Shows suggestions when search results are available
/// - Shows selected locations when no suggestions present
/// - Shows empty state when no data available
///
/// This implements User Story US-001: "As a user, I want to search
/// for locations by typing in a search field, see matching suggestions,
/// and select locations that appear as buttons below the search field."
///
/// Example usage (set as home in MaterialApp):
/// ```dart
/// MaterialApp(
///   home: const HomeScreen(),
/// )
/// ```
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Search'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search input field
            const SearchField(),
            const SizedBox(height: 16),

            // Suggestions or selected locations
            Expanded(
              child: Consumer<LocationProvider>(
                builder: (context, provider, child) {
                  // Show suggestions when available
                  if (provider.suggestions.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Results',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Expanded(child: SuggestionList()),
                      ],
                    );
                  }

                  // Show selected locations when no suggestions
                  if (provider.selectedLocations.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Locations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Expanded(child: SelectedLocationsList()),
                      ],
                    );
                  }

                  // Empty state
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Search for a location to get started',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

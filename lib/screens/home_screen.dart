import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/search_field.dart';
import '../widgets/suggestion_list.dart';
import '../screens/location_detail_screen.dart';

/// Main screen for location search and single city selection.
///
/// This screen provides the primary user interface for searching
/// locations and selecting a single active city. It integrates:
/// - [SearchField] for text input with debouncing
/// - [SuggestionList] for displaying search results
///
/// The screen layout adapts based on the current state:
/// - Shows suggestions when search results are available
/// - Shows selected city when available (single card with city name)
/// - Shows empty state when no city selected
///
/// Selecting a new city replaces the previously selected city.
///
/// This implements User Story US-001: "As a user, I want to search
/// for a city, see matching suggestions, and select a single active
/// city that displays its Wikipedia content and nearby POIs."
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

            // Suggestions or selected city
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

                  // Show selected city when available
                  if (provider.hasSelectedCity) {
                    final city = provider.selectedCity!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected City',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(
                              Icons.location_city,
                              color: Colors.blue,
                              size: 32,
                            ),
                            title: Text(
                              city.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            subtitle: Text(city.country),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Clear selection',
                              onPressed: () => provider.clearCity(),
                            ),
                            onTap: () {
                              // Navigate to location detail screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationDetailScreen(
                                    location: city,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
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
                          'Search for a city to get started',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
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

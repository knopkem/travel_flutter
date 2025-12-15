import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Detail screen showing Wikipedia content for a selected location.
///
/// This screen displays:
/// - Location name and country in AppBar
/// - Loading indicator while fetching Wikipedia content
/// - Article title, extract (summary), and optional thumbnail
/// - Error message if content fetch fails
///
/// The screen automatically fetches Wikipedia content when opened
/// using the location's name as the article title. Content is cached
/// by [WikipediaProvider] to avoid redundant API calls.
///
/// This implements User Story US-002: "As a user, I want to view
/// Wikipedia information about a selected location."
///
/// Example navigation:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => LocationDetailScreen(location: myLocation),
///   ),
/// );
/// ```
class LocationDetailScreen extends StatefulWidget {
  /// The location to display details for
  final Location location;

  const LocationDetailScreen({
    super.key,
    required this.location,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch Wikipedia content when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WikipediaProvider>(context, listen: false)
          .fetchContent(widget.location.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<WikipediaProvider>(
        builder: (context, provider, child) {
          // Show loading indicator
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Wikipedia content...'),
                ],
              ),
            );
          }

          // Show error message
          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.fetchContent(widget.location.name);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Get content from cache
          final content = provider.getContent(widget.location.name);
          if (content == null) {
            return const Center(
              child: Text('No content available'),
            );
          }

          // Display Wikipedia content
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.place, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.location.displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Coordinates: ${widget.location.latitude.toStringAsFixed(4)}, '
                          '${widget.location.longitude.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Wikipedia content
                Text(
                  'Wikipedia',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),

                // Thumbnail image if available
                if (content.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      content.thumbnailUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                if (content.thumbnailUrl != null) const SizedBox(height: 16),

                // Article title
                Text(
                  content.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Article extract (summary)
                Text(
                  content.summary,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/wikipedia_content_widget.dart';

/// Detail screen showing Wikipedia content for a selected location.
///
/// This screen displays:
/// - Location name and country in AppBar
/// - Loading indicator while fetching Wikipedia content
/// - Article summary (quick preview) initially
/// - Option to load full article with sections
/// - Optional thumbnail, complete article sections
/// - Error message if content fetch fails
///
/// The screen uses a two-stage loading approach:
/// 1. Initial load: Fetch summary for quick display
/// 2. User-triggered: Load full article with all sections
///
/// Content is cached by [WikipediaProvider] to avoid redundant API calls.
///
/// This implements User Story US-001 (FR-003): "Display full Wikipedia
/// article content instead of just summaries."
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

  const LocationDetailScreen({super.key, required this.location});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch Wikipedia content when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WikipediaProvider>(
        context,
        listen: false,
      ).fetchContent(widget.location.name);
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
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
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
            return const Center(child: Text('No content available'));
          }

          // Display Wikipedia content
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location information card
                Card(
                  margin: const EdgeInsets.all(16.0),
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

                // Wikipedia content widget
                WikipediaContentWidget(
                  content: content,
                  onLoadFullArticle: () {
                    Provider.of<WikipediaProvider>(
                      context,
                      listen: false,
                    ).fetchFullArticle(widget.location.name);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

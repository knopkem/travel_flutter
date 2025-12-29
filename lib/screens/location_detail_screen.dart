import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/country_language_map.dart';
import '../widgets/wikipedia_content_widget.dart';
import '../widgets/poi_list_widget.dart';
import 'wikipedia_article_screen.dart';
import 'settings_screen.dart';

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
    // Fetch Wikipedia content and POIs when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });
  }

  Future<void> _loadContent() async {
    final wikipediaProvider = Provider.of<WikipediaProvider>(
      context,
      listen: false,
    );
    final poiProvider = Provider.of<POIProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    
    // Set language code based on "Use Local Content" setting
    final useLocalContent = settingsProvider.useLocalContent;
    final country = widget.location.country;
    final languageCode = useLocalContent
        ? CountryLanguageMap.getLanguageCode(country)
        : 'en';
    wikipediaProvider.setLanguageCode(languageCode);

    // Fetch Wikipedia content (errors handled in provider)
    try {
      // Only fetch Wikipedia if location has a name
      if (widget.location.name != null) {
        await wikipediaProvider.fetchContent(widget.location.name!);
      }
    } catch (e) {
      // Error already handled by provider, just log
      debugPrint('Wikipedia fetch failed: $e');
    }

    // Fetch POIs (errors handled in provider)
    try {
      // Fetch POIs for the default category from settings
      final defaultCategory = settingsProvider.defaultPoiCategory;
      poiProvider.setCategory(defaultCategory);
      await poiProvider.discoverPOIs(widget.location, category: defaultCategory);
    } catch (e) {
      // Error already handled by provider, just log
      debugPrint('POI discovery failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.name ??
            'Lat: ${widget.location.latitude.toStringAsFixed(3)}, Lon: ${widget.location.longitude.toStringAsFixed(3)}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<WikipediaProvider>(
        builder: (context, provider, child) {
          // Get content from cache (might be null if fetch failed or no name)
          final content = widget.location.name != null
              ? provider.getContent(widget.location.name!)
              : null;

          // Show full loading only if no content available yet
          if (provider.isLoading && content == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading content...'),
                ],
              ),
            );
          }

          // Display content (even if there's an error, show what we have)
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show error banner if there's an error (but don't block content)
                if (provider.errorMessage != null)
                  Container(
                    width: double.infinity,
                    color: Colors.orange[100],
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange[900]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: TextStyle(color: Colors.orange[900]),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _loadContent(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
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
                                widget.location.displayName ??
                                    'Lat: ${widget.location.latitude.toStringAsFixed(3)}, Lon: ${widget.location.longitude.toStringAsFixed(3)}',
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

                // Wikipedia content widget (if available)
                // Always show summary view here, even if full article is cached
                if (content != null)
                  WikipediaContentWidget(
                    content: WikipediaContent(
                      title: content.title,
                      summary: content.summary,
                      extractHtml: content.extractHtml,
                      thumbnailUrl: content.thumbnailUrl,
                      pageUrl: content.pageUrl,
                      fetchedAt: content.fetchedAt,
                      // Explicitly omit fullContent and sections to show summary only
                    ),
                    onLoadFullArticle: () async {
                      if (widget.location.name != null) {
                        final wikiProvider = Provider.of<WikipediaProvider>(
                          context,
                          listen: false,
                        );
                        final navigator = Navigator.of(context);
                        // Fetch full article first
                        await wikiProvider.fetchFullArticle(widget.location.name!);

                        // Get the updated content with full article
                        if (mounted) {
                          final fullContent = wikiProvider.getContent(widget.location.name!);

                          if (fullContent != null &&
                              fullContent.isFullArticle) {
                            // Navigate to dedicated full article screen
                            navigator.push(
                              MaterialPageRoute(
                                builder: (context) => WikipediaArticleScreen(
                                  content: fullContent,
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Wikipedia content unavailable',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nearby places are still available below',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // POI list widget
                POIListWidget(city: widget.location),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/poi.dart';
import '../providers/providers.dart';

/// POI detail screen showing comprehensive information
///
/// Displays:
/// - POI name, type badge, distance
/// - Image (if available)
/// - Description from Wikipedia
/// - Metadata: opening hours, website
/// - Source attribution
class POIDetailScreen extends StatefulWidget {
  final POI poi;

  const POIDetailScreen({
    super.key,
    required this.poi,
  });

  @override
  State<POIDetailScreen> createState() => _POIDetailScreenState();
}

class _POIDetailScreenState extends State<POIDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch additional details if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.poi.wikipediaTitle != null) {
        Provider.of<WikipediaProvider>(
          context,
          listen: false,
        ).fetchContent(widget.poi.wikipediaTitle!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                if (widget.poi.wikipediaTitle != null)
                  _buildWikipediaContent(context),
                if (widget.poi.description != null) _buildDescription(context),
                _buildMetadata(context),
                _buildSourceAttribution(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.poi.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(128, 0, 0, 0),
              ),
            ],
          ),
        ),
        background: Consumer<WikipediaProvider>(
          builder: (context, provider, child) {
            if (widget.poi.wikipediaTitle != null) {
              final content = provider.getContent(widget.poi.wikipediaTitle!);
              if (content?.thumbnailUrl != null) {
                return Image.network(
                  content!.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholderImage();
                  },
                );
              }
            }
            return _buildPlaceholderImage();
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.place,
        size: 80,
        color: Colors.grey[500],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.poi.type.displayName,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDistance(widget.poi.distanceFromCity),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.star,
                size: 18,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Notability Score: ${widget.poi.notabilityScore}/100',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWikipediaContent(BuildContext context) {
    return Consumer<WikipediaProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final content = provider.getContent(widget.poi.wikipediaTitle!);
        if (content == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                content.summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _launchUrl(content.pageUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Read more on Wikipedia'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.poi.description!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final hasMetadata = widget.poi.website != null ||
        widget.poi.openingHours != null ||
        widget.poi.wikidataId != null;

    if (!hasMetadata) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (widget.poi.openingHours != null) ...[
            _buildMetadataRow(
              context,
              Icons.access_time,
              'Opening Hours',
              widget.poi.openingHours!,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.poi.website != null) ...[
            _buildMetadataLink(
              context,
              Icons.language,
              'Website',
              widget.poi.website!,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.poi.wikidataId != null) ...[
            _buildMetadataRow(
              context,
              Icons.database,
              'Wikidata ID',
              widget.poi.wikidataId!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataLink(
      BuildContext context, IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
        ],
      ),
    );
  }

  Widget _buildSourceAttribution(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Sources',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final source in widget.poi.sources)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSourceIcon(source.name),
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getSourceDisplayName(source.name),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSourceIcon(String sourceName) {
    switch (sourceName) {
      case 'Wikipedia Geosearch':
        return Icons.article;
      case 'OpenStreetMap Overpass':
        return Icons.map;
      case 'Wikidata':
        return Icons.database;
      default:
        return Icons.info;
    }
  }

  String _getSourceDisplayName(String sourceName) {
    switch (sourceName) {
      case 'Wikipedia Geosearch':
        return 'Wikipedia';
      case 'OpenStreetMap Overpass':
        return 'OpenStreetMap';
      case 'Wikidata':
        return 'Wikidata';
      default:
        return sourceName;
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

/// Displays Wikipedia article content with formatting and full article support.
class WikipediaContentWidget extends StatefulWidget {
  final WikipediaContent content;
  final VoidCallback? onLoadFullArticle;

  const WikipediaContentWidget({
    super.key,
    required this.content,
    this.onLoadFullArticle,
  });

  @override
  State<WikipediaContentWidget> createState() => _WikipediaContentWidgetState();
}

class _WikipediaContentWidgetState extends State<WikipediaContentWidget> {
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    for (final section in widget.content.sections ?? []) {
      _expandedSections[section.title] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.content.thumbnailUrl != null) ...[
            _buildThumbnail(),
            const SizedBox(height: 24),
          ],
          _buildTitle(context),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),
          _buildSummary(context),
          const SizedBox(height: 24),
          if (!widget.content.isFullArticle &&
              widget.onLoadFullArticle != null) ...[
            _buildLoadFullArticleButton(),
            const SizedBox(height: 24),
          ] else if (widget.content.isFullArticle &&
              widget.content.sections != null &&
              widget.content.sections!.isNotEmpty) ...[
            _buildSectionsHeader(context),
            const SizedBox(height: 16),
            ..._buildSections(context),
          ],
          const Divider(),
          const SizedBox(height: 16),
          _buildAttribution(context),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Image.network(
          widget.content.thumbnailUrl!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Image unavailable',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      widget.content.title,
      style: Theme.of(
        context,
      ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Text(
      widget.content.summary,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
    );
  }

  Widget _buildLoadFullArticleButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: widget.onLoadFullArticle,
        icon: const Icon(Icons.article),
        label: const Text('Load Full Article'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSectionsHeader(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.menu_book, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Article Sections (${widget.content.sections!.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    return widget.content.sections!.map((section) {
      final isExpanded = _expandedSections[section.title] ?? true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[section.title] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: section.level == 2 ? 18 : 16,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isExpanded) ...[
            Padding(
              padding: EdgeInsets.only(
                left: (section.level - 2) * 16.0,
                bottom: 16,
              ),
              child: Text(
                _stripHtmlTags(section.content),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ],
        ],
      );
    }).toList();
  }

  Widget _buildAttribution(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Content from Wikipedia, the free encyclopedia',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.language, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _launchUrl(widget.content.pageUrl),
                child: Text(
                  widget.content.pageUrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

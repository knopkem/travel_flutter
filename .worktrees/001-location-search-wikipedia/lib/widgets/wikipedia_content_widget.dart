import 'package:flutter/material.dart';
import '../models/models.dart';

/// Displays Wikipedia article content with formatting.
///
/// This widget renders:
/// - Optional thumbnail image with error handling
/// - Article title with headline styling
/// - Article summary text with body styling
/// - Wikipedia attribution footer
/// - Proper spacing and visual hierarchy
///
/// The widget is designed for readability with appropriate
/// typography, spacing, and responsive layout. All content
/// is scrollable via the parent SingleChildScrollView.
///
/// Example:
/// ```dart
/// SingleChildScrollView(
///   child: WikipediaContentWidget(
///     content: myWikipediaContent,
///   ),
/// )
/// ```
class WikipediaContentWidget extends StatelessWidget {
  /// The Wikipedia content to display
  final WikipediaContent content;

  const WikipediaContentWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail image if available
          if (content.thumbnailUrl != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  content.thumbnailUrl!,
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
                            Icon(Icons.broken_image,
                                size: 48, color: Colors.grey),
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
            ),
            const SizedBox(height: 24),
          ],

          // Article title
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),

          // Article summary
          Text(
            content.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6, // Better line height for readability
                ),
          ),
          const SizedBox(height: 32),

          // Wikipedia attribution
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey[600],
              ),
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
              Icon(
                Icons.language,
                size: 16,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content.pageUrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

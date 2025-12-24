import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/wikipedia_content_widget.dart';
import 'settings_screen.dart';

/// Full-screen Wikipedia article view
///
/// Displays a complete Wikipedia article with all sections.
/// This screen is separate from LocationDetailScreen to avoid
/// re-triggering POI discovery when loading the full article.
class WikipediaArticleScreen extends StatelessWidget {
  final WikipediaContent content;

  const WikipediaArticleScreen({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          content.title,
          overflow: TextOverflow.ellipsis,
        ),
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
      body: SingleChildScrollView(
        child: WikipediaContentWidget(
          content: content,
          // No onLoadFullArticle callback since we're already showing full article
        ),
      ),
    );
  }
}

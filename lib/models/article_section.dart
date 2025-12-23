/// Represents a section within a Wikipedia article.
///
/// Articles are structured with hierarchical sections (h2, h3, etc.).
/// This model captures section metadata for rendering and navigation.
///
/// Example:
/// ```dart
/// final section = ArticleSection(
///   title: 'History',
///   content: '<p>Paris was founded...</p>',
///   level: 2, // h2
/// );
/// ```
class ArticleSection {
  /// Section title (extracted from heading tag)
  final String title;

  /// HTML content of the section (everything until the next heading)
  final String content;

  /// Heading level (2 for h2, 3 for h3, etc.)
  ///
  /// Determines section hierarchy and indentation in navigation.
  /// Wikipedia articles typically use h2 for main sections and h3 for subsections.
  final int level;

  /// Creates a new [ArticleSection].
  ///
  /// [level] should be 2 or greater (h2, h3, h4, etc.).
  /// [content] is the HTML between this heading and the next heading.
  const ArticleSection({
    required this.title,
    required this.content,
    required this.level,
  });

  /// Creates [ArticleSection] from parsed HTML data.
  factory ArticleSection.fromMap(Map<String, dynamic> map) {
    return ArticleSection(
      title: map['title'] as String,
      content: map['content'] as String,
      level: map['level'] as int,
    );
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {'title': title, 'content': content, 'level': level};
  }

  @override
  String toString() => 'ArticleSection(title: $title, level: $level)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleSection &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          level == other.level;

  @override
  int get hashCode => title.hashCode ^ level.hashCode;
}

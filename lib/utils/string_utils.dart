/// Utility functions for string matching and manipulation.
library;

/// Checks if a query string is contained within text (case-insensitive).
///
/// Returns true if [query] is empty or if [text] contains [query].
/// Both strings are compared in lowercase for case-insensitive matching.
///
/// Example:
/// ```dart
/// matchesSearch('Grillwerk Curry & Bistro', 'glo'); // false
/// matchesSearch('Grillwerk Curry & Bistro', 'grill'); // true
/// matchesSearch('Grillwerk Curry & Bistro', 'curry'); // true
/// ```
bool matchesSearch(String text, String query) {
  if (query.isEmpty) return true;
  if (text.isEmpty) return false;
  return text.toLowerCase().contains(query.toLowerCase());
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

/// Text input field for searching locations with debouncing.
///
/// This widget handles:
/// - User text input with real-time updates
/// - 300ms debouncing to reduce API calls
/// - Minimum 3 characters required for search
/// - Clear button to reset search
/// - Loading indicator during search
/// - Error message display
///
/// The debouncing mechanism waits 300ms after the last keystroke
/// before triggering a search, preventing excessive API calls during
/// rapid typing.
///
/// Example:
/// ```dart
/// Column(
///   children: [
///     const SearchField(),
///     // Other widgets...
///   ],
/// )
/// ```
class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Handles search input changes with debouncing.
  ///
  /// Cancels any pending search and starts a new 300ms timer.
  /// Only triggers search if query has 3+ characters.
  /// Clears suggestions if query is empty.
  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounce?.cancel();

    // Start new timer (300ms debounce)
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 3) {
        // Trigger search for queries with 3+ characters
        Provider.of<LocationProvider>(context, listen: false)
            .searchLocations(query);
      } else if (query.isEmpty) {
        // Clear suggestions when field is empty
        Provider.of<LocationProvider>(context, listen: false)
            .clearSuggestions();
      }
    });
  }

  /// Handles search submission (Enter key or Done button).
  void _onSearchSubmitted(String query) {
    // Cancel debounce and search immediately
    _debounce?.cancel();
    if (query.length >= 3) {
      Provider.of<LocationProvider>(context, listen: false)
          .searchLocations(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search for a location',
                hintText: 'e.g., Berlin, Paris, Tokyo',
                helperText: 'Type at least 3 characters to search',
                prefixIcon: provider.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          provider.clearSuggestions();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  provider.errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Search for a location',
                      hintText: 'e.g., Berlin, Paris, Tokyo',
                      helperText: 'Type at least 3 characters to search',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
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
                ),
                const SizedBox(width: 8),
                // GPS button
                _GPSButton(provider: provider),
              ],
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

/// GPS button widget that shows loading, error, or ready state.
class _GPSButton extends StatefulWidget {
  final LocationProvider provider;

  const _GPSButton({required this.provider});

  @override
  State<_GPSButton> createState() => _GPSButtonState();
}

class _GPSButtonState extends State<_GPSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Error state - red icon
    if (widget.provider.gpsError != null) {
      return Container(
        height: 54, // Match TextField input height
        width: 54,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: IconButton(
          icon: const Icon(Icons.location_off, color: Colors.red, size: 28),
          tooltip: widget.provider.gpsError,
          onPressed: () => widget.provider.fetchCurrentLocation(context),
        ),
      );
    }

    // Loading state - circular progress indicator
    if (widget.provider.isLoading) {
      return Container(
        height: 54, // Match TextField input height
        width: 54,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    // Ready state - pulsing blue icon
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        height: 54, // Match TextField input height
        width: 54,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: IconButton(
          icon: const Icon(Icons.my_location, color: Colors.blue, size: 28),
          tooltip: 'Use my current location',
          onPressed: () => widget.provider.fetchCurrentLocation(context),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_type.dart';
import '../providers/poi_provider.dart';
import '../providers/map_navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ai_guidance_provider.dart';
import '../screens/poi_detail_screen.dart';
import 'poi_list_item.dart';

/// POI list widget with progressive loading, filtering, and pagination
///
/// Displays discovered POIs with:
/// - Type filter dropdown
/// - Pagination (25 items per page)
/// - Loading states for both phases
/// - Error state with retry button
/// - Empty state when no POIs found
class POIListWidget extends StatefulWidget {
  final Location city;

  const POIListWidget({
    super.key,
    required this.city,
  });

  @override
  State<POIListWidget> createState() => _POIListWidgetState();
}

class _POIListWidgetState extends State<POIListWidget> {
  final Set<POIType> _selectedFilters = {};
  int _currentPage = 1;
  static const int _itemsPerPage = 25;
  bool _hasShownToast = false;
  String? _lastCityId;
  Timer? _distanceDebounceTimer;
  int?
      _tempDistance; // Temporary distance override, null means use settings default

  @override
  void dispose() {
    _distanceDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(POIListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset pagination when city changes
    if (oldWidget.city.id != widget.city.id) {
      setState(() {
        _currentPage = 1;
        _selectedFilters.clear();
        _hasShownToast = false;
        _lastCityId = widget.city.id;
        _tempDistance = null; // Reset distance override
      });
      // Clear filters in provider
      Provider.of<POIProvider>(context, listen: false).clearFilters();
    }
  }

  List<POI> _getFilteredPOIs(
      POIProvider provider, AIGuidanceProvider aiGuidanceProvider) {
    var allPois = provider.allPois;
    debugPrint(
        'POIListWidget: All POIs count: ${allPois.length}, Selected filters: $_selectedFilters');

    // Apply AI guidance filter first
    if (aiGuidanceProvider.hasActiveGuidance) {
      allPois = allPois
          .where((poi) => aiGuidanceProvider.isPoiMatchingGuidance(poi))
          .toList();
      debugPrint('POIListWidget: After AI guidance filter: ${allPois.length}');
    }

    // Then apply type filter
    if (_selectedFilters.isEmpty) {
      return allPois;
    }
    final filtered =
        allPois.where((poi) => _selectedFilters.contains(poi.type)).toList();
    debugPrint('POIListWidget: Filtered POIs count: ${filtered.length}');
    return filtered;
  }

  List<POI> _getPaginatedPOIs(List<POI> pois) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= pois.length) return [];
    return pois.sublist(startIndex, endIndex.clamp(0, pois.length));
  }

  int _getTotalPages(int totalItems) {
    return (totalItems / _itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<POIProvider, AIGuidanceProvider>(
      builder: (context, provider, aiGuidanceProvider, child) {
        // All providers disabled state
        if (provider.allProvidersDisabled) {
          return _buildAllProvidersDisabledState(context);
        }

        // Error state
        if (provider.error != null && !provider.hasData) {
          return _buildErrorState(context, provider);
        }

        // Initial loading (no data yet)
        if (provider.isLoadingPhase1 && !provider.hasData) {
          return _buildShimmerLoading();
        }

        // Empty state
        if (!provider.isLoading && !provider.hasData) {
          return _buildEmptyState();
        }

        // Get filtered and paginated POIs
        final filteredPOIs = _getFilteredPOIs(provider, aiGuidanceProvider);
        final paginatedPOIs = _getPaginatedPOIs(filteredPOIs);
        final totalPages = _getTotalPages(filteredPOIs.length);

        // Show toast if not all sources succeeded (only once per city)
        if (!provider.isLoading &&
            !provider.allSourcesSucceeded &&
            provider.hasData &&
            !_hasShownToast &&
            widget.city.id == _lastCityId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showIncompleteSourcesToast(context, provider);
              setState(() {
                _hasShownToast = true;
              });
            }
          });
        }

        // Has data - show list
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, provider, filteredPOIs.length),
            const SizedBox(height: 8),
            _buildAIGuidanceField(context),
            const SizedBox(height: 8),
            _buildFilterDropdown(context, provider),
            const SizedBox(height: 8),
            _buildDistanceSlider(context),
            const SizedBox(height: 8),

            // Show "no results" message if filter excludes everything
            if (filteredPOIs.isEmpty && _selectedFilters.isNotEmpty)
              _buildNoFilterResultsState()
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paginatedPOIs.length,
                itemBuilder: (context, index) {
                  final poi = paginatedPOIs[index];
                  return POIListItem(
                    poi: poi,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => POIDetailScreen(poi: poi),
                        ),
                      );
                    },
                    onShowOnMap: () => _showPoiOnMap(context, poi),
                    onGetDirections: () => _getDirectionsToPoi(poi),
                  );
                },
              ),

              // Pagination controls
              if (totalPages > 1)
                _buildPaginationControls(totalPages, filteredPOIs.length),
            ],

            if (provider.isLoadingPhase2) ...[
              const SizedBox(height: 16),
              _buildPhase2Loading(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(
      BuildContext context, POIProvider provider, int filteredCount) {
    final count = provider.allPois.length;

    return Semantics(
      label:
          'Nearby Attractions section, showing $filteredCount of $count places',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Icon, Title, and Count
            Row(
              children: [
                Icon(
                  Icons.place,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nearby Attractions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    filteredCount < count
                        ? '$filteredCount of $count'
                        : '$count total',
                    style: const TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            // Second line: API status indicator and Refresh button
            const SizedBox(height: 8),
            Row(
              children: [
                if (!provider.isLoading)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.allSourcesSucceeded
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: provider.allSourcesSucceeded
                            ? Colors.green[300]!
                            : Colors.orange[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.allSourcesSucceeded
                              ? Icons.check_circle
                              : Icons.warning,
                          size: 14,
                          color: provider.allSourcesSucceeded
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'API Sources: ${provider.successfulSources}/${provider.totalSources}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: provider.allSourcesSucceeded
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!provider.isLoading) const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          provider.discoverPOIs(widget.city,
                              forceRefresh: true);
                        },
                  tooltip: 'Refresh POIs',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIGuidanceField(BuildContext context) {
    return _AIGuidanceField();
  }

  Widget _buildFilterDropdown(BuildContext context, POIProvider provider) {
    // Get enabled types from settings
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final enabledTypes = settingsProvider.enabledPoiTypes.toSet();

    // Count POIs by type, only for enabled types
    final typeCounts = <POIType, int>{};
    for (final poi in provider.allPois) {
      if (enabledTypes.contains(poi.type)) {
        typeCounts[poi.type] = (typeCounts[poi.type] ?? 0) + 1;
      }
    }
    debugPrint('POIListWidget: Type counts: $typeCounts');

    final availableTypes = POIType.values
        .where(
            (type) => typeCounts[type] != null && enabledTypes.contains(type))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Filter by Type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (_selectedFilters.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                  onPressed: () {
                    setState(() {
                      _selectedFilters.clear();
                      _currentPage = 1;
                    });
                    // Sync with provider
                    Provider.of<POIProvider>(context, listen: false)
                        .clearFilters();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTypes.map((type) {
              final isSelected = _selectedFilters.contains(type);
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      size: 16,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text('${_getTypeName(type)} (${typeCounts[type]})'),
                  ],
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFilters.add(type);
                    } else {
                      _selectedFilters.remove(type);
                    }
                    _currentPage = 1;
                  });
                  // Sync filters with provider for map
                  Provider.of<POIProvider>(context, listen: false)
                      .updateFilters(_selectedFilters);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceSlider(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currentDistance = _tempDistance ?? settingsProvider.poiSearchDistance;
    final distanceKm = currentDistance / 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Search Radius',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: currentDistance.toDouble(),
            min: 1000,
            max: 50000,
            divisions: 49,
            label: '${distanceKm.toStringAsFixed(1)} km',
            onChanged: (value) {
              setState(() {
                _tempDistance = value.round();
              });
              _onDistanceChanged();
            },
          ),
          if (_tempDistance != null &&
              _tempDistance != settingsProvider.poiSearchDistance)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Temporary override',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempDistance = null;
                      });
                      _onDistanceChanged();
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _onDistanceChanged() {
    // Cancel existing timer
    _distanceDebounceTimer?.cancel();

    // Start new debounce timer (800ms delay)
    _distanceDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        final poiProvider = Provider.of<POIProvider>(context, listen: false);
        final distance = _tempDistance ??
            Provider.of<SettingsProvider>(context, listen: false)
                .poiSearchDistance;

        // Update provider's distance and refetch
        poiProvider.updateSearchDistance(distance);
        poiProvider.discoverPOIs(widget.city, forceRefresh: true);

        // Reset pagination
        setState(() {
          _currentPage = 1;
          _hasShownToast = false;
        });
      }
    });
  }

  Widget _buildPaginationControls(int totalPages, int totalItems) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${(_currentPage * _itemsPerPage).clamp(0, totalItems)} of $totalItems results',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
                tooltip: 'First page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous page',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<int>(
                  value: _currentPage,
                  underline: const SizedBox(),
                  items: List.generate(
                    totalPages,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        'Page ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  onChanged: (int? newPage) {
                    if (newPage != null) {
                      setState(() => _currentPage = newPage);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Next page',
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage = totalPages)
                    : null,
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(POIType type) {
    switch (type) {
      case POIType.monument:
        return Icons.account_balance;
      case POIType.museum:
        return Icons.museum;
      case POIType.religiousSite:
        return Icons.church;
      case POIType.park:
        return Icons.park;
      case POIType.viewpoint:
        return Icons.landscape;
      case POIType.touristAttraction:
        return Icons.attractions;
      case POIType.historicSite:
        return Icons.castle;
      case POIType.other:
        return Icons.place;
    }
  }

  String _getTypeName(POIType type) {
    switch (type) {
      case POIType.monument:
        return 'Monument';
      case POIType.museum:
        return 'Museum';
      case POIType.religiousSite:
        return 'Religious Site';
      case POIType.park:
        return 'Park';
      case POIType.viewpoint:
        return 'Viewpoint';
      case POIType.touristAttraction:
        return 'Tourist Attraction';
      case POIType.historicSite:
        return 'Historic Site';
      case POIType.other:
        return 'Other';
    }
  }

  Widget _buildNoFilterResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Results for This Filter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different POI type.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 200,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                ),
                title: Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                subtitle: Container(
                  width: 100,
                  height: 12,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhase2Loading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading more POIs...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, POIProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load POIs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.retry(widget.city),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllProvidersDisabledState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'POI Discovery Disabled',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All POI data sources are disabled. Enable at least one source in Settings to discover points of interest.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to settings
                Navigator.pushNamed(context, '/settings');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No POIs Found Nearby',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any notable places near this location.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show POI on map by switching to map tab and centering
  void _showPoiOnMap(BuildContext context, POI poi) {
    final mapNavProvider = Provider.of<MapNavigationProvider>(
      context,
      listen: false,
    );
    mapNavProvider.navigateToPoiOnMap(poi);
  }

  /// Open native routing app with directions to POI
  Future<void> _getDirectionsToPoi(POI poi) async {
    final lat = poi.latitude;
    final lng = poi.longitude;
    // Use platform-agnostic geo: URI scheme that works on both iOS and Android
    final url = 'geo:0,0?q=$lat,$lng';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web URL if geo: scheme is not supported
        final fallbackUrl =
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';
        final fallbackUri = Uri.parse(fallbackUrl);
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching directions: $e');
    }
  }

  void _showIncompleteSourcesToast(BuildContext context, POIProvider provider) {
    final failedCount = provider.totalSources - provider.successfulSources;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[100], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$failedCount of ${provider.totalSources} POI sources failed. Some places may be missing.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[800],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _hasShownToast = false;
            });
            provider.discoverPOIs(widget.city, forceRefresh: true);
          },
        ),
      ),
    );
  }
}

class _AIGuidanceField extends StatefulWidget {
  const _AIGuidanceField();

  @override
  State<_AIGuidanceField> createState() => _AIGuidanceFieldState();
}

class _AIGuidanceFieldState extends State<_AIGuidanceField> {
  final TextEditingController _guidanceController = TextEditingController();

  @override
  void dispose() {
    _guidanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final aiGuidanceProvider = Provider.of<AIGuidanceProvider>(context);
    final poiProvider = Provider.of<POIProvider>(context);

    // Only show if API key is configured
    if (!settingsProvider.hasValidOpenAIKey) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Guidance',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _guidanceController,
              decoration: InputDecoration(
                hintText: 'e.g., romantic, kid-friendly, historical...',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: aiGuidanceProvider.hasActiveGuidance
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _guidanceController.clear();
                          aiGuidanceProvider.clearGuidance();
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) => _applyGuidance(
                context,
                aiGuidanceProvider,
                poiProvider,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: aiGuidanceProvider.isLoading
                        ? null
                        : () => _applyGuidance(
                              context,
                              aiGuidanceProvider,
                              poiProvider,
                            ),
                    icon: aiGuidanceProvider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.filter_list, size: 20),
                    label: Text(aiGuidanceProvider.isLoading
                        ? 'Filtering...'
                        : 'Apply AI Filter'),
                  ),
                ),
                if (aiGuidanceProvider.hasActiveGuidance) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      _guidanceController.clear();
                      aiGuidanceProvider.clearGuidance();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            if (aiGuidanceProvider.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: aiGuidanceProvider.noMatchesFound
                      ? Colors.orange.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      aiGuidanceProvider.noMatchesFound
                          ? Icons.info_outline
                          : Icons.error,
                      color: aiGuidanceProvider.noMatchesFound
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        aiGuidanceProvider.error!,
                        style: TextStyle(
                          color: aiGuidanceProvider.noMatchesFound
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (aiGuidanceProvider.hasActiveGuidance &&
                aiGuidanceProvider.error == null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtering by: "${aiGuidanceProvider.guidanceText}"',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyGuidance(
    BuildContext context,
    AIGuidanceProvider aiGuidanceProvider,
    POIProvider poiProvider,
  ) async {
    final guidance = _guidanceController.text.trim();
    if (guidance.isEmpty) {
      aiGuidanceProvider.clearGuidance();
      return;
    }

    await aiGuidanceProvider.applyGuidance(guidance, poiProvider.allPois);
  }
}

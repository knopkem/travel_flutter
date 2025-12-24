import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_source.dart';
import '../models/poi_type.dart';
import '../repositories/repositories.dart';
import '../utils/deduplication_utils.dart';
import '../utils/settings_service.dart';
import 'settings_provider.dart';

/// Provider for managing POI discovery and state
///
/// Orchestrates POI discovery from multiple sources (Wikipedia, Overpass, Wikidata)
/// with progressive loading and automatic deduplication.
class POIProvider extends ChangeNotifier {
  final WikipediaGeosearchRepository _wikipediaRepo;
  final OverpassRepository _overpassRepo;
  final WikidataRepository _wikidataRepo;

  List<POI> _pois = [];
  bool _isLoading = false;
  bool _isLoadingPhase1 = false;
  bool _isLoadingPhase2 = false;
  String? _error;
  String? _currentCityId;
  SettingsProvider? _settingsProvider;
  int _successfulSources = 0;
  int _totalSources = 3; // Wikipedia, Overpass, Wikidata
  Set<POIType> _selectedFilters = {}; // Active POI type filters
  int? _tempSearchDistance; // Temporary distance override from UI slider

  // In-memory cache: cityId -> POI list
  final Map<String, List<POI>> _cache = {};
  final List<String> _cacheKeys = []; // For LRU eviction
  static const int _maxCacheEntries = 10;
  static const int _displayLimit = 25;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  POIProvider({
    WikipediaGeosearchRepository? wikipediaRepo,
    OverpassRepository? overpassRepo,
    WikidataRepository? wikidataRepo,
  })  : _wikipediaRepo = wikipediaRepo ?? WikipediaGeosearchRepository(),
        _overpassRepo = overpassRepo ?? OverpassRepository(),
        _wikidataRepo = wikidataRepo ?? WikidataRepository();

  /// Update settings provider reference
  void updateSettings(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  List<POI> get pois => _pois.take(_displayLimit).toList();
  List<POI> get allPois => _pois;
  List<POI> get filteredPois {
    if (_selectedFilters.isEmpty) return _pois;
    return _pois.where((poi) => _selectedFilters.contains(poi.type)).toList();
  }

  Set<POIType> get selectedFilters => Set.unmodifiable(_selectedFilters);
  bool get isLoading => _isLoading;
  bool get isLoadingPhase1 => _isLoadingPhase1;
  bool get isLoadingPhase2 => _isLoadingPhase2;
  String? get error => _error;
  bool get hasData => _pois.isNotEmpty;
  int get successfulSources => _successfulSources;
  int get totalSources =>
      _settingsProvider?.enabledPoiSources.length ?? _totalSources;
  bool get allSourcesSucceeded => _successfulSources == totalSources;
  bool get allProvidersDisabled =>
      _settingsProvider?.allProvidersDisabled ?? false;

  /// Discover POIs for a city with progressive loading
  ///
  /// Phase 1: Fast Wikipedia Geosearch (~2s)
  /// Phase 2: Parallel Overpass + Wikidata (~3s)
  Future<void> discoverPOIs(Location city, {bool forceRefresh = false}) async {
    final cityId = city.id;

    // Check if all providers are disabled
    if (_settingsProvider?.allProvidersDisabled ?? false) {
      _pois = [];
      _currentCityId = cityId;
      _error = null;
      _isLoading = false;
      _successfulSources = 0;
      notifyListeners();
      return;
    }

    // Get enabled sources
    final enabledSources =
        _settingsProvider?.enabledPoiSources ?? POISource.values;

    // Check cache first (unless force refresh)
    if (!forceRefresh && _cache.containsKey(cityId)) {
      _pois = _cache[cityId]!;
      _currentCityId = cityId;
      _error = null;
      notifyListeners();
      return;
    }

    // Cancel any in-flight requests
    _currentCityId = cityId;
    _isLoading = true;
    _error = null;
    _pois = [];
    _successfulSources = 0;
    notifyListeners();

    try {
      // Phase 1: Wikipedia Geosearch (fast)
      _isLoadingPhase1 = true;
      notifyListeners();

      final distance =
          _tempSearchDistance ?? _settingsProvider?.poiSearchDistance ?? 5000;

      List<POI> wikipediaPOIs = [];
      if (enabledSources.contains(POISource.wikipediaGeosearch)) {
        wikipediaPOIs = await _fetchWithRetry(
          (dist) => _wikipediaRepo.fetchNearbyPOIs(city, radiusMeters: dist),
          'Wikipedia Geosearch',
          distance,
        );
        if (wikipediaPOIs.isNotEmpty) _successfulSources++;
      }

      // Check if city changed during fetch
      if (_currentCityId != cityId) return;

      _pois = _sortAndDeduplicate([wikipediaPOIs]);
      _isLoadingPhase1 = false;
      notifyListeners();

      // Phase 2: Overpass + Wikidata (parallel)
      _isLoadingPhase2 = true;
      notifyListeners();

      final futures = <Future<List<POI>>>[];
      final sourceNames = <String>[];

      if (enabledSources.contains(POISource.overpass)) {
        futures.add(_fetchWithRetry(
          (dist) => _overpassRepo.fetchNearbyPOIs(city, radiusMeters: dist),
          'Overpass',
          distance,
        ));
        sourceNames.add('overpass');
      }

      if (enabledSources.contains(POISource.wikidata)) {
        futures.add(_fetchWithRetry(
          (dist) => _wikidataRepo.fetchNearbyPOIs(city, radiusMeters: dist),
          'Wikidata',
          distance,
        ));
        sourceNames.add('wikidata');
      }

      final results = await Future.wait(futures);

      // Check if city changed during fetch
      if (_currentCityId != cityId) return;

      List<POI> overpassPOIs = [];
      List<POI> wikidataPOIs = [];

      for (int i = 0; i < results.length; i++) {
        if (results[i].isNotEmpty) _successfulSources++;
        if (sourceNames[i] == 'overpass') {
          overpassPOIs = results[i];
        } else if (sourceNames[i] == 'wikidata') {
          wikidataPOIs = results[i];
        }
      }

      // Merge all sources with deduplication
      _pois = _sortAndDeduplicate([wikipediaPOIs, overpassPOIs, wikidataPOIs]);
      _isLoadingPhase2 = false;
      _isLoading = false;

      // Cache the results
      _updateCache(cityId, _pois);

      notifyListeners();
    } catch (e) {
      if (_currentCityId == cityId) {
        debugPrint('POI discovery error: $e');
        _error = 'Unable to discover nearby places. Please try again.';
        _isLoading = false;
        _isLoadingPhase1 = false;
        _isLoadingPhase2 = false;
        notifyListeners();
      }
    }
  }

  /// Fetch POIs from a repository with retry logic and error handling
  /// Reduces search distance by 500m on each retry attempt
  Future<List<POI>> _fetchWithRetry(
    Future<List<POI>> Function(int distance) fetch,
    String sourceName,
    int initialDistance,
  ) async {
    int attempts = 0;
    int currentDistance = initialDistance;

    while (attempts < _maxRetries) {
      try {
        return await fetch(currentDistance);
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries) {
          // Log error but continue with other sources
          debugPrint(
              'Warning: $sourceName failed after $_maxRetries attempts: $e');
          return [];
        }
        // Reduce distance by 500m for next attempt (min 1000m)
        currentDistance = (currentDistance - 500).clamp(1000, initialDistance);
        debugPrint(
            '$sourceName attempt $attempts failed, retrying with ${currentDistance}m radius...');
        await Future.delayed(_retryDelay * attempts); // Exponential backoff
      }
    }

    return [];
  }

  /// Sort and deduplicate POIs from multiple sources
  ///
  /// Applies the following logic:
  /// 1. Deduplicates by ID
  /// 2. Groups by POI type
  /// 3. Sorts each group by notability score (descending)
  /// 4. Orders groups according to user's preference (from SettingsProvider)
  List<POI> _sortAndDeduplicate(List<List<POI>> poiLists) {
    final allPOIs = poiLists.expand((list) => list).toList();
    if (allPOIs.isEmpty) return [];

    // Deduplicate using utility from WP01
    final deduplicated = deduplicatePOIs(allPOIs);

    // Group by POI type
    final grouped = <POIType, List<POI>>{};
    for (final poi in deduplicated) {
      grouped.putIfAbsent(poi.type, () => []).add(poi);
    }

    // Sort each group by notability score (descending)
    for (final group in grouped.values) {
      group.sort((a, b) => b.notabilityScore.compareTo(a.notabilityScore));
    }

    // Get user's preferred order (or default)
    final typeOrder =
        _settingsProvider?.poiTypeOrder ?? SettingsService.defaultPoiOrder;

    // Combine groups according to user's preference order
    final sorted = <POI>[];
    for (final type in typeOrder) {
      if (grouped.containsKey(type)) {
        sorted.addAll(grouped[type]!);
      }
    }

    return sorted;
  }

  /// Update cache with LRU eviction
  void _updateCache(String cityId, List<POI> pois) {
    // Remove if already exists
    if (_cache.containsKey(cityId)) {
      _cacheKeys.remove(cityId);
    }

    // Add to cache
    _cache[cityId] = pois;
    _cacheKeys.add(cityId);

    // Evict oldest if cache is full
    if (_cacheKeys.length > _maxCacheEntries) {
      final oldestKey = _cacheKeys.removeAt(0);
      _cache.remove(oldestKey);
    }
  }

  /// Retry POI discovery after error
  Future<void> retry(Location city) async {
    await discoverPOIs(city, forceRefresh: true);
  }

  /// Clear all POIs and reset state
  void clear() {
    _pois = [];
    _isLoading = false;
    _isLoadingPhase1 = false;
    _isLoadingPhase2 = false;
    _error = null;
    _currentCityId = null;
    _selectedFilters.clear();
    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _cacheKeys.clear();
  }

  /// Update active POI type filters
  void updateFilters(Set<POIType> filters) {
    _selectedFilters = Set.from(filters);
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedFilters.clear();
    notifyListeners();
  }

  /// Update temporary search distance override
  /// Pass null to use default from settings
  void updateSearchDistance(int? distanceMeters) {
    _tempSearchDistance = distanceMeters;
    notifyListeners();
  }

  @override
  void dispose() {
    _wikipediaRepo.dispose();
    _overpassRepo.dispose();
    _wikidataRepo.dispose();
    super.dispose();
  }
}

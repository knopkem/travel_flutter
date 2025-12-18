import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../models/poi.dart';
import '../repositories/repositories.dart';
import '../utils/deduplication_utils.dart';

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

  // In-memory cache: cityId -> POI list
  final Map<String, List<POI>> _cache = {};
  final List<String> _cacheKeys = []; // For LRU eviction
  static const int _maxCacheEntries = 10;
  static const int _displayLimit = 25;

  POIProvider({
    WikipediaGeosearchRepository? wikipediaRepo,
    OverpassRepository? overpassRepo,
    WikidataRepository? wikidataRepo,
  })  : _wikipediaRepo = wikipediaRepo ?? WikipediaGeosearchRepository(),
        _overpassRepo = overpassRepo ?? OverpassRepository(),
        _wikidataRepo = wikidataRepo ?? WikidataRepository();

  List<POI> get pois => _pois.take(_displayLimit).toList();
  List<POI> get allPois => _pois;
  bool get isLoading => _isLoading;
  bool get isLoadingPhase1 => _isLoadingPhase1;
  bool get isLoadingPhase2 => _isLoadingPhase2;
  String? get error => _error;
  bool get hasData => _pois.isNotEmpty;

  /// Discover POIs for a city with progressive loading
  ///
  /// Phase 1: Fast Wikipedia Geosearch (~2s)
  /// Phase 2: Parallel Overpass + Wikidata (~3s)
  Future<void> discoverPOIs(Location city) async {
    final cityId = city.id;

    // Check cache first
    if (_cache.containsKey(cityId)) {
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
    notifyListeners();

    try {
      // Phase 1: Wikipedia Geosearch (fast)
      _isLoadingPhase1 = true;
      notifyListeners();

      final wikipediaPOIs = await _fetchWithErrorHandling(
        () => _wikipediaRepo.fetchNearbyPOIs(city),
        'Wikipedia Geosearch',
      );

      // Check if city changed during fetch
      if (_currentCityId != cityId) return;

      _pois = _sortAndDeduplicate([wikipediaPOIs]);
      _isLoadingPhase1 = false;
      notifyListeners();

      // Phase 2: Overpass + Wikidata (parallel)
      _isLoadingPhase2 = true;
      notifyListeners();

      final results = await Future.wait([
        _fetchWithErrorHandling(
          () => _overpassRepo.fetchNearbyPOIs(city),
          'Overpass',
        ),
        _fetchWithErrorHandling(
          () => _wikidataRepo.fetchNearbyPOIs(city),
          'Wikidata',
        ),
      ]);

      // Check if city changed during fetch
      if (_currentCityId != cityId) return;

      final overpassPOIs = results[0];
      final wikidataPOIs = results[1];

      // Merge all sources with deduplication
      _pois = _sortAndDeduplicate([wikipediaPOIs, overpassPOIs, wikidataPOIs]);
      _isLoadingPhase2 = false;
      _isLoading = false;

      // Cache the results
      _updateCache(cityId, _pois);

      notifyListeners();
    } catch (e) {
      if (_currentCityId == cityId) {
        _error = 'Failed to discover POIs: $e';
        _isLoading = false;
        _isLoadingPhase1 = false;
        _isLoadingPhase2 = false;
        notifyListeners();
      }
    }
  }

  /// Fetch POIs from a repository with error handling
  Future<List<POI>> _fetchWithErrorHandling(
    Future<List<POI>> Function() fetch,
    String sourceName,
  ) async {
    try {
      return await fetch();
    } catch (e) {
      // Log error but continue with other sources
      debugPrint('Warning: $sourceName failed: $e');
      return [];
    }
  }

  /// Sort and deduplicate POIs from multiple sources
  List<POI> _sortAndDeduplicate(List<List<POI>> poiLists) {
    final allPOIs = poiLists.expand((list) => list).toList();
    if (allPOIs.isEmpty) return [];

    // Deduplicate using utility from WP01
    final deduplicated = deduplicatePOIs(allPOIs);

    // Sort by notability score (highest first)
    deduplicated.sort((a, b) => b.notabilityScore.compareTo(a.notabilityScore));

    return deduplicated;
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
    await discoverPOIs(city);
  }

  /// Clear all POIs and reset state
  void clear() {
    _pois = [];
    _isLoading = false;
    _isLoadingPhase1 = false;
    _isLoadingPhase2 = false;
    _error = null;
    _currentCityId = null;
    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _cacheKeys.clear();
  }

  @override
  void dispose() {
    _wikipediaRepo.dispose();
    _overpassRepo.dispose();
    _wikidataRepo.dispose();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../models/poi.dart';
import '../models/poi_category.dart';
import '../models/poi_source.dart';
import '../models/poi_type.dart';
import '../repositories/repositories.dart';
import '../utils/country_language_map.dart';
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
  GooglePlacesRepository _googlePlacesRepo;

  List<POI> _pois = [];
  bool _isLoading = false;
  bool _isLoadingPhase1 = false;
  bool _isLoadingPhase2 = false;
  String? _error;
  String? _currentCityId;
  SettingsProvider? _settingsProvider;
  int _successfulSources = 0;
  final int _totalSources = 3; // Wikipedia, Overpass, Wikidata
  Set<POIType> _selectedFilters = {}; // Active POI type filters
  int? _tempSearchDistance; // Temporary distance override from UI slider
  POICategory _currentCategory = POICategory.attraction; // Current active category
  String _searchQuery = ''; // Search query for filtering POIs by name

  // In-memory cache: "cityId_category" -> POI list
  final Map<String, List<POI>> _cache = {};
  final List<String> _cacheKeys = []; // For LRU eviction

  // Place details cache: placeId -> details map
  final Map<String, Map<String, dynamic>> _detailsCache = {};

  static const int _maxCacheEntries = 10;
  static const int _displayLimit = 25;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  POIProvider({
    WikipediaGeosearchRepository? wikipediaRepo,
    OverpassRepository? overpassRepo,
    WikidataRepository? wikidataRepo,
    GooglePlacesRepository? googlePlacesRepo,
  })  : _wikipediaRepo = wikipediaRepo ?? WikipediaGeosearchRepository(),
        _overpassRepo = overpassRepo ?? OverpassRepository(),
        _wikidataRepo = wikidataRepo ?? WikidataRepository(),
        _googlePlacesRepo = googlePlacesRepo ?? GooglePlacesRepository();

  /// Update settings provider reference
  void updateSettings(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
    // Recreate Google Places repository with callback when settings change
    if (_settingsProvider != null) {
      final apiKey = _settingsProvider!.googlePlacesApiKey;
      if (apiKey != null && apiKey.isNotEmpty) {
        _googlePlacesRepo = _googlePlacesRepo.withApiKey(apiKey);
      }
    }
  }

  List<POI> get pois => _pois.take(_displayLimit).toList();
  List<POI> get allPois => _pois;
  List<POI> get filteredPois {
    if (_selectedFilters.isEmpty) return _pois;
    return _pois.where((poi) => _selectedFilters.contains(poi.type)).toList();
  }

  /// Find a POI by its ID
  POI? findById(String id) {
    try {
      return _pois.firstWhere((poi) => poi.id == id);
    } catch (e) {
      return null;
    }
  }

  Set<POIType> get selectedFilters => Set.unmodifiable(_selectedFilters);
  POICategory get currentCategory => _currentCategory;
  String get searchQuery => _searchQuery;
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

  /// Set the current POI category (attractions or commercial)
  void setCategory(POICategory category) {
    _currentCategory = category;
    notifyListeners();
  }

  /// Discover POIs for a city with progressive loading
  ///
  /// Phase 1: Fast Wikipedia Geosearch (~2s) - only for attractions
  /// Phase 2: Parallel Overpass + Wikidata (~3s) - Wikidata only for attractions
  Future<void> discoverPOIs(Location city,
      {bool forceRefresh = false, POICategory? category}) async {
    final cityId = city.id;
    final targetCategory = category ?? _currentCategory;
    final cacheKey = '${cityId}_${targetCategory.name}';

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

    // Get enabled types for this category
    final enabledTypes = (_settingsProvider?.enabledPoiTypes ?? POIType.values)
        .where((type) => type.category == targetCategory)
        .toSet();

    // Check if all POI types for this category are disabled
    if (enabledTypes.isEmpty) {
      _pois = [];
      _currentCityId = cityId;
      _error =
          'Please enable at least one ${targetCategory.displayName} type in settings';
      _isLoading = false;
      _successfulSources = 0;
      notifyListeners();
      return;
    }

    // Get enabled sources (skip Wikipedia/Wikidata for commercial)
    Set<POISource> enabledSources =
        _settingsProvider?.enabledPoiSources.toSet() ?? POISource.values.toSet();
    if (targetCategory == POICategory.commercial) {
      enabledSources = enabledSources
          .where((source) =>
              source != POISource.wikipediaGeosearch &&
              source != POISource.wikidata)
          .toSet();
    }

    // Check cache first (unless force refresh)
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      _pois = _cache[cacheKey]!;
      _currentCityId = cityId;
      _currentCategory = targetCategory;
      _error = null;
      notifyListeners();
      return;
    }

    // Cancel any in-flight requests
    _currentCityId = cityId;
    _currentCategory = targetCategory;
    _isLoading = true;
    _error = null;
    _pois = [];
    _successfulSources = 0;
    notifyListeners();

    try {
      // Determine language code for API calls
      final useLocalContent = _settingsProvider?.useLocalContent ?? false;
      final languageCode = useLocalContent
          ? CountryLanguageMap.getLanguageCode(city.country)
          : 'en';

      // Configure all repositories with the determined language
      _wikipediaRepo.setLanguageCode(languageCode);
      _wikidataRepo.setLanguageCode(languageCode);
      _googlePlacesRepo.setLanguageCode(languageCode);

      // Phase 1: Wikipedia Geosearch (fast) - only for attractions
      _isLoadingPhase1 = true;
      notifyListeners();

      final distance =
          _tempSearchDistance ?? _settingsProvider?.poiSearchDistance ?? 5000;

      List<POI> wikipediaPOIs = [];
      if (targetCategory == POICategory.attraction &&
          enabledSources.contains(POISource.wikipediaGeosearch)) {
        wikipediaPOIs = await _fetchWithRetry(
          (dist) => _wikipediaRepo.fetchNearbyPOIs(city,
              radiusMeters: dist, enabledTypes: enabledTypes),
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
          (dist) => _overpassRepo.fetchNearbyPOIs(city,
              radiusMeters: dist, enabledTypes: enabledTypes),
          'Overpass',
          distance,
        ));
        sourceNames.add('overpass');
      }

      // Wikidata only for attractions
      if (targetCategory == POICategory.attraction &&
          enabledSources.contains(POISource.wikidata)) {
        futures.add(_fetchWithRetry(
          (dist) => _wikidataRepo.fetchNearbyPOIs(city,
              radiusMeters: dist, enabledTypes: enabledTypes),
          'Wikidata',
          distance,
        ));
        sourceNames.add('wikidata');
      }

      if (enabledSources.contains(POISource.googlePlaces)) {
        final googleApiKey = _settingsProvider?.googlePlacesApiKey;
        if (googleApiKey != null && googleApiKey.isNotEmpty) {
          futures.add(_fetchWithRetry(
            (dist) => _googlePlacesRepo
                .withApiKey(googleApiKey)
                .fetchNearbyPOIs(city,
                    radiusMeters: dist, enabledTypes: enabledTypes),
            'Google Places',
            distance,
          ));
          sourceNames.add('googlePlaces');
        }
      }

      final results = await Future.wait(futures);

      // Check if city changed during fetch
      if (_currentCityId != cityId) return;

      List<POI> overpassPOIs = [];
      List<POI> wikidataPOIs = [];
      List<POI> googlePlacesPOIs = [];

      for (int i = 0; i < results.length; i++) {
        if (results[i].isNotEmpty) _successfulSources++;
        if (sourceNames[i] == 'overpass') {
          overpassPOIs = results[i];
        } else if (sourceNames[i] == 'wikidata') {
          wikidataPOIs = results[i];
        } else if (sourceNames[i] == 'googlePlaces') {
          googlePlacesPOIs = results[i];
        }
      }

      // Merge all sources with deduplication
      _pois = _sortAndDeduplicate(
          [wikipediaPOIs, overpassPOIs, wikidataPOIs, googlePlacesPOIs]);
      _isLoadingPhase2 = false;
      _isLoading = false;

      // Cache the results
      _updateCache(cacheKey, _pois);

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

    // Filter out disabled POI types
    final enabledTypesSet =
        _settingsProvider?.enabledPoiTypes.toSet() ?? POIType.values.toSet();
    final filtered = deduplicated
        .where((poi) => enabledTypesSet.contains(poi.type))
        .toList();

    // Group by POI type
    final grouped = <POIType, List<POI>>{};
    for (final poi in filtered) {
      grouped.putIfAbsent(poi.type, () => []).add(poi);
    }

    // Sort each group by notability score (descending)
    for (final group in grouped.values) {
      group.sort((a, b) => b.notabilityScore.compareTo(a.notabilityScore));
    }

    // Get user's preferred order (or default) - extract just the types
    final typeOrder =
        _settingsProvider?.poiTypeOrder.map((entry) => entry.$1).toList() ??
            SettingsService.defaultPoiOrder;

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
  void _updateCache(String cacheKey, List<POI> pois) {
    // Remove if already exists
    if (_cache.containsKey(cacheKey)) {
      _cacheKeys.remove(cacheKey);
    }

    // Add to cache
    _cache[cacheKey] = pois;
    _cacheKeys.add(cacheKey);

    // Evict oldest if cache is full
    if (_cacheKeys.length > _maxCacheEntries) {
      final oldestKey = _cacheKeys.removeAt(0);
      _cache.remove(oldestKey);
    }
  }

  /// Retry POI discovery after error
  Future<void> retry(Location city, {POICategory? category}) async {
    await discoverPOIs(city,
        forceRefresh: true, category: category ?? _currentCategory);
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
    _searchQuery = '';
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

  /// Update search query for filtering POIs by name
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedFilters.clear();
    _searchQuery = '';
    notifyListeners();
  }

  /// Update temporary search distance override
  /// Pass null to use default from settings
  void updateSearchDistance(int? distanceMeters) {
    _tempSearchDistance = distanceMeters;
    notifyListeners();
  }

  /// Fetch detailed information for a Google Places POI
  ///
  /// Returns an enriched POI with additional details like reviews, ratings,
  /// phone number, and formatted address. Uses cache to avoid redundant API calls.
  Future<POI?> fetchPlaceDetails(POI poi, String apiKey) async {
    // Only fetch details for Google Places POIs
    if (poi.placeId == null) {
      return poi;
    }

    // Check cache first
    if (_detailsCache.containsKey(poi.placeId)) {
      return _mergePOIWithDetails(poi, _detailsCache[poi.placeId]!);
    }

    try {
      final repository = _googlePlacesRepo.withApiKey(apiKey);
      final details = await repository.fetchPlaceDetails(poi.placeId!);

      if (details != null) {
        // Cache the details
        _detailsCache[poi.placeId!] = details;

        // Merge with existing POI
        return _mergePOIWithDetails(poi, details);
      }

      return poi;
    } catch (e) {
      debugPrint('Error fetching place details: $e');
      return poi;
    }
  }

  /// Merge POI with Place Details API response
  POI _mergePOIWithDetails(POI poi, Map<String, dynamic> details) {
    // Use editorial summary as description if available, otherwise keep original
    String? description = poi.description;
    final editorialSummary = details['editorial_summary'] as String?;
    if (editorialSummary != null && editorialSummary.isNotEmpty) {
      description = editorialSummary;
    }

    return POI(
      id: poi.id,
      name: poi.name,
      type: poi.type,
      latitude: poi.latitude,
      longitude: poi.longitude,
      distanceFromCity: poi.distanceFromCity,
      sources: poi.sources,
      description: description,
      wikipediaTitle: poi.wikipediaTitle,
      wikipediaLang: poi.wikipediaLang,
      wikidataId: poi.wikidataId,
      imageUrl: poi.imageUrl,
      website: details['website'] as String? ?? poi.website,
      openingHours: poi.openingHours,
      notabilityScore: poi.notabilityScore,
      discoveredAt: poi.discoveredAt,
      placeId: poi.placeId,
      rating: (details['rating'] as num?)?.toDouble() ?? poi.rating,
      userRatingsTotal:
          details['user_ratings_total'] as int? ?? poi.userRatingsTotal,
      formattedAddress: details['formatted_address'] as String?,
      formattedPhoneNumber: details['formatted_phone_number'] as String?,
      priceLevel: details['price_level'] as int? ?? poi.priceLevel,
      isOpenNow: (details['opening_hours']
              as Map<String, dynamic>?)?['openNow'] as bool? ??
          poi.isOpenNow,
    );
  }

  @override
  void dispose() {
    _wikipediaRepo.dispose();
    _overpassRepo.dispose();
    _wikidataRepo.dispose();
    super.dispose();
  }
}

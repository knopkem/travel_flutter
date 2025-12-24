import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/openai_service.dart';
import '../utils/settings_service.dart';
import 'settings_provider.dart';

class AIGuidanceProvider extends ChangeNotifier {
  final OpenAIService _openaiService;
  final SettingsService _settingsService;
  final SettingsProvider _settingsProvider;

  String _guidanceText = '';
  Set<String> _filteredPoiIds = {};
  bool _isLoading = false;
  String? _error;
  bool _dailyLimitReached = false;
  bool _noMatchesFound = false;

  AIGuidanceProvider({
    required OpenAIService openaiService,
    required SettingsService settingsService,
    required SettingsProvider settingsProvider,
  })  : _openaiService = openaiService,
        _settingsService = settingsService,
        _settingsProvider = settingsProvider;

  String get guidanceText => _guidanceText;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get dailyLimitReached => _dailyLimitReached;
  bool get hasActiveGuidance => _guidanceText.isNotEmpty;
  bool get noMatchesFound => _noMatchesFound;

  /// Check if a POI matches the current guidance filter
  bool isPoiMatchingGuidance(POI poi) {
    if (!hasActiveGuidance) return true; // No filter active, show all
    if (_noMatchesFound || _error != null)
      return true; // Show all on error or no matches
    return _filteredPoiIds.contains(poi.id);
  }

  /// Apply AI guidance to filter POIs
  Future<void> applyGuidance(String guidanceText, List<POI> allPois) async {
    if (guidanceText.trim().isEmpty) {
      clearGuidance();
      return;
    }

    // Check daily limit
    final (requestCount, _) = await _settingsService.loadAIRequestCount();
    if (requestCount >= 50) {
      _error = 'Daily AI request limit reached (50 requests)';
      _dailyLimitReached = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _dailyLimitReached = false;
    _noMatchesFound = false;
    _guidanceText = guidanceText.trim();
    notifyListeners();

    try {
      final apiKey = await _settingsService.loadOpenAIApiKey();
      if (apiKey == null) {
        throw Exception('No API key configured');
      }

      final matchingPoiIds = await _openaiService.filterPOIsByGuidance(
          allPois,
          _guidanceText,
          apiKey,
          _settingsProvider.openaiModel,
          _settingsProvider.aiBatchSize);

      _filteredPoiIds = matchingPoiIds.toSet();

      // Increment request count
      await _settingsService.saveAIRequestCount(
          requestCount + 1, DateTime.now());

      // Check if no matches were found
      if (_filteredPoiIds.isEmpty) {
        _noMatchesFound = true;
        _error =
            'No matches found for "$_guidanceText". Showing all attractions.';
      } else {
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
      _filteredPoiIds.clear();
      _noMatchesFound = false; // Error case, not "no matches"
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear the guidance filter
  void clearGuidance() {
    _guidanceText = '';
    _filteredPoiIds.clear();
    _error = null;
    _dailyLimitReached = false;
    _noMatchesFound = false;
    notifyListeners();
  }
}

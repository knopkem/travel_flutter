import 'package:flutter/material.dart';
import '../models/models.dart';

/// Provider for coordinating map navigation between screens
class MapNavigationProvider with ChangeNotifier {
  POI? _targetPOI;
  bool _shouldNavigate = false;
  String? _nameFilter;

  POI? get targetPOI => _targetPOI;
  bool get shouldNavigate => _shouldNavigate;
  String? get nameFilter => _nameFilter;

  /// Request navigation to a specific POI on the map
  /// This will trigger the tab switch and map centering
  void navigateToPoiOnMap(POI poi) {
    _targetPOI = poi;
    _nameFilter = null;
    _shouldNavigate = true;
    notifyListeners();
  }

  /// Request navigation to map with name filter (for showing all locations)
  /// This will show all POIs matching the given name
  void navigateToMapWithFilter(String name) {
    _nameFilter = name;
    _targetPOI = null;
    _shouldNavigate = true;
    notifyListeners();
  }

  /// Clear navigation request after it has been handled
  void clearNavigation() {
    _shouldNavigate = false;
    _targetPOI = null;
    _nameFilter = null;
    notifyListeners();
  }
}

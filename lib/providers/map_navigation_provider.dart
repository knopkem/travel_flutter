import 'package:flutter/material.dart';
import '../models/models.dart';

/// Provider for coordinating map navigation between screens
class MapNavigationProvider with ChangeNotifier {
  POI? _targetPOI;
  bool _shouldNavigate = false;

  POI? get targetPOI => _targetPOI;
  bool get shouldNavigate => _shouldNavigate;

  /// Request navigation to a specific POI on the map
  /// This will trigger the tab switch and map centering
  void navigateToPoiOnMap(POI poi) {
    _targetPOI = poi;
    _shouldNavigate = true;
    notifyListeners();
  }

  /// Clear navigation request after it has been handled
  void clearNavigation() {
    _shouldNavigate = false;
    _targetPOI = null;
    notifyListeners();
  }
}

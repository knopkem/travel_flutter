import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking dwell time at POIs (5-minute requirement before notification)
class DwellTimeTracker {
  static const String _dwellTimesKey = 'poi_dwell_times';
  static const Duration _requiredDwellTime = Duration(minutes: 5);

  /// Record entry time for a POI
  Future<void> recordEntry(String poiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dwellTimes = await _loadDwellTimes();
      
      // Only record if not already present
      if (!dwellTimes.containsKey(poiId)) {
        dwellTimes[poiId] = DateTime.now().toIso8601String();
        await prefs.setString(_dwellTimesKey, json.encode(dwellTimes));
      }
    } catch (e) {
      debugPrint('Error recording entry time: $e');
    }
  }

  /// Clear entry time for a POI
  Future<void> clearEntry(String poiId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dwellTimes = await _loadDwellTimes();
      
      dwellTimes.remove(poiId);
      await prefs.setString(_dwellTimesKey, json.encode(dwellTimes));
    } catch (e) {
      debugPrint('Error clearing entry time: $e');
    }
  }

  /// Check if user has been within range for required dwell time
  Future<bool> hasDwelledLongEnough(String poiId) async {
    try {
      final dwellTimes = await _loadDwellTimes();
      final entryTimeStr = dwellTimes[poiId];
      
      if (entryTimeStr == null) return false;
      
      final entryTime = DateTime.parse(entryTimeStr);
      final elapsed = DateTime.now().difference(entryTime);
      
      return elapsed >= _requiredDwellTime;
    } catch (e) {
      debugPrint('Error checking dwell time: $e');
      return false;
    }
  }

  /// Get entry time for a POI (if exists)
  Future<DateTime?> getEntryTime(String poiId) async {
    try {
      final dwellTimes = await _loadDwellTimes();
      final entryTimeStr = dwellTimes[poiId];
      
      if (entryTimeStr == null) return null;
      
      return DateTime.parse(entryTimeStr);
    } catch (e) {
      debugPrint('Error getting entry time: $e');
      return null;
    }
  }

  /// Clear all dwell times (cleanup)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dwellTimesKey);
    } catch (e) {
      debugPrint('Error clearing all dwell times: $e');
    }
  }

  /// Load dwell times from storage
  Future<Map<String, String>> _loadDwellTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dwellTimesJson = prefs.getString(_dwellTimesKey);
      
      if (dwellTimesJson == null || dwellTimesJson.isEmpty) {
        return {};
      }

      final decoded = json.decode(dwellTimesJson);
      return Map<String, String>.from(decoded);
    } catch (e) {
      debugPrint('Error loading dwell times: $e');
      return {};
    }
  }
}

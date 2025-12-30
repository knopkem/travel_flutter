import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

/// Service for persisting reminders to SharedPreferences
class ReminderService {
  static const String _remindersKey = 'shopping_reminders';

  /// Load all reminders from storage
  Future<List<Reminder>> loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = prefs.getString(_remindersKey);
      
      if (remindersJson == null || remindersJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = json.decode(remindersJson);
      return decoded
          .map((json) => Reminder.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      return [];
    }
  }

  /// Save all reminders to storage
  Future<bool> saveReminders(List<Reminder> reminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = json.encode(
        reminders.map((reminder) => reminder.toJson()).toList(),
      );
      return await prefs.setString(_remindersKey, remindersJson);
    } catch (e) {
      debugPrint('Error saving reminders: $e');
      return false;
    }
  }

  /// Save a single reminder (add or update)
  Future<bool> saveReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    
    // Check if reminder with this ID already exists
    final existingIndex = reminders.indexWhere((r) => r.id == reminder.id);
    
    if (existingIndex >= 0) {
      // Update existing
      reminders[existingIndex] = reminder;
    } else {
      // Add new
      reminders.add(reminder);
    }
    
    return await saveReminders(reminders);
  }

  /// Delete a reminder by ID
  Future<bool> deleteReminder(String id) async {
    final reminders = await loadReminders();
    reminders.removeWhere((r) => r.id == id);
    return await saveReminders(reminders);
  }

  /// Update a specific reminder
  Future<bool> updateReminder(Reminder updatedReminder) async {
    return await saveReminder(updatedReminder);
  }

  /// Clear all reminders
  Future<bool> clearAllReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_remindersKey);
    } catch (e) {
      debugPrint('Error clearing reminders: $e');
      return false;
    }
  }
}

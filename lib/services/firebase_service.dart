import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase service for anonymous authentication
class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _initialized = false;

  /// Initialize Firebase and sign in anonymously
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('FirebaseService: Already initialized');
      return;
    }

    try {
      if (_auth.currentUser == null) {
        final userCredential = await _auth.signInAnonymously();
        debugPrint(
            '✓ FirebaseService: Signed in anonymously: ${userCredential.user?.uid}');
      } else {
        debugPrint(
            '✓ FirebaseService: Already authenticated as: ${_auth.currentUser?.uid}');
      }
      _initialized = true;
    } catch (e) {
      debugPrint('✗ FirebaseService: Auth initialization failed: $e');
      // Don't rethrow - app can still work without Firebase
    }
  }

  /// Get current user ID
  static String? get userId => _auth.currentUser?.uid;

  /// Get ID token for Cloud Function calls
  static Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('FirebaseService: No user authenticated');
        return null;
      }
      return await user.getIdToken();
    } catch (e) {
      debugPrint('FirebaseService: Failed to get ID token: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Check if Firebase is initialized
  static bool get isInitialized => _initialized;
}

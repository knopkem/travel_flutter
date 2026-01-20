import 'package:shared_preferences/shared_preferences.dart';

/// Service to track onboarding/disclosure state for Play Store compliance
class OnboardingService {
  static const String _keyDisclosureShown = 'disclosure_shown';

  // TODO: Replace these URLs with your actual privacy policy and terms URLs
  // These MUST be hosted and accessible before Play Store submission
  static const String privacyPolicyUrl = 'https://knopkem.github.io/travel_flutter/policy.html';
  static const String termsOfServiceUrl =
      'https://knopkem.github.io/travel_flutter/terms.html';

  /// Check if the permissions disclosure has been shown to the user
  static Future<bool> hasShownDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDisclosureShown) ?? false;
  }

  /// Mark the permissions disclosure as shown
  static Future<void> markDisclosureShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDisclosureShown, true);
  }

  /// Reset the disclosure state (for testing purposes)
  static Future<void> resetDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDisclosureShown);
  }

  /// Check if privacy policy URL is configured
  static bool isPrivacyPolicyConfigured() {
    return !privacyPolicyUrl.contains('example.com') &&
        privacyPolicyUrl.isNotEmpty;
  }

  /// Check if terms of service URL is configured
  static bool isTermsConfigured() {
    return !termsOfServiceUrl.contains('example.com') &&
        termsOfServiceUrl.isNotEmpty;
  }
}

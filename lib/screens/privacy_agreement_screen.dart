import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen shown on first launch to accept privacy policy and terms of service
class PrivacyAgreementScreen extends StatelessWidget {
  const PrivacyAgreementScreen({super.key});

  static const String hasAcceptedKey = 'has_accepted_privacy_policy';
  static const String privacyPolicyUrl =
      'https://your-website.com/privacy-policy';
  static const String termsOfServiceUrl = 'https://your-website.com/terms';

  /// Check if user has already accepted privacy policy
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hasAcceptedKey) ?? false;
  }

  /// Mark privacy policy as accepted
  static Future<void> markAsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasAcceptedKey, true);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to LocationPal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Before you start exploring, please review and accept our privacy policy and terms of service.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildInfoCard(
                context,
                icon: Icons.location_on,
                title: 'Location Data',
                description:
                    'We use your location to find nearby points of interest and shopping reminders.',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                icon: Icons.settings,
                title: 'Settings & Preferences',
                description:
                    'Your settings and API keys are stored locally on your device.',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                icon: Icons.cloud_off,
                title: 'No Personal Data Collection',
                description:
                    'We do not collect or share your personal information with third parties.',
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _launchUrl(privacyPolicyUrl),
                    child: const Text('Privacy Policy'),
                  ),
                  const Text(' • '),
                  TextButton(
                    onPressed: () => _launchUrl(termsOfServiceUrl),
                    child: const Text('Terms of Service'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await markAsAccepted();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Accept & Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _showDeclineDialog(context);
                },
                child: const Text('Decline'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeclineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agreement Required'),
        content: const Text(
          'You must accept the privacy policy and terms of service to use this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

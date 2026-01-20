import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/onboarding_service.dart';

/// First-launch permissions disclosure screen required for Play Store compliance
///
/// Shows users:
/// - Why location permissions are needed
/// - Why notification permissions are needed
/// - Links to privacy policy and terms
/// - Clear opt-in button
class PermissionsDisclosureScreen extends StatelessWidget {
  const PermissionsDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to LocationPal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App intro
              Text(
                'Before we get started',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'LocationPal helps you discover nearby places and get timely reminders when you arrive at stores.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Permissions section
              Text(
                'Permissions We Need',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Location Permission Card
              _PermissionCard(
                icon: Icons.location_on,
                iconColor: Colors.blue,
                title: 'Location Access',
                description:
                    'We use your location to show nearby points of interest and send location-based reminders when you arrive at stores you want to visit.',
                whyNeeded:
                    'This feature requires precise location to work accurately. We only collect location when the app is in use or when you have active reminders.',
                dataUsage: [
                  'Location data stays on your device',
                  'Used only to trigger reminders and show nearby places',
                  'Not shared with third parties for advertising',
                  'You can disable this anytime in Settings',
                ],
              ),
              const SizedBox(height: 16),

              // Notification Permission Card
              _PermissionCard(
                icon: Icons.notifications,
                iconColor: Colors.orange,
                title: 'Notifications',
                description:
                    'We send notifications to remind you when you arrive near stores you\'ve added to your reminder list.',
                whyNeeded:
                    'Timely reminders help you remember shopping tasks when you\'re nearby.',
                dataUsage: [
                  'Notifications are generated locally on your device',
                  'No personal data is sent to servers',
                  'You can customize or disable notifications in Settings',
                ],
              ),
              const SizedBox(height: 24),

              // Background Location Notice
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Background Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To send you reminders when you arrive at stores, we need to access your location even when the app is closed or not in use. This is optional and only needed if you want location-based reminders.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Privacy & Legal section
              Text(
                'Privacy & Legal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your privacy matters to us. Please review:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _LegalLink(
                label: '📄 Privacy Policy',
                url: OnboardingService.privacyPolicyUrl,
                subtitle: 'How we handle your data',
              ),
              const SizedBox(height: 8),
              _LegalLink(
                label: '📋 Terms of Service',
                url: OnboardingService.termsOfServiceUrl,
                subtitle: 'Terms and conditions',
              ),
              const SizedBox(height: 32),

              // Consent button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _acceptAndContinue(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Accept & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fine print
              Text(
                'By continuing, you acknowledge that you have read and agree to our Privacy Policy and Terms of Service.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptAndContinue(BuildContext context) async {
    // Mark disclosure as shown
    await OnboardingService.markDisclosureShown();

    // Close the disclosure screen and return to app
    // Permissions will be requested contextually when features are used
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Card showing a permission request with details
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String whyNeeded;
  final List<String> dataUsage;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.whyNeeded,
    required this.dataUsage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),

            // Why needed
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why we need this:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    whyNeeded,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Data usage details
            Text(
              'What you should know:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            ...dataUsage.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Clickable link to legal documents
class _LegalLink extends StatelessWidget {
  final String label;
  final String url;
  final String subtitle;

  const _LegalLink({
    required this.label,
    required this.url,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _launchUrl(url, context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 20, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString, BuildContext context) async {
    // Check if URL is a placeholder
    if (urlString.contains('example.com') || urlString.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Privacy Policy URL not yet configured. Please contact support.',
            ),
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $urlString')),
        );
      }
    }
  }
}

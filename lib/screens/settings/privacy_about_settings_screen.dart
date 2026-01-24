import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/onboarding_service.dart';
import '../../utils/device_optimization_helper.dart';

/// Settings screen for Privacy, Legal information, and About section
class PrivacyAboutSettingsScreen extends StatefulWidget {
  const PrivacyAboutSettingsScreen({super.key});

  @override
  State<PrivacyAboutSettingsScreen> createState() =>
      _PrivacyAboutSettingsScreenState();
}

class _PrivacyAboutSettingsScreenState
    extends State<PrivacyAboutSettingsScreen> {
  String _version = 'Loading...';
  bool _isProblematicDevice = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkDevice();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _checkDevice() async {
    final isProblematic = await DeviceOptimizationHelper.isProblematicDevice();
    if (mounted) {
      setState(() {
        _isProblematicDevice = isProblematic;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & About'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          _buildPrivacySection(context),
          const Divider(height: 1),
          if (_isProblematicDevice || kDebugMode) ...[
            _buildDeviceSupportSection(context),
            const Divider(height: 1),
          ],
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.privacy_tip),
      title: const Text(
        'Privacy & Legal',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('Privacy policy, terms & data management'),
      children: [
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Privacy Policy'),
          subtitle: const Text('How we handle your data'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _launchUrl(
            OnboardingService.privacyPolicyUrl,
            'Privacy Policy',
            context,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.article),
          title: const Text('Terms of Service'),
          subtitle: const Text('Terms and conditions'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _launchUrl(
            OnboardingService.termsOfServiceUrl,
            'Terms of Service',
            context,
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Collection',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildDataItem(
                context,
                Icons.location_on,
                'Location Data',
                'Used only for showing nearby places and location-based reminders. Data stays on your device.',
              ),
              const SizedBox(height: 8),
              _buildDataItem(
                context,
                Icons.notifications,
                'Notifications',
                'Local notifications to remind you when near tagged stores. No data sent to servers.',
              ),
              const SizedBox(height: 8),
              _buildDataItem(
                context,
                Icons.phone_android,
                'Device Info',
                'Basic device info for app functionality. Not used for tracking.',
              ),
              const SizedBox(height: 16),
              if (!OnboardingService.isPrivacyPolicyConfigured())
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[900], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Privacy Policy URL is not configured yet. Please contact support.',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(
    String urlString,
    String label,
    BuildContext context,
  ) async {
    if (urlString.contains('example.com') || urlString.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$label URL not yet configured. Please contact support.',
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
          SnackBar(content: Text('Could not open $label')),
        );
      }
    }
  }

  Widget _buildDeviceSupportSection(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: _isProblematicDevice,
      leading: Icon(
        _isProblematicDevice ? Icons.warning_amber : Icons.phone_android,
        color: _isProblematicDevice ? Colors.orange : null,
      ),
      title: const Text(
        'Device Support',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: _isProblematicDevice
          ? const Text('Special setup required for reliable location tracking')
          : const Text('Device compatibility and diagnostics'),
      children: [
        if (_isProblematicDevice)
          ListTile(
            leading: const Icon(Icons.settings_suggest, color: Colors.orange),
            title: const Text('Device Optimization Guide'),
            subtitle: const Text(
              'Your device requires special settings for background location',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await DeviceOptimizationHelper.showOptimizationGuide(context);
            },
          ),
        if (_isProblematicDevice && kDebugMode) const Divider(),
        ListTile(
          leading: Icon(
            Icons.bug_report,
            color: kDebugMode ? Colors.orange : Colors.grey,
          ),
          title: const Text('Run Location Diagnostics'),
          subtitle: Text(
            kDebugMode
                ? 'Test location methods on this device'
                : 'Only available in debug builds',
          ),
          trailing: kDebugMode ? const Icon(Icons.chevron_right) : null,
          enabled: kDebugMode,
          onTap: kDebugMode ? () => _runLocationDiagnostics(context) : null,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.info_outline),
      title: const Text(
        'About',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('App info, licenses & attributions'),
      children: [
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: const Text('LocationPal'),
          subtitle: Text('Version $_version'),
        ),
        // Debug: Location Diagnostics (only in debug mode)
        if (kDebugMode) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('Run Location Diagnostics'),
            subtitle: const Text('Debug: Test location on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _runLocationDiagnostics(context),
          ),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Open Source Licenses'),
          subtitle: const Text('View third-party software licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'LocationPal',
              applicationVersion: _version,
              applicationLegalese: '© 2025 LocationPal',
            );
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Attributions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildAttributionItem(
                context,
                'Wikipedia',
                'Content licensed under CC BY-SA 3.0',
                'https://wikipedia.org',
              ),
              const SizedBox(height: 8),
              _buildAttributionItem(
                context,
                'OpenStreetMap',
                'Map data © OpenStreetMap contributors, ODbL',
                'https://openstreetmap.org',
              ),
              const SizedBox(height: 8),
              _buildAttributionItem(
                context,
                'Wikidata',
                'Data available under CC0 1.0',
                'https://wikidata.org',
              ),
              const SizedBox(height: 8),
              _buildAttributionItem(
                context,
                'Nominatim',
                'Geocoding service by OpenStreetMap',
                'https://nominatim.org',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttributionItem(
    BuildContext context,
    String name,
    String description,
    String url,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Run location diagnostics (debug only)
  Future<void> _runLocationDiagnostics(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Running location diagnostics...\nThis may take up to 45 seconds.')),
          ],
        ),
      ),
    );

    try {
      final results = await DeviceOptimizationHelper.runLocationDiagnostics();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show results dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Diagnostics Results'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      const JsonEncoder.withIndent('  ').convert(results),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diagnostics failed: $e')),
        );
      }
    }
  }
}

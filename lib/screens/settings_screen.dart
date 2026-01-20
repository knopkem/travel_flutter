import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/reminder_provider.dart';
import 'settings/api_keys_settings_screen.dart';
import 'settings/poi_discovery_settings_screen.dart';
import 'settings/reminders_settings_screen.dart';
import 'settings/privacy_about_settings_screen.dart';

/// Main Settings screen with navigation to sub-screens organized by topic
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer2<SettingsProvider, ReminderProvider>(
        builder: (context, settingsProvider, reminderProvider, child) {
          if (settingsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              _buildSettingsCategory(
                context: context,
                icon: Icons.key,
                iconColor: _getApiKeysStatusColor(settingsProvider),
                title: 'API Keys',
                subtitle: _getApiKeysSubtitle(settingsProvider),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ApiKeysSettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildSettingsCategory(
                context: context,
                icon: Icons.explore,
                iconColor: Theme.of(context).colorScheme.primary,
                title: 'POI Discovery',
                subtitle: _getPoiDiscoverySubtitle(settingsProvider),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PoiDiscoverySettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildSettingsCategory(
                context: context,
                icon: Icons.shopping_cart,
                iconColor: reminderProvider.hasReminders
                    ? Colors.green
                    : Colors.grey,
                title: 'Shopping Reminders',
                subtitle: _getRemindersSubtitle(
                    settingsProvider, reminderProvider),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemindersSettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildSettingsCategory(
                context: context,
                icon: Icons.info_outline,
                iconColor: Theme.of(context).colorScheme.primary,
                title: 'Privacy & About',
                subtitle: 'Privacy policy, licenses & attributions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyAboutSettingsScreen(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsCategory({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  Color _getApiKeysStatusColor(SettingsProvider settingsProvider) {
    final hasOpenAI = settingsProvider.hasValidOpenAIKey;
    final hasGooglePlaces = settingsProvider.hasValidGooglePlacesKey;

    if (hasOpenAI && hasGooglePlaces) {
      return Colors.green;
    } else if (hasOpenAI || hasGooglePlaces) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  String _getApiKeysSubtitle(SettingsProvider settingsProvider) {
    final hasOpenAI = settingsProvider.hasValidOpenAIKey;
    final hasGooglePlaces = settingsProvider.hasValidGooglePlacesKey;

    if (hasOpenAI && hasGooglePlaces) {
      return 'OpenAI & Google Places configured';
    } else if (hasOpenAI) {
      return 'OpenAI configured';
    } else if (hasGooglePlaces) {
      return 'Google Places configured';
    } else {
      return 'Configure API keys for enhanced features';
    }
  }

  String _getPoiDiscoverySubtitle(SettingsProvider settingsProvider) {
    final enabledSources = settingsProvider.enabledPoiSources.length;
    final distanceKm = (settingsProvider.poiSearchDistance / 1000).round();

    return '$enabledSources sources enabled • $distanceKm km radius';
  }

  String _getRemindersSubtitle(
    SettingsProvider settingsProvider,
    ReminderProvider reminderProvider,
  ) {
    if (!reminderProvider.hasReminders) {
      return 'No active reminders';
    }

    final count = reminderProvider.reminders.length;
    final bgEnabled = settingsProvider.backgroundLocationEnabled;

    return '$count reminder${count == 1 ? '' : 's'} • Background ${bgEnabled ? 'on' : 'off'}';
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper for showing permission rationale dialogs
class PermissionDialogHelper {
  /// Show foreground location permission rationale
  static Future<bool> showForegroundLocationRationale(
      BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'To notify you when you\'re near a tagged store, this app needs location access.\n\n'
            'Your location is only checked periodically when reminders are active and is never shared with third parties.\n\n'
            'You can disable this feature anytime in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show background location permission rationale (Android 10+)
  static Future<bool> showBackgroundLocationRationale(
      BuildContext context) async {
    final isIOS = Platform.isIOS;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Background Location Permission'),
          content: Text(
            isIOS
                ? 'To receive reminders when near stores, this app needs "Always" location access.\n\n'
                  'On the next screen, tap "Location" and select "Always" to enable shopping reminders.\n\n'
                  'Your location is only checked periodically when reminders are active and is never shared with third parties.'
                : 'To check your location even when the app is closed or not in use, Android requires "Allow all the time" permission.\n\n'
                  'On the next screen, please select "Allow all the time" to enable shopping reminders.\n\n'
                  'Your location is only checked periodically when reminders are active and is never shared with third parties.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(isIOS ? 'Open Settings' : 'Continue'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show notification permission rationale
  static Future<bool> showNotificationRationale(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notification Permission'),
          content: const Text(
            'To remind you about your shopping list when near a store, '
            'this app needs permission to send notifications.\n\n'
            'You can disable notifications anytime in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show dialog when notification permission was previously denied
  /// Returns true if user wants to open Settings
  static Future<bool> showNotificationPermissionDeniedDialog(
      BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_off, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifications Disabled')),
            ],
          ),
          content: const Text(
            'Notification permission was previously denied.\n\n'
            'To receive shopping reminders when near a store, please enable notifications in your device Settings:\n\n'
            '1. Tap "Open Settings" below\n'
            '2. Find "Notifications"\n'
            '3. Enable "Allow Notifications"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show success message after reminder creation
  static void showReminderCreatedMessage(
      BuildContext context, String brandName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shopping reminder created for $brandName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show success message after reminder creation (with messenger)
  static void showReminderCreatedMessageWithMessenger(
      ScaffoldMessengerState messenger, String brandName) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Shopping reminder created for $brandName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show success message after reminder removal
  static void showReminderRemovedMessage(
      BuildContext context, String brandName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shopping reminder removed for $brandName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show success message after reminder removal (with messenger)
  static void showReminderRemovedMessageWithMessenger(
      ScaffoldMessengerState messenger, String brandName) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Shopping reminder removed for $brandName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show auto-removal message when all items checked
  static void showReminderAutoRemovedMessage(
      BuildContext context, String brandName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All items checked! Reminder for $brandName removed.'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show auto-removal message when all items checked (with messenger)
  static void showReminderAutoRemovedMessageWithMessenger(
      ScaffoldMessengerState messenger, String brandName) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('All items checked! Reminder for $brandName removed.'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error message
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  /// Show error message (with messenger)
  static void showErrorWithMessenger(
      ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  /// Show Google Play Services update dialog
  static Future<bool> showPlayServicesUpdateDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Google Play Services Required'),
            ],
          ),
          content: const Text(
            'Location reminders require Google Play Services to work efficiently.\n\n'
            'You can update Google Play Services from the Play Store, or continue with basic polling-based monitoring (uses more battery).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Use Basic Monitoring'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Open Play Store to Google Play Services
                final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.gms');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Update Play Services'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

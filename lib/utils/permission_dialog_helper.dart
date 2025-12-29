import 'package:flutter/material.dart';

/// Helper for showing permission rationale dialogs
class PermissionDialogHelper {
  /// Show background location permission rationale
  static Future<bool> showBackgroundLocationRationale(
      BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Background Location Permission'),
          content: const Text(
            'To notify you when you\'re near a tagged store, this app needs background location access.\n\n'
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

  /// Show success message after reminder creation
  static void showReminderCreatedMessage(BuildContext context, String brandName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shopping reminder created for $brandName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show success message after reminder removal
  static void showReminderRemovedMessage(BuildContext context, String brandName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shopping reminder removed for $brandName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show auto-removal message when all items checked
  static void showReminderAutoRemovedMessage(BuildContext context, String brandName) {
    ScaffoldMessenger.of(context).showSnackBar(
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
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

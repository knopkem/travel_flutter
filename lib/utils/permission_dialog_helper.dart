import 'package:flutter/material.dart';

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
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Background Location Permission'),
          content: const Text(
            'To check your location even when the app is closed or not in use, Android requires "Allow all the time" permission.\n\n'
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
}

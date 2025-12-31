import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper for managing battery optimization exemption on Android
class BatteryOptimizationHelper {
  /// Check if the app is ignoring battery optimizations
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;

    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Show rationale dialog and request battery optimization exemption
  static Future<bool> requestBatteryOptimizationExemption(
      BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Check if already exempted
    final isExempted = await isIgnoringBatteryOptimizations();
    if (isExempted) return true;

    // Show rationale dialog
    if (!context.mounted) return false;
    final shouldRequest = await showRationale(context);
    if (!shouldRequest) return false;

    // Request the exemption
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Show rationale dialog explaining why battery optimization should be disabled
  static Future<bool> showRationale(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'For reliable location monitoring when the app is in the background, '
            'LocationPal needs to be exempted from battery optimization.\n\n'
            'On the next screen, please allow LocationPal to run in the background '
            'without restrictions.\n\n'
            'This ensures you receive timely reminders when near your tagged stores.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
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

  /// Show info dialog when battery optimization check fails
  static void showBatteryOptimizationInfo(
    BuildContext context,
    ScaffoldMessengerState messenger,
  ) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'For best results, disable battery optimization in Settings > Apps > LocationPal',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }
}

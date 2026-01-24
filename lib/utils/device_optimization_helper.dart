import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper for handling manufacturer-specific battery optimization and permissions
/// 
/// Many Android manufacturers (Xiaomi, Huawei, OnePlus, etc.) have aggressive
/// battery optimization that kills background services. This helper provides:
/// - Detection of problematic manufacturers
/// - Links to manufacturer-specific setup guides (dontkillmyapp.com)
/// - Battery optimization settings access
class DeviceOptimizationHelper {
  /// List of manufacturers known to have aggressive battery optimization
  /// Source: https://dontkillmyapp.com
  static const List<String> _problematicManufacturers = [
    'xiaomi',
    'redmi',
    'poco',
    'huawei',
    'honor',
    'oneplus',
    'oppo',
    'realme',
    'vivo',
    'samsung',
    'sony',
    'asus',
    'meizu',
    'letv',
    'nokia', // HMD Global devices
    'lenovo',
    'zte',
    'wiko',
  ];

  /// Cached device info to avoid repeated queries
  static AndroidDeviceInfo? _cachedDeviceInfo;
  static String? _cachedManufacturer;

  /// Get device info (cached)
  static Future<AndroidDeviceInfo> _getDeviceInfo() async {
    _cachedDeviceInfo ??= await DeviceInfoPlugin().androidInfo;
    return _cachedDeviceInfo!;
  }

  /// Get manufacturer name (cached, lowercase)
  static Future<String> getManufacturer() async {
    if (_cachedManufacturer != null) return _cachedManufacturer!;
    final deviceInfo = await _getDeviceInfo();
    _cachedManufacturer = deviceInfo.manufacturer.toLowerCase();
    return _cachedManufacturer!;
  }

  /// Check if device is from a manufacturer with aggressive battery optimization
  static Future<bool> isProblematicDevice() async {
    final manufacturer = await getManufacturer();
    return _problematicManufacturers.any((m) => manufacturer.contains(m));
  }

  /// Get manufacturer-specific instructions URL from dontkillmyapp.com
  static Future<String?> getOptimizationGuideUrl() async {
    final manufacturer = await getManufacturer();
    
    final urlMap = {
      'xiaomi': 'https://dontkillmyapp.com/xiaomi',
      'redmi': 'https://dontkillmyapp.com/xiaomi',
      'poco': 'https://dontkillmyapp.com/xiaomi',
      'huawei': 'https://dontkillmyapp.com/huawei',
      'honor': 'https://dontkillmyapp.com/honor',
      'oneplus': 'https://dontkillmyapp.com/oneplus',
      'oppo': 'https://dontkillmyapp.com/oppo',
      'realme': 'https://dontkillmyapp.com/realme',
      'vivo': 'https://dontkillmyapp.com/vivo',
      'samsung': 'https://dontkillmyapp.com/samsung',
      'sony': 'https://dontkillmyapp.com/sony',
      'asus': 'https://dontkillmyapp.com/asus',
      'meizu': 'https://dontkillmyapp.com/meizu',
      'letv': 'https://dontkillmyapp.com/letv',
      'nokia': 'https://dontkillmyapp.com/nokia',
      'lenovo': 'https://dontkillmyapp.com/lenovo',
      'zte': 'https://dontkillmyapp.com/zte',
      'wiko': 'https://dontkillmyapp.com/wiko',
    };
    
    // Find matching manufacturer
    for (final entry in urlMap.entries) {
      if (manufacturer.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Check if battery optimization is disabled for this app
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      // permission_handler doesn't have battery optimization check
      // Return false to always prompt on problematic devices
      return false;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization (opens system settings)
  static Future<bool> requestDisableBatteryOptimization() async {
    try {
      await openAppSettings();
      return true;
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Show manufacturer-specific setup dialog
  static Future<void> showOptimizationGuide(BuildContext context) async {
    final deviceInfo = await _getDeviceInfo();
    final manufacturer = deviceInfo.manufacturer;
    final guideUrl = await getOptimizationGuideUrl();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$manufacturer Device Setup'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'For reliable location tracking on $manufacturer devices, please:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStep('1', 'Disable battery optimization'),
              _buildStep('2', 'Enable "Autostart" permission'),
              _buildStep('3', 'Set location to "Allow all the time"'),
              _buildStep('4', 'Keep location accuracy on "High"'),
              const SizedBox(height: 16),
              const Text(
                'Without these settings, background location tracking and shopping reminders may not work reliably.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              if (guideUrl != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(guideUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Detailed Guide'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await requestDisableBatteryOptimization();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Build a numbered step widget
  static Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  /// Check optimization status and prompt if needed before creating reminder
  /// 
  /// Returns true if optimization is disabled or user wants to proceed anyway
  /// Returns false if user cancels
  static Future<bool> checkOptimizationBeforeReminder(BuildContext context) async {
    final isProblematic = await isProblematicDevice();
    if (!isProblematic) return true;

    final isOptimized = await isBatteryOptimizationDisabled();
    if (isOptimized) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Important Setup Required'),
        content: const Text(
          'Your device requires special settings for background location tracking. '
          'Without these, shopping reminders may not work reliably.\n\n'
          'Would you like to configure these settings now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip for Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              if (context.mounted) {
                await showOptimizationGuide(context);
              }
            },
            child: const Text('Configure'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show a simple warning snackbar about battery optimization
  static void showOptimizationWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'For reliable reminders, please disable battery optimization in Settings',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () async {
            await requestDisableBatteryOptimization();
          },
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/settings_provider.dart';
import '../services/location_monitor_service.dart';
import '../services/debug_log_service.dart';

/// Info panel for geofence debugging
class GeofenceDebugOverlay extends StatefulWidget {
  final bool showDebug;
  final VoidCallback onToggleDebug;

  const GeofenceDebugOverlay({
    super.key,
    required this.showDebug,
    required this.onToggleDebug,
  });

  @override
  State<GeofenceDebugOverlay> createState() => _GeofenceDebugOverlayState();
}

class _GeofenceDebugOverlayState extends State<GeofenceDebugOverlay> {
  bool _showInfoPanel = true;
  Timer? _statsUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Update stats periodically when debug is enabled
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (widget.showDebug && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _statsUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debugLogService = DebugLogService();
    final eventLogs = debugLogService.getLogs();

    return Consumer2<ReminderProvider, SettingsProvider>(
      builder: (context, reminderProvider, settingsProvider, child) {
        final reminders = reminderProvider.reminders;
        final locationService = LocationMonitorService();
        final stats = locationService.getGeofenceStats();

        return Stack(
          children: [
            // Debug toggle FAB
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                heroTag: 'debug_toggle',
                onPressed: widget.onToggleDebug,
                backgroundColor:
                    widget.showDebug ? Colors.orange : Colors.grey[700],
                child: Icon(
                  widget.showDebug
                      ? Icons.bug_report
                      : Icons.bug_report_outlined,
                  size: 20,
                ),
              ),
            ),

            // Info panel
            if (widget.showDebug && _showInfoPanel)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.orange[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bug_report,
                              size: 20,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Geofence Debug',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _showInfoPanel = false;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // Stats
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    label: 'Total Reminders',
                                    value: '${reminders.length}',
                                    icon: Icons.notifications,
                                  ),
                                ),
                                if (stats != null) ...[
                                  Expanded(
                                    child: _StatItem(
                                      label: 'Active Geofences',
                                      value: '${stats['active']}',
                                      icon: Icons.radio_button_checked,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (stats != null &&
                                stats['total']! > stats['active']!)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.amber[900],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Only nearest ${stats['active']} of ${stats['total']} reminders are active (100-limit)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.amber[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Event log
                      if (eventLogs.isNotEmpty) ...[
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Event Log',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${eventLogs.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      debugLogService.clear();
                                      setState(() {});
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 120),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: eventLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = eventLogs[index];
                                    Color logColor;
                                    switch (log.type) {
                                      case DebugLogType.register:
                                        logColor = Colors.green[700]!;
                                        break;
                                      case DebugLogType.unregister:
                                        logColor = Colors.orange[700]!;
                                        break;
                                      case DebugLogType.event:
                                        logColor = Colors.blue[700]!;
                                        break;
                                      case DebugLogType.error:
                                        logColor = Colors.red[700]!;
                                        break;
                                      case DebugLogType.strategy:
                                        logColor = Colors.purple[700]!;
                                        break;
                                      default:
                                        logColor = Colors.grey[700]!;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.typeIcon,
                                            style:
                                                const TextStyle(fontSize: 10),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            log.formattedTime,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontFamily: 'monospace',
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              log.message,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: logColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Reopen info panel button
            if (widget.showDebug && !_showInfoPanel)
              Positioned(
                bottom: 16,
                left: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'reopen_info',
                  onPressed: () {
                    setState(() {
                      _showInfoPanel = true;
                    });
                  },
                  backgroundColor: Colors.orange[100],
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text(
                    'Debug Info',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color ?? Colors.blue),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

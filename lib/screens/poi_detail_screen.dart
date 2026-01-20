import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/poi.dart';
import '../models/poi_category.dart';
import '../providers/providers.dart';
import '../providers/reminder_provider.dart';
import '../utils/brand_matcher.dart';
import '../utils/country_language_map.dart';
import '../utils/format_utils.dart';
import '../utils/permission_dialog_helper.dart';
import '../utils/battery_optimization_helper.dart';
import '../services/location_monitor_service.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';

/// POI detail screen showing comprehensive information
///
/// Displays:
/// - POI name, type badge, distance
/// - Image (if available)
/// - Description from Wikipedia
/// - Metadata: opening hours, website
/// - Source attribution
class POIDetailScreen extends StatefulWidget {
  final POI poi;

  const POIDetailScreen({
    super.key,
    required this.poi,
  });

  @override
  State<POIDetailScreen> createState() => _POIDetailScreenState();
}

class _POIDetailScreenState extends State<POIDetailScreen> {
  POI? _enrichedPOI; // POI with fetched place details
  bool _isReminderExpanded = false;
  bool _isOperationInProgress = false;
  final TextEditingController _newItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch additional details if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();

      if (widget.poi.wikipediaTitle != null) {
        // Determine language code based on settings
        final settingsProvider = Provider.of<SettingsProvider>(
          context,
          listen: false,
        );
        final locationProvider = Provider.of<LocationProvider>(
          context,
          listen: false,
        );
        final wikipediaProvider = Provider.of<WikipediaProvider>(
          context,
          listen: false,
        );

        // Determine language code based on "Use Local Content" setting:
        // - If OFF: Always use English (even if article doesn't exist)
        // - If ON: Use POI's explicit language, or fall back to country's language
        final useLocalContent = settingsProvider.useLocalContent;
        String languageCode;
        if (useLocalContent) {
          // Use POI's explicit language if available, else country's language
          if (widget.poi.wikipediaLang != null) {
            languageCode = widget.poi.wikipediaLang!;
          } else {
            final country = locationProvider.selectedCity?.country;
            languageCode = CountryLanguageMap.getLanguageCode(country);
          }
        } else {
          // Always use English when "Use Local Content" is disabled
          languageCode = 'en';
        }
        wikipediaProvider.setLanguageCode(languageCode);

        wikipediaProvider.fetchContent(widget.poi.wikipediaTitle!);
      }
    });
  }

  /// Fetch place details if this is a Google Places POI
  Future<void> _fetchDetails() async {
    if (widget.poi.placeId == null) return;

    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final poiProvider = Provider.of<POIProvider>(
        context,
        listen: false,
      );

      final apiKey = settingsProvider.googlePlacesApiKey;
      if (apiKey != null && apiKey.isNotEmpty) {
        final enriched =
            await poiProvider.fetchPlaceDetails(widget.poi, apiKey);
        if (mounted) {
          setState(() {
            _enrichedPOI = enriched;
          });
        }
      }
    } catch (e) {
      // Silently fail - user still sees basic POI info
    }
  }

  POI get _currentPOI => _enrichedPOI ?? widget.poi;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    if (_currentPOI.rating != null ||
                        _currentPOI.isOpenNow != null)
                      _buildRatingAndStatus(context),
                    _buildActionButtons(context),
                    if (_currentPOI.type.category == POICategory.commercial)
                      _buildReminderSection(context),
                    const Divider(height: 1),
                    if (_currentPOI.wikipediaTitle != null)
                      _buildWikipediaContent(context),
                    if (_currentPOI.description != null)
                      _buildDescription(context),
                    _buildMetadata(context),
                    _buildSourceAttribution(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Loading overlay when performing operations
        if (_isOperationInProgress)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Updating shopping list...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
          tooltip: 'Settings',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _currentPOI.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(128, 0, 0, 0),
              ),
            ],
          ),
        ),
        background: _buildHeaderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.place,
        size: 80,
        color: Colors.grey[500],
      ),
    );
  }

  /// Build header image with priority: poi.imageUrl > Wikipedia thumbnail > placeholder
  Widget _buildHeaderImage() {
    // Priority 1: Use poi.imageUrl if available (from Google Places)
    if (_currentPOI.imageUrl != null) {
      return Image.network(
        _currentPOI.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    }

    // Priority 2: Use Wikipedia thumbnail if available
    if (_currentPOI.wikipediaTitle != null) {
      return Consumer<WikipediaProvider>(
        builder: (context, provider, child) {
          final content = provider.getContent(_currentPOI.wikipediaTitle!);
          if (content?.thumbnailUrl != null) {
            return Image.network(
              content!.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            );
          }
          return _buildPlaceholderImage();
        },
      );
    }

    // Priority 3: Use placeholder
    return _buildPlaceholderImage();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _currentPOI.type.displayName,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${formatDistance(_currentPOI.distanceFromCity)} away',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.star,
                size: 18,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Notability Score: ${_currentPOI.notabilityScore}/100',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingAndStatus(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_currentPOI.rating != null) ...[
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[700], size: 24),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPOI.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentPOI.userRatingsTotal != null)
                        Text(
                          '${_currentPOI.userRatingsTotal} reviews',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_currentPOI.isOpenNow != null) ...[
            if (_currentPOI.rating != null)
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
            Expanded(
              child: Row(
                children: [
                  Icon(
                    _currentPOI.isOpenNow! ? Icons.check_circle : Icons.cancel,
                    color: _currentPOI.isOpenNow! ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentPOI.isOpenNow! ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _currentPOI.isOpenNow!
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_currentPOI.priceLevel != null) ...[
            if (_currentPOI.rating != null || _currentPOI.isOpenNow != null)
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
            Row(
              children: List.generate(
                4,
                (index) => Icon(
                  Icons.attach_money,
                  size: 18,
                  color: index < _currentPOI.priceLevel!
                      ? Colors.green[700]
                      : Colors.grey[300],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isCommercial = _currentPOI.type.category == POICategory.commercial;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showOnMap(context),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Show on Map'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _getDirections(),
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
              ),
            ],
          ),
          if (isCommercial) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAllLocations(context),
                icon: const Icon(Icons.store_mall_directory),
                label: const Text('Show all locations'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderSection(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, reminderProvider, child) {
        final brandName = BrandMatcher.extractBrand(_currentPOI.name);
        if (brandName == null) return const SizedBox.shrink();

        final reminder = reminderProvider.getReminderForBrand(brandName);
        final hasReminder = reminder != null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasReminder)
                  // Add reminder button
                  ListTile(
                    leading:
                        const Icon(Icons.shopping_cart, color: Colors.blue),
                    title: const Text('Add Shopping Reminder'),
                    subtitle: Text('Get notified at any $brandName store'),
                    trailing: const Icon(Icons.add),
                    onTap: () => _createReminder(context, brandName),
                  )
                else
                  // Reminder card
                  Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.shopping_cart,
                          color: Colors.green[700],
                        ),
                        title: Text('Shopping List for $brandName'),
                        subtitle: Text(
                          '${reminder.items.where((i) => !i.isChecked).length} items',
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            _isReminderExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() {
                              _isReminderExpanded = !_isReminderExpanded;
                            });
                          },
                        ),
                      ),
                      if (_isReminderExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Shopping list
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: reminder.items.length,
                                itemBuilder: (context, index) {
                                  final item = reminder.items[index];
                                  return CheckboxListTile(
                                    value: item.isChecked,
                                    onChanged: (checked) async {
                                      setState(() {
                                        _isOperationInProgress = true;
                                      });

                                      try {
                                        final scaffoldMessenger =
                                            ScaffoldMessenger.of(context);
                                        final success =
                                            await reminderProvider.toggleItem(
                                          reminder.id,
                                          item.id,
                                        );
                                        if (success && mounted) {
                                          // Check if all items are now checked
                                          if (checked == true &&
                                              reminder.items.length == 1) {
                                            PermissionDialogHelper
                                                .showReminderAutoRemovedMessageWithMessenger(
                                              scaffoldMessenger,
                                              brandName,
                                            );
                                          }
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isOperationInProgress = false;
                                          });
                                        }
                                      }
                                    },
                                    title: Text(
                                      item.text,
                                      style: TextStyle(
                                        decoration: item.isChecked
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    secondary: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20),
                                      onPressed: () async {
                                        setState(() {
                                          _isOperationInProgress = true;
                                        });

                                        try {
                                          await reminderProvider.removeItem(
                                            reminder.id,
                                            item.id,
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isOperationInProgress = false;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              // Add new item
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _newItemController,
                                      decoration: const InputDecoration(
                                        hintText: 'Add item...',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onSubmitted: (text) async {
                                        if (text.trim().isNotEmpty) {
                                          setState(() {
                                            _isOperationInProgress = true;
                                          });

                                          try {
                                            await reminderProvider.addItem(
                                              reminder.id,
                                              text.trim(),
                                            );
                                            _newItemController.clear();
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _isOperationInProgress = false;
                                              });
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    color: Colors.blue,
                                    onPressed: () async {
                                      final text =
                                          _newItemController.text.trim();
                                      if (text.isNotEmpty) {
                                        setState(() {
                                          _isOperationInProgress = true;
                                        });

                                        try {
                                          await reminderProvider.addItem(
                                            reminder.id,
                                            text,
                                          );
                                          _newItemController.clear();
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isOperationInProgress = false;
                                            });
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Remove reminder button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('Remove Reminder?'),
                                        content: Text(
                                          'Remove shopping reminder for $brandName?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true && mounted) {
                                      setState(() {
                                        _isOperationInProgress = true;
                                      });

                                      try {
                                        final success = await reminderProvider
                                            .removeReminder(
                                          reminder.id,
                                        );
                                        if (success && mounted) {
                                          PermissionDialogHelper
                                              .showReminderRemovedMessageWithMessenger(
                                            scaffoldMessenger,
                                            brandName,
                                          );
                                          setState(() {
                                            _isReminderExpanded = false;
                                          });
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isOperationInProgress = false;
                                          });
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Remove Reminder'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createReminder(BuildContext context, String brandName) async {
    final reminderProvider = Provider.of<ReminderProvider>(
      context,
      listen: false,
    );

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    // Capture context-dependent values before any async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Check if this is the first reminder
    final isFirstReminder = !reminderProvider.hasReminders;

    if (isFirstReminder) {
      final permissionsGranted = await _requestAllPermissions();
      if (!permissionsGranted) return;
    }

    // Show dialog to add initial shopping items
    if (!mounted) return;
    final items = await navigator.push<List<String>>(
      MaterialPageRoute(
        builder: (dialogContext) => _ShoppingListDialog(brandName: brandName),
        fullscreenDialog: true,
      ),
    );

    if (items == null || items.isEmpty) return;

    // Get all available POIs to find brand matches
    final poiProvider = Provider.of<POIProvider>(context, listen: false);

    // Create the reminder
    final success = await reminderProvider.addReminder(
      _currentPOI,
      items,
      allAvailablePOIs: poiProvider.allPois,
    );
    if (!mounted) return;

    if (success) {
      PermissionDialogHelper.showReminderCreatedMessageWithMessenger(
          scaffoldMessenger, brandName);
      setState(() {
        _isReminderExpanded = true;
      });

      // Enable background location monitoring in settings
      if (isFirstReminder) {
        await settingsProvider.updateBackgroundLocationEnabled(true);

        // Request battery optimization exemption on Android
        if (!mounted) return;
        await _requestBatteryOptimizationExemption();
      }
    } else {
      PermissionDialogHelper.showErrorWithMessenger(
        scaffoldMessenger,
        reminderProvider.error ?? 'Failed to create reminder',
      );
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    if (!mounted) return;
    await BatteryOptimizationHelper.requestBatteryOptimizationExemption(
        context);
  }

  Future<bool> _requestAllPermissions() async {
    if (!mounted) return false;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final locationService = LocationMonitorService();

    // Step 1: Check and request foreground location permission
    bool foregroundGranted = await locationService.hasPermission();
    if (!mounted) return false;

    if (!foregroundGranted) {
      final allowedForeground =
          await PermissionDialogHelper.showForegroundLocationRationale(context);
      if (!allowedForeground) return false;

      foregroundGranted = await locationService.requestForegroundPermission();
      if (!mounted) return false;

      if (!foregroundGranted) {
        PermissionDialogHelper.showErrorWithMessenger(
          scaffoldMessenger,
          'Location permission is required for reminders. Please enable location services in device settings and grant location permission.',
        );
        return false;
      }
    }

    // Step 2: Check and request background location permission (Android 10+)
    bool backgroundGranted = await locationService.hasBackgroundPermission();
    if (!mounted) return false;

    if (!backgroundGranted) {
      final allowedBg =
          await PermissionDialogHelper.showBackgroundLocationRationale(context);
      if (!allowedBg) return false;

      backgroundGranted = await locationService.requestBackgroundPermission();
      if (!mounted) return false;

      if (!backgroundGranted) {
        PermissionDialogHelper.showErrorWithMessenger(
          scaffoldMessenger,
          'Background location permission is required for reminders. Please select "Allow all the time" in the permission dialog.',
        );
        return false;
      }
    }

    // Step 3: Check and request notification permission
    final notificationService = NotificationService();

    final allowedNotif =
        await PermissionDialogHelper.showNotificationRationale(context);
    if (!allowedNotif) return false;

    final notifGranted = await notificationService.requestPermission();
    if (!mounted) return false;

    if (!notifGranted) {
      PermissionDialogHelper.showErrorWithMessenger(
        scaffoldMessenger,
        'Notification permission is required for reminders',
      );
      return false;
    }

    return true;
  }

  Widget _buildWikipediaContent(BuildContext context) {
    return Consumer<WikipediaProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final content = provider.getContent(widget.poi.wikipediaTitle!);
        if (content == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                content.summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _launchUrl(content.pageUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Read more on Wikipedia'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentPOI.description!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final hasMetadata = _currentPOI.website != null ||
        _currentPOI.openingHours != null ||
        _currentPOI.wikidataId != null ||
        _currentPOI.formattedAddress != null ||
        _currentPOI.formattedPhoneNumber != null;

    if (!hasMetadata) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (_currentPOI.formattedAddress != null) ...[
            _buildMetadataRow(
              context,
              Icons.location_on,
              'Address',
              _currentPOI.formattedAddress!,
            ),
            const SizedBox(height: 12),
          ],
          if (_currentPOI.formattedPhoneNumber != null) ...[
            _buildMetadataLink(
              context,
              Icons.phone,
              'Phone',
              'tel:${_currentPOI.formattedPhoneNumber!}',
              displayText: _currentPOI.formattedPhoneNumber!,
            ),
            const SizedBox(height: 12),
          ],
          if (_currentPOI.openingHours != null) ...[
            _buildMetadataRow(
              context,
              Icons.access_time,
              'Opening Hours',
              _currentPOI.openingHours!,
            ),
            const SizedBox(height: 12),
          ],
          if (_currentPOI.website != null) ...[
            _buildMetadataLink(
              context,
              Icons.language,
              'Website',
              _currentPOI.website!,
            ),
            const SizedBox(height: 12),
          ],
          if (_currentPOI.wikidataId != null) ...[
            _buildMetadataRow(
              context,
              Icons.storage,
              'Wikidata ID',
              _currentPOI.wikidataId!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataLink(
      BuildContext context, IconData icon, String label, String url,
      {String? displayText}) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayText ?? url,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
        ],
      ),
    );
  }

  Widget _buildSourceAttribution(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Sources',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final source in _currentPOI.sources)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSourceIcon(source.name),
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getSourceDisplayName(source.name),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSourceIcon(String sourceName) {
    switch (sourceName) {
      case 'Wikipedia Geosearch':
        return Icons.article;
      case 'OpenStreetMap Overpass':
        return Icons.map;
      case 'Wikidata':
        return Icons.storage;
      default:
        return Icons.info;
    }
  }

  String _getSourceDisplayName(String sourceName) {
    switch (sourceName) {
      case 'Wikipedia Geosearch':
        return 'Wikipedia';
      case 'OpenStreetMap Overpass':
        return 'OpenStreetMap';
      case 'Wikidata':
        return 'Wikidata';
      default:
        return sourceName;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Show POI on map by switching to map tab and centering
  void _showOnMap(BuildContext context) {
    final mapNavProvider = Provider.of<MapNavigationProvider>(
      context,
      listen: false,
    );
    mapNavProvider.navigateToPoiOnMap(widget.poi);
    Navigator.pop(context); // Return to previous screen
  }

  /// Open native routing app with directions to POI
  Future<void> _getDirections() async {
    final lat = _currentPOI.latitude;
    final lng = _currentPOI.longitude;
    // Use platform-agnostic geo: URI scheme that works on both iOS and Android
    final url = 'geo:0,0?q=$lat,$lng';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web URL if geo: scheme is not supported
        final fallbackUrl =
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';
        final fallbackUri = Uri.parse(fallbackUrl);
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching directions: $e');
    }
  }

  /// Show all locations matching this POI's name on the map
  void _showAllLocations(BuildContext context) {
    final mapNavProvider = Provider.of<MapNavigationProvider>(
      context,
      listen: false,
    );
    // Navigate to map filtered by this POI's name
    mapNavProvider.navigateToMapWithFilter(widget.poi.name);
    Navigator.pop(context); // Return to previous screen
  }
}

/// Dialog for creating initial shopping list
class _ShoppingListDialog extends StatefulWidget {
  final String brandName;

  const _ShoppingListDialog({required this.brandName});

  @override
  State<_ShoppingListDialog> createState() => _ShoppingListDialogState();
}

class _ShoppingListDialogState extends State<_ShoppingListDialog> {
  final List<String> _items = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _items.add(text);
      });
      _controller.clear();
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Shopping List for ${widget.brandName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add item field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Add item...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Colors.blue,
                  onPressed: _addItem,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Items list
            if (_items.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_items[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeItem(index),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Add items to your shopping list',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _items.isEmpty ? null : () => Navigator.pop(context, _items),
          child: const Text('Create Reminder'),
        ),
      ],
    );
  }
}

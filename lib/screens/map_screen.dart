import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/location.dart';
import '../models/poi.dart';
import '../models/reminder.dart';
import '../providers/ai_guidance_provider.dart';
import '../providers/location_provider.dart';
import '../providers/poi_provider.dart';
import '../providers/map_navigation_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/string_utils.dart';
import '../widgets/geofence_debug_overlay.dart';
import 'poi_detail_screen.dart';
import 'settings_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Location? _previousLocation;
  double _currentZoom = 13.0;
  bool _showGeofenceDebug = false;

  @override
  void initState() {
    super.initState();
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventFlingAnimationEnd) {
        setState(() {
          _currentZoom = _mapController.camera.zoom;
        });
      }
    });

    // Listen for map navigation requests
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToMapNavigation();
    });
  }

  /// Listen for POI navigation requests and center map
  void _listenToMapNavigation() {
    final mapNavProvider = Provider.of<MapNavigationProvider>(
      context,
      listen: false,
    );

    mapNavProvider.addListener(() {
      if (mapNavProvider.shouldNavigate) {
        if (mapNavProvider.targetPOI != null) {
          final poi = mapNavProvider.targetPOI!;
          // Center map on POI with higher zoom level
          _mapController.move(
            LatLng(poi.latitude, poi.longitude),
            16.0, // Closer zoom for individual POI
          );
        } else if (mapNavProvider.nameFilter != null) {
          // For name filter, just center on the selected city with medium zoom
          final locationProvider = Provider.of<LocationProvider>(
            context,
            listen: false,
          );
          if (locationProvider.selectedCity != null) {
            final city = locationProvider.selectedCity!;
            _mapController.move(
              LatLng(city.latitude, city.longitude),
              14.0, // Medium zoom to see multiple locations
            );
          }
        }
        // Clear navigation request
        mapNavProvider.clearNavigation();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Truncates text with ellipsis if too long
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Creates a marker for a POI
  Marker _createPOIMarker(POI poi) {
    final bool showLabel =
        _currentZoom >= 13.0; // Lower threshold to show labels earlier
    final double iconSize = 30.0;
    final color = poi.type.color;

    return Marker(
      point: LatLng(poi.latitude, poi.longitude),
      width: showLabel ? 140 : iconSize,
      height: showLabel ? 60 : iconSize,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => POIDetailScreen(poi: poi),
            ),
          );
        },
        child: showLabel
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    poi.type.icon,
                    color: color,
                    size: iconSize,
                    shadows: const [
                      Shadow(
                        blurRadius: 3,
                        color: Colors.black45,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: color,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      _truncateText(poi.name, 18),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : Icon(
                poi.type.icon,
                color: color,
                size: iconSize,
                shadows: const [
                  Shadow(
                    blurRadius: 3,
                    color: Colors.black45,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
      ),
    );
  }

  /// Creates a marker for the city center
  Marker _createCityMarker(Location location) {
    final String cityName = location.name ?? 'Current Location';
    final bool showLabel = _currentZoom >= 11.0;

    return Marker(
      point: LatLng(location.latitude, location.longitude),
      width: showLabel ? 150 : 40,
      height: showLabel ? 70 : 40,
      child: showLabel
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_city,
                  color: Colors.blueAccent,
                  size: 40,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    _truncateText(cityName, 18),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : const Icon(
              Icons.location_city,
              color: Colors.blueAccent,
              size: 40,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black54,
                  offset: Offset(1, 1),
                ),
              ],
            ),
    );
  }

  /// Auto-recenters map when location changes
  void _handleLocationChange(Location? newLocation) {
    if (newLocation != null && newLocation != _previousLocation) {
      _previousLocation = newLocation;

      // Animate map to new location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(newLocation.latitude, newLocation.longitude),
          13.0, // Zoom level for city view
        );
      });
    }
  }

  /// Get geofence circle markers for debug visualization
  List<CircleMarker> _getGeofenceCircles(
      List<Reminder> reminders, double proximityRadius) {
    return reminders.map((reminder) {
      return CircleMarker(
        point: LatLng(reminder.latitude, reminder.longitude),
        radius: proximityRadius,
        color: Colors.blue.withOpacity(0.15),
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
      ),
      body: Consumer5<LocationProvider, POIProvider, AIGuidanceProvider, SettingsProvider, ReminderProvider>(
        builder: (context, locationProvider, poiProvider, aiGuidanceProvider, settingsProvider, reminderProvider, child) {
          final selectedCity = locationProvider.selectedCity;

          // Auto-recenter when location changes
          _handleLocationChange(selectedCity);

          // No city selected - show empty state
          if (selectedCity == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No city selected',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for a city in the Search tab',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          // Build list of markers
          final List<Marker> markers = [];

          // Add city center marker
          markers.add(_createCityMarker(selectedCity));

          // Calculate filtered POIs (same logic as POIListWidget)
          List<POI> poisToShow = [];
          if (!poiProvider.isLoading && poiProvider.error == null) {
            // Check if we should filter by name (from MapNavigationProvider)
            final mapNavProvider = Provider.of<MapNavigationProvider>(context);
            final nameFilter = mapNavProvider.nameFilter;

            // Start with all POIs
            poisToShow = poiProvider.allPois.toList();

            // Apply AI guidance filter first (same as POIListWidget)
            if (aiGuidanceProvider.hasActiveGuidance) {
              poisToShow = poisToShow
                  .where((poi) => aiGuidanceProvider.isPoiMatchingGuidance(poi))
                  .toList();
            }

            // Apply search query filter (from POIProvider)
            final searchQuery = poiProvider.searchQuery;
            if (searchQuery.isNotEmpty) {
              poisToShow = poisToShow.where((poi) {
                return matchesSearch(poi.name, searchQuery);
              }).toList();
            }

            // Apply type filters (from POIProvider)
            if (poiProvider.selectedFilters.isNotEmpty) {
              poisToShow = poisToShow
                  .where((poi) => poiProvider.selectedFilters.contains(poi.type))
                  .toList();
            }

            // Apply name filter if present (for "Show all locations")
            if (nameFilter != null && nameFilter.isNotEmpty) {
              poisToShow = poisToShow
                  .where((poi) => matchesSearch(poi.name, nameFilter))
                  .toList();
            }

            for (final poi in poisToShow) {
              markers.add(_createPOIMarker(poi));
            }
          }

          // Get geofence circles if debug mode enabled
          final geofenceCircles = _showGeofenceDebug 
              ? _getGeofenceCircles(
                  reminderProvider.reminders,
                  settingsProvider.proximityRadiusMeters.toDouble(),
                ) 
              : <CircleMarker>[];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    selectedCity.latitude,
                    selectedCity.longitude,
                  ),
                  initialZoom: 13.0,
                  minZoom: 3.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.travel_flutter_app',
                    maxZoom: 19,
                  ),
                  if (_showGeofenceDebug && geofenceCircles.isNotEmpty)
                    CircleLayer(
                      circles: geofenceCircles,
                    ),
                  MarkerLayer(
                    markers: markers,
                  ),
                ],
              ),

              // Loading indicator overlay
              if (poiProvider.isLoading)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              poiProvider.isLoadingPhase1
                                  ? 'Loading POIs...'
                                  : 'Loading more POIs...',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Error banner
              if (poiProvider.error != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              poiProvider.error!,
                              style: TextStyle(color: Colors.red[900]),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: () {
                              // Retry loading POIs
                              poiProvider.discoverPOIs(selectedCity);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Crosshair at map center
              const Center(
                child: IgnorePointer(
                  child: Icon(
                    Icons.add,
                    size: 28,
                    color: Colors.black54,
                  ),
                ),
              ),

              // Set location from map center button
              Positioned(
                top: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: locationProvider.isLoading
                        ? null
                        : () async {
                            final center = _mapController.camera.center;
                            // Clear POI cache before setting new location
                            poiProvider.clearCache();
                            await locationProvider.setLocationFromMapCenter(
                              center.latitude,
                              center.longitude,
                            );
                            // Force refresh POIs for the new location
                            if (locationProvider.selectedCity != null) {
                              poiProvider.discoverPOIs(
                                locationProvider.selectedCity!,
                                forceRefresh: true,
                              );
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: locationProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.my_location, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Set Location Here',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              // Map legend
              Positioned(
                bottom: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_city,
                                color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 8),
                            const Text('City Center',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text(
                                'POIs (${poisToShow.length})',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        if (_currentZoom < 13.0) ...[
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.blue, size: 18),
                              SizedBox(width: 8),
                              Text('Zoom in to see labels',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Geofence debug overlay
              GeofenceDebugOverlay(
                showDebug: _showGeofenceDebug,
                onToggleDebug: () {
                  setState(() {
                    _showGeofenceDebug = !_showGeofenceDebug;
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

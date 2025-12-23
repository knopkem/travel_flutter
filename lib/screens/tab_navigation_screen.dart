import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import 'home_screen.dart';
import 'map_screen.dart';

class TabNavigationScreen extends StatefulWidget {
  const TabNavigationScreen({super.key});

  @override
  State<TabNavigationScreen> createState() => _TabNavigationScreenState();
}

class _TabNavigationScreenState extends State<TabNavigationScreen> {
  int _currentIndex = 0;
  bool _canGoBack = false;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    // Update back button visibility and initialize GPS when navigation changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBackButtonVisibility();
      _initializeGPS();
      _listenToMapNavigation();
    });
  }

  /// Listen for map navigation requests from POI detail screen or list
  void _listenToMapNavigation() {
    final mapNavProvider = Provider.of<MapNavigationProvider>(
      context,
      listen: false,
    );

    mapNavProvider.addListener(() {
      if (mapNavProvider.shouldNavigate && mounted) {
        // Switch to map tab
        setState(() {
          _currentIndex = 1;
        });
      }
    });
  }

  /// Initializes GPS location fetch at startup.
  ///
  /// Silently attempts to get the user's current location and set it as
  /// the selected city. Any errors are stored in the LocationProvider
  /// for display in the GPS button (error state).
  void _initializeGPS() {
    if (!mounted) return;

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Trigger GPS fetch - errors will be shown in GPS button
    locationProvider.fetchCurrentLocation(context);
  }

  void _updateBackButtonVisibility() {
    final navigator = _navigatorKeys[_currentIndex].currentState;
    if (navigator != null) {
      setState(() {
        _canGoBack = navigator.canPop();
      });
    }
  }

  Future<bool> _onWillPop() async {
    final isFirstRouteInCurrentTab =
        !await _navigatorKeys[_currentIndex].currentState!.maybePop();

    if (isFirstRouteInCurrentTab) {
      // If on first route of current tab, switch to Search tab
      if (_currentIndex != 0) {
        setState(() {
          _currentIndex = 0;
        });
        return false;
      }
    }

    return isFirstRouteInCurrentTab;
  }

  Widget _buildNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [
        _NavigatorObserver(
          onNavigationChange: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateBackButtonVisibility();
            });
          },
        ),
      ],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) => child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildNavigator(0, const HomeScreen()),
            _buildNavigator(1, const MapScreen()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_canGoBack && index == 2) {
              // Back button tapped
              _navigatorKeys[_currentIndex].currentState!.maybePop().then((_) {
                _updateBackButtonVisibility();
              });
            } else if (index < 2) {
              setState(() {
                _currentIndex = index;
              });
              _updateBackButtonVisibility();
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _canGoBack ? Icons.arrow_back : Icons.more_horiz,
                color: _canGoBack ? null : Colors.transparent,
              ),
              label: _canGoBack ? 'Back' : '',
            ),
          ],
        ),
      ),
    );
  }
}

/// Observer to track navigation changes and update back button visibility
class _NavigatorObserver extends NavigatorObserver {
  final VoidCallback onNavigationChange;

  _NavigatorObserver({required this.onNavigationChange});

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    onNavigationChange();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    onNavigationChange();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    onNavigationChange();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onNavigationChange();
  }
}

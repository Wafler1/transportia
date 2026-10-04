import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/nav_destination.dart';
import '../models/tab_bar_item.dart';
import '../providers/theme_provider.dart';
import '../utils/custom_page_route.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/pushed_screen_back_overlay.dart';
import 'map_screen.dart';
import 'saved_trips_screen.dart';
import 'timetables_screen.dart';
import 'user_screen.dart';
import '../services/transitous_geocode_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  NavDestination _currentDestination = NavDestination.main;
  TransitousLocationSuggestion? _pendingTimetableStop;
  final ValueNotifier<bool> _mapCollapsedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _mapCollapseProgressNotifier =
      ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _overlaysVisibleNotifier = ValueNotifier<bool>(
    false,
  );

  /// Always Main first and Settings last (never configurable); Departures
  /// and Saved trips appear in between only if enabled as a tab.
  List<NavDestination> _tabsFor(ThemeProvider? theme) {
    final items = theme?.tabBarItems ?? TabBarItemConfig.defaults;
    bool isTab(TabBarItem item) {
      for (final config in items) {
        if (config.item == item) return config.enabledAsTab;
      }
      return false;
    }

    return [
      NavDestination.main,
      if (isTab(TabBarItem.departures)) NavDestination.departures,
      if (isTab(TabBarItem.savedTrips)) NavDestination.savedTrips,
      NavDestination.settings,
    ];
  }

  void _onNavIndexChanged(int index, List<NavDestination> tabs) {
    if (index < 0 || index >= tabs.length) return;
    final destination = tabs[index];
    if (destination != _currentDestination) {
      setState(() => _currentDestination = destination);
    }
  }

  /// Switches to [destination] if it's currently a tab; otherwise pushes it
  /// as a standalone screen (with a back affordance, since these screens
  /// normally rely on being tab-hosted for that). The single place that
  /// implements "gets a settings link/entry instead."
  void _goTo(NavDestination destination, List<NavDestination> tabs) {
    if (tabs.contains(destination)) {
      _onNavIndexChanged(tabs.indexOf(destination), tabs);
      return;
    }
    switch (destination) {
      case NavDestination.departures:
        Navigator.of(context).push(
          CustomPageRoute(
            child: PushedScreenBackOverlay(
              child: TimetablesScreen(initialStop: _pendingTimetableStop),
            ),
          ),
        );
      case NavDestination.savedTrips:
        Navigator.of(context).push(
          CustomPageRoute(
            child: const PushedScreenBackOverlay(child: SavedTripsScreen()),
          ),
        );
      case NavDestination.main:
      case NavDestination.settings:
        break; // always tabs; never reached via this branch
    }
  }

  void _handleTimetableRequested(TransitousLocationSuggestion stop) {
    setState(() => _pendingTimetableStop = stop);
    _goTo(NavDestination.departures, _tabsFor(ThemeProvider.instance));
  }

  bool _handleBackGesture() {
    if (_currentDestination != NavDestination.main) {
      setState(() => _currentDestination = NavDestination.main);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _mapCollapsedNotifier.dispose();
    _mapCollapseProgressNotifier.dispose();
    _overlaysVisibleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final tabs = _tabsFor(themeProvider);
    final rawIndex = tabs.indexOf(_currentDestination);
    final currentIndex = rawIndex == -1 ? 0 : rawIndex;

    final children = tabs.map<Widget>((destination) {
      switch (destination) {
        case NavDestination.main:
          return MapScreen(
            onCollapseChanged: (isCollapsed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapCollapsedNotifier.value = isCollapsed;
              });
            },
            onCollapseProgressChanged: (progress) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapCollapseProgressNotifier.value = progress;
              });
            },
            onOverlayVisibilityChanged: (overlaysVisible) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _overlaysVisibleNotifier.value = overlaysVisible;
              });
            },
            onTabChangeRequested: (dest) => _goTo(dest, tabs),
            onTimetableRequested: _handleTimetableRequested,
          );
        case NavDestination.departures:
          return TimetablesScreen(initialStop: _pendingTimetableStop);
        case NavDestination.savedTrips:
          return const SavedTripsScreen();
        case NavDestination.settings:
          return const AccountScreen();
      }
    }).toList();

    final icons = tabs.map((destination) {
      switch (destination) {
        case NavDestination.main:
          return LucideIcons.mapPinned;
        case NavDestination.departures:
          return LucideIcons.clock;
        case NavDestination.savedTrips:
          return LucideIcons.bookmark;
        case NavDestination.settings:
          return LucideIcons.user;
      }
    }).toList();

    return PopScope(
      canPop: _currentDestination == NavDestination.main,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackGesture();
        }
      },
      child: Stack(
        children: [
          IndexedStack(index: currentIndex, children: children),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: ValueListenableBuilder<double>(
                valueListenable: _mapCollapseProgressNotifier,
                builder: (context, progress, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _overlaysVisibleNotifier,
                    builder: (context, overlaysVisible, child) {
                      const double hideStart = 0.6;
                      const double hideEnd = 0.9;

                      double visibility = 1.0;
                      if (_currentDestination == NavDestination.main) {
                        if (overlaysVisible) {
                          visibility = 0.0;
                        } else {
                          if (progress <= hideStart) {
                            visibility = 1.0;
                          } else if (progress >= hideEnd) {
                            visibility = 0.0;
                          } else {
                            final t =
                                (progress - hideStart) / (hideEnd - hideStart);
                            visibility = 1.0 - Curves.easeInOut.transform(t);
                          }
                        }
                      }

                      return FloatingNavBar(
                        currentIndex: currentIndex,
                        icons: icons,
                        onIndexChanged: (index) =>
                            _onNavIndexChanged(index, tabs),
                        visibility: visibility,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

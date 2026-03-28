import 'package:flutter/cupertino.dart';
import '../widgets/floating_nav_bar.dart';
import 'map_screen.dart';
import 'timetables_screen.dart';
import 'user_screen.dart';
import '../services/transitous_geocode_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  TransitousLocationSuggestion? _pendingTimetableStop;
  final ValueNotifier<bool> _mapCollapsedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _mapCollapseProgressNotifier =
      ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _overlaysVisibleNotifier = ValueNotifier<bool>(
    false,
  );

  void _onNavIndexChanged(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _handleTimetableRequested(TransitousLocationSuggestion stop) {
    setState(() {
      _pendingTimetableStop = stop;
      _currentIndex = 1;
    });
  }

  bool _handleBackGesture() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
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
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackGesture();
        }
      },
      child: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              MapScreen(
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
                onTabChangeRequested: _onNavIndexChanged,
                onTimetableRequested: _handleTimetableRequested,
              ),
              TimetablesScreen(initialStop: _pendingTimetableStop),
              const AccountScreen(),
            ],
          ),

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
                      if (_currentIndex == 0) {
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
                        currentIndex: _currentIndex,
                        onIndexChanged: _onNavIndexChanged,
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

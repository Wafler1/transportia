import 'package:flutter/cupertino.dart';
import '../widgets/floating_nav_bar.dart';
import 'map_screen.dart';
import 'timetables_screen.dart';
import 'user_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _mapCollapsedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _mapCollapseProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _overlaysVisibleNotifier = ValueNotifier<bool>(false);

  void _onNavIndexChanged(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  bool _handleBackGesture() {
    // If not on map screen, navigate to map screen
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false; // Prevent default back behavior
    }
    return true; // Allow default back behavior (exit app)
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
      canPop: _currentIndex == 0, // Only allow popping when on map screen
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Back gesture was invoked but pop was prevented
          _handleBackGesture();
        }
      },
      child: Stack(
        children: [
          // Screen content
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
              ),
              const TimetablesScreen(),
              const AccountScreen(),
            ],
          ),

        // Floating navigation bar
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
                    // Calculate navbar visibility based on drag progress
                    // Start hiding at 0.6 (trigger point), fully hidden at 0.9
                    const double hideStart = 0.6;
                    const double hideEnd = 0.9;

                    double visibility = 1.0;
                    if (_currentIndex == 0) {
                      // Hide navbar when overlays are visible
                      if (overlaysVisible) {
                        visibility = 0.0;
                      } else {
                        // Apply drag-based animation when on map screen
                        if (progress <= hideStart) {
                          visibility = 1.0; // Fully visible
                        } else if (progress >= hideEnd) {
                          visibility = 0.0; // Fully hidden
                        } else {
                          // Smooth transition between trigger points
                          final t = (progress - hideStart) / (hideEnd - hideStart);
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

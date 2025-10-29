import 'package:flutter/cupertino.dart';
import '../widgets/floating_nav_bar.dart';
import 'map_screen.dart';
import 'timetables_screen.dart';
import 'account_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ValueNotifier<bool> _mapCollapsedNotifier = ValueNotifier<bool>(false);

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
            child: ValueListenableBuilder<bool>(
              valueListenable: _mapCollapsedNotifier,
              builder: (context, mapCollapsed, child) {
                // Hide nav bar when on map screen AND sheet is collapsed
                final shouldHide = _currentIndex == 0 && mapCollapsed;
                // Use smooth animated visibility
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  opacity: shouldHide ? 0.0 : 1.0,
                  child: FloatingNavBar(
                    currentIndex: _currentIndex,
                    onIndexChanged: _onNavIndexChanged,
                    visibility: shouldHide ? 0.0 : 1.0, // Pass the direct visibility state
                  ),
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

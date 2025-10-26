import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vibration/vibration.dart';
import 'map_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _kWelcomeSeenKey = 'welcome_seen_v1';

  Future<void> _onSkip(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeSeenKey, true);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MapScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: SafeArea(
        child: SizedBox.expand(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    child: Image.asset(
                      "assets/images/welcome-image.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Welcome to Entaria, \na free transportation app",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF000000),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "With Entaria, you can find your way \nfrom one city to another easily.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xA3000000),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PressableHighlight(
                    onPressed: () => _onSkip(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Let's go",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 0, 113, 133),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: Color.fromARGB(255, 0, 113, 133),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableHighlight extends StatefulWidget {
  const _PressableHighlight({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_PressableHighlight> createState() => _PressableHighlightState();
}

class _PressableHighlightState extends State<_PressableHighlight> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  Future<void> _vibrateSubtle() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) return;
      final custom = await Vibration.hasCustomVibrationsSupport();
      if (custom) {
        // Very short, low amplitude pulse (Android API 26+ respects amplitude).
        await Vibration.vibrate(pattern: [0, 100, 25, 100],
                                intensities: [0, 100, 0, 250]);
      } else {
        await Vibration.vibrate(duration: 100);
      }
    } catch (_) {
      // Ignore vibration errors (e.g., unsupported platform).
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Trigger a subtle vibration and then invoke callback.
        _vibrateSubtle();
        widget.onPressed();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _pressed
              // Semi-transparent tint of the accent color
              ? const Color.fromARGB(38, 0, 113, 133) // ~15% opacity
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(32),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: widget.child,
      ),
    );
  }
}

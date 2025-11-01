import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/pressable_highlight.dart';
import '../theme/app_colors.dart';
import 'map_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const _kWelcomeSeenKey = 'welcome_seen_v1';

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _activateMap = ValueNotifier<bool>(false);
  bool _fading = false;
  bool _overlayGone = false;

  Future<void> _onContinue() async {
    // Persist that welcome has been seen, then fade overlay away.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WelcomeScreen._kWelcomeSeenKey, true);
    if (!mounted) return;
    setState(() => _fading = true);
  }

  @override
  void dispose() {
    _activateMap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Pre-mount the map behind; defer its location init until revealed.
        RepaintBoundary(
          child: MapScreen(deferInit: true, activateOnShow: _activateMap),
        ),

        // Welcome overlay that fades out, then gets removed.
        if (!_overlayGone)
          AnimatedOpacity(
            opacity: _fading ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 690),
            curve: Curves.easeOutCubic,
            onEnd: () {
              if (_fading && mounted) {
                // Activate the map's deferred init once the overlay is gone.
                _activateMap.value = true;
                setState(() => _overlayGone = true);
              }
            },
            child: AnimatedScale(
              scale: _fading ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 690),
              curve: Curves.easeOutCubic,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _fading ? 8.0 : 0.0),
                duration: const Duration(milliseconds: 690),
                curve: Curves.easeOutCubic,
                builder: (context, sigma, child) => ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                  ),
                  child: child,
                ),
                child: ColoredBox(
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
                                  color: AppColors.black,
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
                              PressableHighlight(
                                onPressed: _onContinue,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Let's go",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.accentOf(context),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      LucideIcons.chevronRight,
                                      size: 20,
                                      color: AppColors.accentOf(context),
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
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// PressableHighlight moved to lib/widgets/pressable_highlight.dart

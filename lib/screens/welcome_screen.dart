import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../environment.dart';
import '../constants/prefs_keys.dart';
import '../widgets/pressable_highlight.dart';
import '../widgets/validation_toast.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import 'map_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onFinished});

  static const _kWelcomeSeenKey = PrefsKeys.welcomeSeen;
  final VoidCallback? onFinished;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _activateMap = ValueNotifier<bool>(false);
  bool _fading = false;
  bool _overlayGone = false;
  late final TapGestureRecognizer _privacyTapRecognizer;
  late final TapGestureRecognizer _termsTapRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(Environment.privacyUrl);
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(Environment.termsUrl);
  }

  Future<void> _onContinue() async {
    // Persist that welcome has been seen, then fade overlay away.
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(WelcomeScreen._kWelcomeSeenKey, true);
    if (!mounted) return;
    setState(() => _fading = true);
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        showValidationToast(context, "Unable to open link.");
      }
    }
  }

  @override
  void dispose() {
    _activateMap.dispose();
    _privacyTapRecognizer.dispose();
    _termsTapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
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
                widget.onFinished?.call();
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
                  color: AppColors.white,
                  child: SafeArea(
                    child: SizedBox.expand(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Image.asset(
                                          "assets/images/welcome-image.png",
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Text(
                                        "Welcome to ${Environment.appName}, \na free transportation app",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.black,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "With ${Environment.appName}, you can find your way \nfrom one city to another easily.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.black.withValues(
                                            alpha: 0.64,
                                          ),
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
                                                color: AppColors.accentOf(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              LucideIcons.chevronRight,
                                              size: 20,
                                              color: AppColors.accentOf(
                                                context,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 24,
                                  right: 24,
                                  bottom: 18,
                                ),
                                child: _buildLegalNotice(context),
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

  Widget _buildLegalNotice(BuildContext context) {
    final subtle = AppColors.black.withValues(alpha: 0.45);
    final accent = AppColors.accentOf(context);
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 12, color: subtle, height: 1.4),
        children: [
          const TextSpan(text: 'By continuing, you agree to the '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            recognizer: _privacyTapRecognizer,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            recognizer: _termsTapRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// PressableHighlight moved to lib/widgets/pressable_highlight.dart

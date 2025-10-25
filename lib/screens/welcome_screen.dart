import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'map_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _kWelcomeSeenKey = 'welcome_seen_v1';

  Future<void> _onSkip(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeSeenKey, true);
    // Replace so user can't go back to welcome.
    // ignore: use_build_context_synchronously
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
                    child: Image.network(
                      "https://i.postimg.cc/Qtxc8xgv/welcome-image.png",
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onSkip(context),
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
                          LucideIcons.arrowRight,
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

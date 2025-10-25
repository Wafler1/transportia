import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/map_screen.dart';
import 'screens/welcome_screen.dart';

class EntariaApp extends StatelessWidget {
  const EntariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Entaria',
      color: const Color(0xFF0b0f14),
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
        );
      },
      textStyle: const TextStyle(
        color: Color(0xFF000000),
        fontSize: 14,
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  static const _kWelcomeSeenKey = 'welcome_seen_v1';
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_kWelcomeSeenKey) ?? false;
    if (!mounted) return;
    setState(() => _seen = v);
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      // Simple placeholder while loading preference.
      return const SizedBox.expand();
    }
    return _seen! ? const MapScreen() : const WelcomeScreen();
  }
}

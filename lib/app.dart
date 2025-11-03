import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/version_service.dart';
import 'utils/app_version.dart';
import 'utils/version_utils.dart';
import 'widgets/update_prompt_overlay.dart';

class EntariaApp extends StatelessWidget {
  const EntariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: OKToast(
        child: WidgetsApp(
          title: 'Entaria',
          color: const Color(0xFF0b0f14),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US'), Locale('en')],
          pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
            return PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  builder(context),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) => child,
            );
          },
          textStyle: const TextStyle(color: Color(0xFF000000), fontSize: 14),
          home: const _RootGate(),
        ),
      ),
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
  static const _kIgnoredUpdateKey = 'ignored_update_version';
  bool? _seen;
  String? _ignoredUpdateVersion;
  String? _availableUpdateVersion;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kWelcomeSeenKey) ?? false;
    final ignored = prefs.getString(_kIgnoredUpdateKey);
    _prefs = prefs;
    if (!mounted) return;
    setState(() {
      _seen = seen;
      _ignoredUpdateVersion = ignored;
    });
    _checkForUpdates(ignored);
  }

  Future<void> _checkForUpdates(String? ignoredVersion) async {
    final remoteVersion = await VersionService.fetchLatestVersion();
    if (!mounted || remoteVersion == null) return;
    if (!_shouldShowUpdate(remoteVersion, ignoredVersion)) return;
    setState(() => _availableUpdateVersion = remoteVersion);
  }

  bool _shouldShowUpdate(String remoteVersion, String? ignoredVersion) {
    if (!isVersionGreater(remoteVersion, AppVersion.current)) {
      return false;
    }
    if (ignoredVersion != null && ignoredVersion == remoteVersion) {
      return false;
    }
    return true;
  }

  void _handleWelcomeFinished() {
    if (!mounted) return;
    setState(() => _seen = true);
  }

  void _dismissUpdateOverlay() {
    if (!mounted) return;
    setState(() => _availableUpdateVersion = null);
  }

  Future<void> _skipCurrentVersion() async {
    final version = _availableUpdateVersion;
    if (version == null) {
      _dismissUpdateOverlay();
      return;
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_kIgnoredUpdateKey, version);
    if (!mounted) return;
    setState(() {
      _ignoredUpdateVersion = version;
      _availableUpdateVersion = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      // Simple placeholder while loading preference.
      return const SizedBox.expand();
    }
    final mainChild = _seen!
        ? const MainNavigationScreen()
        : WelcomeScreen(onFinished: _handleWelcomeFinished);

    return Stack(
      children: [
        mainChild,
        if (_availableUpdateVersion != null)
          UpdatePromptOverlay(
            remoteVersion: _availableUpdateVersion!,
            localVersion: AppVersion.current,
            onDismiss: _dismissUpdateOverlay,
            onSkipVersion: () {
              _skipCurrentVersion();
            },
          ),
      ],
    );
  }
}

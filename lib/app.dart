import 'dart:async';

import 'package:app_links/app_links.dart';
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

class Transportia extends StatelessWidget {
  const Transportia({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: OKToast(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final baseTextStyle = TextStyle(
              color: themeProvider.textColor,
              fontSize: 14,
            );
            return WidgetsApp(
              title: 'Transportia',
              color: themeProvider.backgroundColor,
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                DefaultWidgetsLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en', 'US'), Locale('en')],
              pageRouteBuilder:
                  <T>(RouteSettings settings, WidgetBuilder builder) {
                    return PageRouteBuilder<T>(
                      settings: settings,
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          builder(context),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) =>
                              child,
                    );
                  },
              textStyle: baseTextStyle,
              builder: (context, child) {
                final content = child ?? const SizedBox.shrink();
                return ColoredBox(
                  color: themeProvider.backgroundColor,
                  child: IconTheme(
                    data: IconThemeData(color: themeProvider.textColor),
                    child: content,
                  ),
                );
              },
              home: const _RootGate(),
            );
          },
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
  String? _availableUpdateVersion;
  SharedPreferences? _prefs;
  StreamSubscription<Uri>? _appLinkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _init();
  }

  Future<void> _initDeepLinks() async {
    try {
      final appLinks = AppLinks();

      final initialLink = await appLinks.getInitialLink();
      if (initialLink != null) {
        _handleIncomingDeepLink(initialLink);
      }

      _appLinkSubscription = appLinks.uriLinkStream.listen(
        (uri) {
          _handleIncomingDeepLink(uri);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Failed to process incoming app link: $error');
          debugPrint('$stackTrace');
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to initialize deep link handling: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kWelcomeSeenKey) ?? false;
    final ignored = prefs.getString(_kIgnoredUpdateKey);
    _prefs = prefs;
    if (!mounted) return;
    setState(() {
      _seen = seen;
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
      _availableUpdateVersion = null;
    });
  }

  void _handleIncomingDeepLink(Uri uri) {
    if (uri.scheme != 'transportia' || uri.host != 'trip') {
      return;
    }
    debugPrint('Received Transportia trip link: ${uri.toString()}');
    // Trip link payload will be handled in a future iteration.
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

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    super.dispose();
  }
}

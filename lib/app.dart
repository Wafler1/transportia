import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'environment.dart';
import 'constants/prefs_keys.dart';
import 'providers/backend_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/offline_banner_shell.dart';

class Transportia extends StatelessWidget {
  const Transportia({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BackendProvider()),
      ],
      child: OKToast(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final baseTextStyle = TextStyle(
              color: themeProvider.textColor,
              fontSize: 14,
            );
            return WidgetsApp(
              title: Environment.appName,
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
                    child: OfflineBannerShell(child: content),
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
  static const _kWelcomeSeenKey = PrefsKeys.welcomeSeen;
  bool? _seen;
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
    final prefs = SharedPreferencesAsync();
    final seen = await prefs.getBool(_kWelcomeSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _seen = seen;
    });
  }

  void _handleWelcomeFinished() {
    if (!mounted) return;
    setState(() => _seen = true);
  }

  void _handleIncomingDeepLink(Uri uri) {
    if (uri.scheme != 'transportia' || uri.host != 'trip') {
      return;
    }
    debugPrint('Received ${Environment.appName} trip link: ${uri.toString()}');
    // TODO: this
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const SizedBox.expand();
    }
    final mainChild = _seen!
        ? const MainNavigationScreen()
        : WelcomeScreen(onFinished: _handleWelcomeFinished);

    return mainChild;
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    super.dispose();
  }
}

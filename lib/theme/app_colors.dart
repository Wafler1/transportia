import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppColors {
  static Color accentOf(BuildContext context) {
    try {
      return context.watch<ThemeProvider>().accentColor;
    } catch (_) {
      final provider = ThemeProvider.instance;
      if (provider != null) {
        return provider.accentColor;
      }
      try {
        return context.read<ThemeProvider>().accentColor;
      } catch (_) {
        return accent;
      }
    }
  }

  static Color get accent => ThemeProvider.defaultAccentColor;
  static const Color solidBlack = Color(0xFF000000);
  static const Color solidWhite = Color(0xFFFFFFFF);

  static Color get black =>
      _resolveThemeColor((provider) => provider.textColor, solidBlack);
  static Color get white =>
      _resolveThemeColor((provider) => provider.backgroundColor, solidWhite);

  static Color _resolveThemeColor(
    Color Function(ThemeProvider provider) resolver,
    Color fallback,
  ) {
    final provider = ThemeProvider.instance;
    if (provider == null) {
      return fallback;
    }
    return resolver(provider);
  }
}

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppColors {
  // Dynamic accent color - use this when you have BuildContext
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
        // Fallback if provider is not available
        return accent;
      }
    }
  }

  // Static accent color for places where context is not available
  static const Color accent = Color.fromARGB(255, 0, 113, 133);
  static const Color solidBlack = Color(0xFF000000);
  static const Color solidWhite = Color(0xFFFFFFFF);

  // Theme-driven base colors (light/dark).
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

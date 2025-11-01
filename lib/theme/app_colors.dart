import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppColors {
  // Dynamic accent color - use this when you have BuildContext
  static Color accentOf(BuildContext context) {
    try {
      return context.watch<ThemeProvider>().accentColor;
    } catch (e) {
      // Fallback if provider is not available
      return accent;
    }
  }

  // Static accent color for places where context is not available
  static const Color accent = Color.fromARGB(255, 0, 113, 133);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
}

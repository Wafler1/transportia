import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Converts a hex string (with or without leading '#') into a [Color].
/// Returns null when the value cannot be parsed.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;

  var cleaned = hex.replaceAll('#', '');

  if (cleaned.length == 6) {
    cleaned = 'FF$cleaned';
  }

  if (cleaned.length != 8) return null;

  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;

  return Color(value);
}

/// Convenience wrapper that falls back to [fallback] when the color is invalid.
Color parseHexColorOr(String? hex, Color fallback) {
  return parseHexColor(hex) ?? fallback;
}

/// Convenience wrapper that falls back to the current accent colour when the
/// value is invalid.
Color parseHexColorOrAccent(BuildContext context, String? hex) {
  return parseHexColor(hex) ?? AppColors.accentOf(context);
}

String colorToHex(Color color) {
  final r = (color.r * 255.0).round();
  final g = (color.g * 255.0).round();
  final b = (color.b * 255.0).round();
  return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
}

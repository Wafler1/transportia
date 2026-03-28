import 'package:vibration/vibration.dart';

import '../providers/theme_provider.dart';

class Haptics {
  static bool get isEnabled =>
      ThemeProvider.instance?.vibrationsEnabled ??
      ThemeProvider.defaultVibrationsEnabled;

  static Future<bool> hasVibrator() async {
    try {
      return await Vibration.hasVibrator();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasCustomVibrationsSupport() async {
    try {
      return await Vibration.hasCustomVibrationsSupport();
    } catch (_) {
      return false;
    }
  }

  static Future<void> _tryVibrate({int duration = 20, int? amplitude}) async {
    if (!isEnabled) return;

    try {
      final bool hasVibrator = await Haptics.hasVibrator();
      if (!hasVibrator) return;
      if (amplitude != null) {
        await Vibration.vibrate(duration: duration, amplitude: amplitude);
      } else {
        await Vibration.vibrate(duration: duration);
      }
    } catch (_) {
      // Silently ignore unsupported platforms or errors.
    }
  }

  static Future<void> subtlePress() async {
    // Small ascending pattern to feel responsive but not intrusive.
    await _tryVibrate(duration: 20, amplitude: 40);
    await Future.delayed(const Duration(milliseconds: 40));
    await _tryVibrate(duration: 20, amplitude: 80);
    await Future.delayed(const Duration(milliseconds: 40));
    await _tryVibrate(duration: 20, amplitude: 120);
    await Future.delayed(const Duration(milliseconds: 40));
    await _tryVibrate(duration: 20, amplitude: 160);
    await Future.delayed(const Duration(milliseconds: 40));
    await _tryVibrate(duration: 20, amplitude: 200);
  }

  static Future<void> lightTick() async {
    await _tryVibrate(duration: 12, amplitude: 120);
  }

  static Future<void> mediumTick() async {
    await _tryVibrate(duration: 18, amplitude: 200);
  }

  static Future<void> dragRumblePulse() async {
    await _tryVibrate(duration: 8, amplitude: 25);
  }

  static Future<void> snap({required bool useCustomAmplitude}) async {
    await _tryVibrate(duration: 10, amplitude: useCustomAmplitude ? 90 : null);
  }
}

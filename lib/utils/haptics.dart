import 'package:vibration/vibration.dart';

class Haptics {
  static Future<void> _tryVibrate({int duration = 20, int? amplitude}) async {
    try {
      final bool hasVibrator = await Vibration.hasVibrator();
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
  }

  static Future<void> mediumTick() async {
    await _tryVibrate(duration: 18, amplitude: 200);
  }
}

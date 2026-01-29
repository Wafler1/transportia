import 'package:flutter/widgets.dart';

String formatTime(DateTime? dateTime, {String nullPlaceholder = '-'}) {
  if (dateTime == null) return nullPlaceholder;

  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Duration? computeDelay(
  DateTime? scheduledTime,
  DateTime actualTime, {
  Duration threshold = const Duration(minutes: 1),
}) {
  if (scheduledTime == null) return null;
  final diff = actualTime.difference(scheduledTime);
  if (diff.inSeconds.abs() < threshold.inSeconds) return null;
  return diff;
}

String formatDelay(Duration delay) {
  final isNegative = delay.isNegative;
  final totalMinutes = delay.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final buffer = <String>[];
  if (hours > 0) buffer.add('${hours}h');
  if (minutes > 0 || buffer.isEmpty) buffer.add('${minutes}m');
  final sign = isNegative ? '-' : '+';
  return '$sign${buffer.join(' ')}';
}

String formatIso8601Millis(DateTime dateTime) {
  final utc = dateTime.toUtc();
  final base = utc.toIso8601String();
  final dot = base.indexOf('.');
  if (dot == -1) {
    return base;
  }
  final millis = utc.millisecond.toString().padLeft(3, '0');
  return '${base.substring(0, dot)}.${millis}Z';
}

Color delayColor(Duration delay) {
  return delay.isNegative ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
}

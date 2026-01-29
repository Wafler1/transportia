import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../utils/time_utils.dart';

Widget? buildStopScheduleRow(
  String label,
  DateTime? scheduled,
  DateTime? actual,
  bool isPassed,
) {
  if (scheduled == null && actual == null) return null;
  final display = formatTime(scheduled ?? actual);
  final delay = (scheduled != null && actual != null)
      ? computeDelay(scheduled, actual)
      : null;
  final baseColor = isPassed
      ? AppColors.black.withValues(alpha: 0.4)
      : AppColors.black.withValues(alpha: 0.6);
  return Row(
    children: [
      Text('$label $display', style: TextStyle(fontSize: 13, color: baseColor)),
      if (delay != null) ...[
        const SizedBox(width: 6),
        Text(
          formatDelay(delay),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: delayColor(delay),
          ),
        ),
      ],
    ],
  );
}

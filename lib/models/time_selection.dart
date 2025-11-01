/// Represents the time selection state for route planning
class TimeSelection {
  final DateTime dateTime;
  final bool isArriveBy; // true = arrive by, false = depart at
  final bool
  _isDefaultNow; // Internal flag to track if this is unmodified "Now"

  const TimeSelection({
    required this.dateTime,
    required this.isArriveBy,
    bool isDefaultNow = false,
  }) : _isDefaultNow = isDefaultNow;

  /// Creates a "Now" time selection (depart now)
  factory TimeSelection.now() {
    return TimeSelection(
      dateTime: DateTime.now(),
      isArriveBy: false,
      isDefaultNow: true,
    );
  }

  /// Check if this is a "Now" selection
  bool get isNow => _isDefaultNow;

  /// Format date for API (YYYYMMDD format)
  String toApiDateFormat() {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}';
  }

  /// Format time for API (HH:MM:SS format)
  String toApiTimeFormat() {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Format for display in UI
  String toDisplayString() {
    if (isNow) return 'Now';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (selectedDay == today) {
      dateStr = 'Today';
    } else if (selectedDay == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}';
    }

    final timeStr =
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }

  TimeSelection copyWith({
    DateTime? dateTime,
    bool? isArriveBy,
    bool? isDefaultNow,
  }) {
    return TimeSelection(
      dateTime: dateTime ?? this.dateTime,
      isArriveBy: isArriveBy ?? this.isArriveBy,
      isDefaultNow: isDefaultNow ?? _isDefaultNow,
    );
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/time_selection.dart';
import '../theme/app_colors.dart';
import 'bottom_overlay_card.dart';
import 'pressable_highlight.dart';

class TimeSelectionOverlay extends StatefulWidget {
  const TimeSelectionOverlay({
    super.key,
    required this.currentSelection,
    required this.onSelectionChanged,
    required this.onDismiss,
    this.showDepartArriveToggle = true,
  });

  final TimeSelection currentSelection;
  final void Function(TimeSelection) onSelectionChanged;
  final VoidCallback onDismiss;
  final bool showDepartArriveToggle;

  @override
  State<TimeSelectionOverlay> createState() => _TimeSelectionOverlayState();
}

class _TimeSelectionOverlayState extends State<TimeSelectionOverlay> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isArriveBy;

  @override
  void initState() {
    super.initState();
    final initial = widget.currentSelection.dateTime;
    _selectedDate = DateTime(
      initial.year,
      initial.month,
      initial.day,
    );
    _selectedHour = initial.hour;
    _selectedMinute = initial.minute;
    _isArriveBy = widget.currentSelection.isArriveBy;
  }

  DateTime get _selectedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedHour,
      _selectedMinute,
    );
  }

  void _handleConfirm() {
    final selection = TimeSelection(
      dateTime: _selectedDateTime,
      isArriveBy: _isArriveBy,
      isDefaultNow: false,
    );
    widget.onSelectionChanged(selection);
    widget.onDismiss();
  }

  void _handleSetNow() {
    widget.onSelectionChanged(TimeSelection.now());
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Depart/Arrive toggle
        if (widget.showDepartArriveToggle)
          Row(
            children: [
              Expanded(
                child: _ToggleButton(
                  label: 'Depart at',
                  isSelected: !_isArriveBy,
                  onTap: () {
                    setState(() => _isArriveBy = false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToggleButton(
                  label: 'Arrive by',
                  isSelected: _isArriveBy,
                  onTap: () {
                    setState(() => _isArriveBy = true);
                  },
                ),
              ),
            ],
          ),
        if (widget.showDepartArriveToggle) const SizedBox(height: 10),

        // Date Selection
        _DateSelector(
          selectedDate: _selectedDate,
          onDateChanged: (date) {
            setState(() => _selectedDate = date);
          },
        ),
        const SizedBox(height: 10),

        // Time Selection
        _TimeSelector(
          selectedHour: _selectedHour,
          selectedMinute: _selectedMinute,
          onHourChanged: (hour) {
            setState(() => _selectedHour = hour);
          },
          onMinuteChanged: (minute) {
            setState(() => _selectedMinute = minute);
          },
        ),
        const SizedBox(height: 10),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ActionButton(
              label: 'Now',
              isPrimary: false,
              onTap: _handleSetNow,
            ),
            PressableHighlight(
              onPressed: _handleConfirm,
              highlightColor: AppColors.accentOf(context),
              borderRadius: BorderRadius.circular(14),
              enableHaptics: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 8),
                  Text(
                    'Confirm',
                    style: TextStyle(
                      color: AppColors.accentOf(context),
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    return BottomOverlayCard(
      title: 'Set time',
      maxHeightFactor: 0.8,
      padding: const EdgeInsets.all(16),
      onDismiss: widget.onDismiss,
      child: content,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isPrimary ? AppColors.white : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatefulWidget {
  const _DateSelector({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final void Function(DateTime) onDateChanged;

  @override
  State<_DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<_DateSelector> {
  double _dragOffset = 0;
  Timer? _autoScrollTimer;
  int _autoScrollDirection = 0; // 1 for next day, -1 for previous day

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) return 'Today';
    if (selected == tomorrow) return 'Tomorrow';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  void _changeDate(int days) {
    final newDate = widget.selectedDate.add(Duration(days: days));
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 30));

    if (newDate.isBefore(maxDate.add(const Duration(days: 1)))) {
      widget.onDateChanged(newDate);
    }
  }

  void _incrementDate() => _changeDate(1);

  void _decrementDate() => _changeDate(-1);

  void _startAutoScroll(int direction) {
    if (_autoScrollDirection == direction) return;
    _autoScrollDirection = direction;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_autoScrollDirection == 1) {
        _incrementDate();
      } else if (_autoScrollDirection == -1) {
        _decrementDate();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollDirection = 0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _handleDragStart(DragStartDetails details) {
    _dragOffset = 0;
    _stopAutoScroll();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragOffset += details.delta.dx;

    int direction;
    if (_dragOffset >= 10) {
      direction = 1;
    } else if (_dragOffset <= -10) {
      direction = -1;
    } else {
      direction = 0;
    }

    if (direction != 0) {
      _startAutoScroll(direction);
    }

    if (_dragOffset.abs() >= 26) {
      if (_dragOffset > 0) {
        _incrementDate();
      } else {
        _decrementDate();
      }
      _dragOffset = 0;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragOffset = 0;
    _stopAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x0F000000),
        border: Border.all(color: const Color(0x11000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _stopAutoScroll,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _decrementDate,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 20,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              _formatDate(widget.selectedDate),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            GestureDetector(
              onTap: _incrementDate,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.selectedHour,
    required this.selectedMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final int selectedHour;
  final int selectedMinute;
  final void Function(int) onHourChanged;
  final void Function(int) onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NumberPicker(
            value: selectedHour,
            minValue: 0,
            maxValue: 23,
            onChanged: onHourChanged,
            label: 'Hour',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _NumberPicker(
            value: selectedMinute,
            minValue: 0,
            maxValue: 59,
            onChanged: onMinuteChanged,
            label: 'Minute',
          ),
        ),
      ],
    );
  }
}

class _NumberPicker extends StatefulWidget {
  const _NumberPicker({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
    required this.label,
  });

  final int value;
  final int minValue;
  final int maxValue;
  final void Function(int) onChanged;
  final String label;

  @override
  State<_NumberPicker> createState() => _NumberPickerState();
}

class _NumberPickerState extends State<_NumberPicker> {
  double _dragOffset = 0;
  Timer? _autoScrollTimer;
  int _autoScrollDirection = 0; // 1 for up, -1 for down

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _increment() {
    if (widget.value < widget.maxValue) {
      widget.onChanged(widget.value + 1);
    }
  }

  void _decrement() {
    if (widget.value > widget.minValue) {
      widget.onChanged(widget.value - 1);
    }
  }

  void _startAutoScroll(int direction) {
    if (_autoScrollDirection == direction) return;
    _autoScrollDirection = direction;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_autoScrollDirection == 1) {
        _increment();
      } else if (_autoScrollDirection == -1) {
        _decrement();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollDirection = 0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _handleDragStart(DragStartDetails details) {
    _dragOffset = 0;
    _stopAutoScroll();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragOffset += details.delta.dy;

    // Determine direction: upward drag -> decrement dy negative -> increment
    int direction;
    if (_dragOffset <= -10) {
      direction = 1;
    } else if (_dragOffset >= 10) {
      direction = -1;
    } else {
      direction = 0;
    }

    if (direction != 0) {
      _startAutoScroll(direction);
    }

    // Trigger change every 26 pixels for snappier response
    if (_dragOffset.abs() >= 26) {
      if (_dragOffset < 0) {
        _increment();
      } else {
        _decrement();
      }
      _dragOffset = 0;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragOffset = 0;
    _stopAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x0F000000),
        border: Border.all(color: const Color(0x11000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _increment,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.chevronUp,
                    size: 20,
                    color: widget.value < widget.maxValue
                        ? AppColors.black.withValues(alpha: 0.6)
                        : AppColors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    widget.value.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _decrement,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 20,
                    color: widget.value > widget.minValue
                        ? AppColors.black.withValues(alpha: 0.6)
                        : AppColors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentOf(context) : AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.solidWhite : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

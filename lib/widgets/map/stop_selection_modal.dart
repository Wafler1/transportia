import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/stop_time.dart';
import '../../services/transitous_map_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/color_utils.dart';
import '../../utils/time_utils.dart';
import '../buttons/pill_button.dart';
import '../error_notice.dart';
import '../pressable_highlight.dart';
import '../skeletons/skeleton_shimmer.dart';

class StopSelectionModal extends StatefulWidget {
  const StopSelectionModal({
    super.key,
    required this.stop,
    required this.stopTimes,
    required this.isLoading,
    required this.errorMessage,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onStopTimeTap,
    required this.onViewTimetable,
    required this.onDismissRequested,
    required this.onClosed,
    required this.isClosing,
  });

  final MapStop stop;
  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final ValueChanged<StopTime> onStopTimeTap;
  final VoidCallback onViewTimetable;
  final VoidCallback onDismissRequested;
  final VoidCallback onClosed;
  final bool isClosing;

  @override
  State<StopSelectionModal> createState() => _StopSelectionModalState();
}

class _StopSelectionModalState extends State<StopSelectionModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _backdropOpacity;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            widget.onClosed();
          }
        });
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
    _scaleAnim = Tween<double>(begin: 1.06, end: 1.0).animate(_curve);
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant StopSelectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isClosing && widget.isClosing) {
      if (_controller.value == 0.0) {
        widget.onClosed();
      } else {
        _controller.reverse();
      }
    } else if (oldWidget.stop.id != widget.stop.id && !widget.isClosing) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _backdropOpacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismissRequested,
        child: Container(
          color: const Color(0xBF000000),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: _StopModalCard(
                  stop: widget.stop,
                  stopTimes: widget.stopTimes,
                  isLoading: widget.isLoading,
                  errorMessage: widget.errorMessage,
                  onSelectFrom: widget.onSelectFrom,
                  onSelectTo: widget.onSelectTo,
                  onStopTimeTap: widget.onStopTimeTap,
                  onViewTimetable: widget.onViewTimetable,
                  onDismiss: widget.onDismissRequested,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopModalCard extends StatelessWidget {
  const _StopModalCard({
    required this.stop,
    required this.stopTimes,
    required this.isLoading,
    required this.errorMessage,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onStopTimeTap,
    required this.onViewTimetable,
    required this.onDismiss,
  });

  final MapStop stop;
  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final ValueChanged<StopTime> onStopTimeTap;
  final VoidCallback onViewTimetable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double maxWidth = math.min(size.width - 48.0, 360.0);
    const double iconBoxSize = 40.0;

    Widget segment(
      String label,
      IconData icon,
      VoidCallback onTap,
      BorderRadius radius,
      bool alignEnd,
    ) {
      return Expanded(
        child: PillButton(
          onTap: onTap,
          borderRadius: radius,
          restingColor: const Color(0x00000000),
          pressedColor: const Color(0x00000000),
          borderColor: const Color(0x00000000),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: FittedBox(
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignEnd
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: alignEnd
                  ? [
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 18, color: AppColors.black),
                    ]
                  : [
                      Icon(icon, size: 18, color: AppColors.black),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                    ],
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 36,
              offset: Offset(0, 24),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.black.withValues(alpha: 0.07),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.mapPin,
                    size: 18,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: iconBoxSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          stop.stopId ?? 'Transit stop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Departures & arrivals',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            _StopTimesPreview(
              stopTimes: stopTimes,
              isLoading: isLoading,
              errorMessage: errorMessage,
              onStopTimeTap: onStopTimeTap,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onViewTimetable,
                highlightColor: AppColors.accentOf(context),
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 18,
                      color: AppColors.accentOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View full timetable',
                      style: TextStyle(
                        color: AppColors.accentOf(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Use this stop as:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.black.withValues(alpha: 0.07),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  segment(
                    'Origin',
                    LucideIcons.arrowUpFromDot,
                    onSelectFrom,
                    const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    false,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: const Color(0x33000000),
                  ),
                  segment(
                    'Destination',
                    LucideIcons.arrowDownToDot,
                    onSelectTo,
                    const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onDismiss,
                highlightColor: AppColors.accentOf(context),
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.accentOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dismiss',
                      style: TextStyle(
                        color: AppColors.accentOf(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTimesPreview extends StatelessWidget {
  const _StopTimesPreview({
    required this.stopTimes,
    required this.isLoading,
    required this.errorMessage,
    required this.onStopTimeTap,
  });

  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<StopTime> onStopTimeTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _StopTimesSkeleton();
    }
    if (errorMessage != null) {
      return ErrorNotice(message: errorMessage!, compact: true);
    }
    if (stopTimes.isEmpty) {
      return Text(
        'No upcoming departures.',
        style: TextStyle(
          color: AppColors.black.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < stopTimes.length; i++) ...[
          _StopTimePreviewRow(
            stopTime: stopTimes[i],
            onTap: () => onStopTimeTap(stopTimes[i]),
          ),
          if (i != stopTimes.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StopTimesSkeleton extends StatelessWidget {
  const _StopTimesSkeleton();

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.black.withValues(alpha: 0.08);
    final highlightColor = AppColors.black.withValues(alpha: 0.04);
    return SkeletonShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
            child: const _StopTimesSkeletonRow(),
          ),
        ),
      ),
    );
  }
}

class _StopTimesSkeletonRow extends StatelessWidget {
  const _StopTimesSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 140,
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              height: 10,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 10,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StopTimePreviewRow extends StatelessWidget {
  const _StopTimePreviewRow({required this.stopTime, this.onTap});

  final StopTime stopTime;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final routeColor =
        parseHexColor(stopTime.routeColor) ?? AppColors.accentOf(context);
    final routeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;
    final arrival = formatTime(
      stopTime.place.arrival ?? stopTime.place.scheduledArrival,
    );
    final departure = formatTime(
      stopTime.place.departure ?? stopTime.place.scheduledDeparture,
    );
    final label = stopTime.displayName.isNotEmpty
        ? stopTime.displayName
        : stopTime.routeShortName;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: routeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: routeTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            stopTime.headsign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Arr $arrival',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Dep $departure',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

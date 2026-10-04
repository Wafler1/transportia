import 'package:flutter/widgets.dart';

import '../models/itinerary.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import 'bottom_overlay_card.dart';
import 'pressable_highlight.dart';

/// Bottom sheet listing the stops after [boardingIndex] in [stops] (a
/// [Leg.fullStopSequence]) so the user can pick where they're getting off —
/// used to start ad-hoc tracking from a tapped departure rather than a
/// searched itinerary. Pops with the picked index into [stops], or null if
/// dismissed without picking.
Future<int?> showDestinationStopPicker(
  BuildContext context, {
  required List<TripStop> stops,
  required int boardingIndex,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Choose destination stop',
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, __) {
      return _DestinationStopPickerSheet(
        stops: stops,
        boardingIndex: boardingIndex,
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _DestinationStopPickerSheet extends StatelessWidget {
  const _DestinationStopPickerSheet({
    required this.stops,
    required this.boardingIndex,
  });

  final List<TripStop> stops;
  final int boardingIndex;

  @override
  Widget build(BuildContext context) {
    final destinationIndexes = [
      for (int i = boardingIndex + 1; i < stops.length; i++) i,
    ];

    return BottomOverlayCard(
      title: 'Getting off at…',
      onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
      maxHeightFactor: 0.75,
      child: Flexible(
        child: destinationIndexes.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No stops remain on this trip.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.5),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final index in destinationIndexes)
                      _DestinationStopRow(
                        stop: stops[index],
                        onTap: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(index),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DestinationStopRow extends StatelessWidget {
  const _DestinationStopRow({required this.stop, required this.onTap});

  final TripStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final arrival = formatTime(stop.arrival ?? stop.scheduledArrival);

    return PressableHighlight(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(12),
      enableHaptics: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                stop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              arrival,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

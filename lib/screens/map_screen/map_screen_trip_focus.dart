part of '../map_screen.dart';

class _TripFocusBottomCard extends StatelessWidget {
  const _TripFocusBottomCard({
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBack,
    required this.itinerary,
    required this.isLoading,
    required this.errorMessage,
    required this.bottomSpacer,
  });

  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onBack;
  final Itinerary? itinerary;
  final bool isLoading;
  final String? errorMessage;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BottomSheetHandle(
              onTap: onHandleTap,
              onDragStart: onDragStart,
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
            ),
            _BottomSheetBackButton(onPressed: onBack),
            Expanded(
              child: _TripFocusContent(
                itinerary: itinerary,
                isLoading: isLoading,
                errorMessage: errorMessage,
                bottomSpacer: bottomSpacer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripFocusContent extends StatelessWidget {
  const _TripFocusContent({
    required this.itinerary,
    required this.isLoading,
    required this.errorMessage,
    required this.bottomSpacer,
  });

  final Itinerary? itinerary;
  final bool isLoading;
  final String? errorMessage;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SkeletonShimmer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              const SkeletonCard(
                height: 140,
                borderRadius: BorderRadius.all(Radius.circular(14)),
                margin: EdgeInsets.all(12),
              ),
              const SkeletonCard(
                height: 420,
                borderRadius: BorderRadius.all(Radius.circular(14)),
                margin: EdgeInsets.all(12),
              ),
              SizedBox(height: bottomSpacer),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorNotice(message: errorMessage!),
        ),
      );
    }

    final itinerary = this.itinerary;
    if (itinerary == null || itinerary.legs.isEmpty) {
      return Center(
        child: EmptyState(
          title: 'No trip data available',
          titleStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.black.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final focusLeg = itinerary.legs.firstWhere(
      (leg) => leg.mode != 'WALK',
      orElse: () => itinerary.legs.first,
    );
    final routeColor =
        parseHexColor(focusLeg.routeColor) ?? AppColors.accentOf(context);
    final routeTextColor =
        parseHexColor(focusLeg.routeTextColor) ?? AppColors.solidWhite;
    final modeIcon = getLegIcon(focusLeg.mode);
    final headerText = focusLeg.displayName?.trim().isNotEmpty == true
        ? focusLeg.displayName!
        : focusLeg.routeShortName?.trim().isNotEmpty == true
        ? focusLeg.routeShortName!
        : getTransitModeName(focusLeg.mode);
    final headsign = focusLeg.headsign?.trim().isNotEmpty == true
        ? focusLeg.headsign
        : null;
    final stops = buildJourneyStops(focusLeg);
    final (vehicleStopIndex, isVehicleAtStation, isBeforeStart, isAfterEnd) =
        _estimateVehiclePosition(stops);
    final showVehicle =
        vehicleStopIndex >= 0 && vehicleStopIndex < stops.length;
    final timelineItems = <_TimelineItem>[];
    for (int i = 0; i < stops.length; i++) {
      timelineItems.add(_TimelineItem(stop: stops[i], isVehicle: false));
      if (showVehicle &&
          !isVehicleAtStation &&
          i == vehicleStopIndex &&
          i < stops.length - 1) {
        timelineItems.add(_TimelineItem(stop: null, isVehicle: true));
      }
    }

    int upcomingStopIndex = -1;
    if (showVehicle) {
      if (isVehicleAtStation) {
        upcomingStopIndex = vehicleStopIndex < stops.length - 1
            ? vehicleStopIndex + 1
            : -1;
      } else {
        upcomingStopIndex = vehicleStopIndex < stops.length - 1
            ? vehicleStopIndex + 1
            : -1;
      }
    }
    final currentStopIndex = isBeforeStart
        ? -1
        : isAfterEnd
        ? (stops.isEmpty ? -1 : stops.length - 1)
        : vehicleStopIndex;
    final allAlerts = <String, Alert>{};
    for (final stop in stops) {
      for (final alert in stop.alerts) {
        if (alert.headerText != null || alert.descriptionText != null) {
          final key = '${alert.headerText}|${alert.descriptionText}';
          allAlerts[key] = alert;
        }
      }
    }
    for (final alert in focusLeg.alerts) {
      if (alert.headerText != null || alert.descriptionText != null) {
        final key = '${alert.headerText}|${alert.descriptionText}';
        allAlerts[key] = alert;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(modeIcon, size: 32, color: AppColors.black),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (headerText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: routeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                headerText,
                                style: TextStyle(
                                  color: routeTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (headsign != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${getTransitModeName(focusLeg.mode)} • $headsign',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (allAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warnings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...allAlerts.values.map((alert) {
                    final hasTitle =
                        alert.headerText != null &&
                        alert.headerText!.isNotEmpty;
                    final hasBody =
                        alert.descriptionText != null &&
                        alert.descriptionText!.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.triangleAlert,
                              size: 16,
                              color: Color(0xFFF57C00),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasTitle)
                                    Text(
                                      alert.headerText!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  if (hasBody) ...[
                                    if (hasTitle) const SizedBox(height: 2),
                                    Text(
                                      alert.descriptionText!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.black.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (focusLeg.realTime)
                      const InfoChip(
                        icon: LucideIcons.radio,
                        label: 'Real-time',
                      ),
                    if (focusLeg.cancelled == true)
                      const InfoChip(
                        icon: LucideIcons.x,
                        label: 'CANCELLED',
                        tint: Color(0xFFD32F2F),
                      ),
                    InfoChip(
                      icon: LucideIcons.clock,
                      label: formatDuration(focusLeg.duration),
                    ),
                    if (focusLeg.distance != null)
                      InfoChip(
                        icon: LucideIcons.ruler,
                        label:
                            '${(focusLeg.distance! / 1000).toStringAsFixed(1)} km',
                      ),
                    if (focusLeg.agencyName != null)
                      InfoChip(
                        icon: LucideIcons.building,
                        label: focusLeg.agencyName!,
                      ),
                    if (focusLeg.routeLongName != null &&
                        focusLeg.routeLongName!.isNotEmpty)
                      InfoChip(
                        icon: LucideIcons.route,
                        label: focusLeg.routeLongName!,
                      ),
                    if (itinerary.fare != null)
                      InfoChip(
                        icon: LucideIcons.coins,
                        label:
                            '${itinerary.fare!.amount.toStringAsFixed(2)} ${itinerary.fare!.currency}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journey',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 16),
                if (stops.isEmpty)
                  EmptyState(
                    title: 'No stops available',
                    padding: EdgeInsets.zero,
                    titleStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  )
                else
                  FixedTimeline.tileBuilder(
                    theme: TimelineThemeData(
                      nodePosition: 0.08,
                      color: routeColor,
                      indicatorTheme: const IndicatorThemeData(size: 28),
                      connectorTheme: const ConnectorThemeData(thickness: 2.5),
                    ),
                    builder: TimelineTileBuilder.connected(
                      itemCount: timelineItems.length,
                      connectionDirection: ConnectionDirection.before,
                      contentsBuilder: (context, index) {
                        final item = timelineItems[index];
                        if (item.isVehicle && item.stop == null) {
                          return const SizedBox.shrink();
                        }

                        final stop = item.stop!;
                        final stopIndex = stops.indexOf(stop);
                        final isPassed = stopIndex <= currentStopIndex;
                        final isUpcoming = stopIndex == upcomingStopIndex;

                        final arrRow = buildStopScheduleRow(
                          'Arr',
                          stop.scheduledArrival,
                          stop.arrival,
                          isPassed,
                        );
                        final depRow = buildStopScheduleRow(
                          'Dep',
                          stop.scheduledDeparture,
                          stop.departure,
                          isPassed,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stop.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            stopIndex == 0 ||
                                                stopIndex == stops.length - 1 ||
                                                isUpcoming
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isPassed
                                            ? AppColors.black.withValues(
                                                alpha: 0.5,
                                              )
                                            : AppColors.black,
                                      ),
                                    ),
                                  ),
                                  if (isUpcoming) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: routeColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Upcoming',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: routeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (arrRow != null || depRow != null) ...[
                                const SizedBox(height: 2),
                                if (arrRow != null) arrRow,
                                if (depRow != null) ...[
                                  if (arrRow != null) const SizedBox(height: 2),
                                  depRow,
                                ],
                              ],
                              if (stop.track != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Track ${stop.track}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPassed
                                        ? AppColors.black.withValues(alpha: 0.4)
                                        : AppColors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                  ),
                                ),
                              ],
                              if (stop.cancelled == true) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'CANCELLED',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFD32F2F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      indicatorBuilder: (context, index) {
                        final item = timelineItems[index];
                        if (item.isVehicle && item.stop == null) {
                          return TimelineIndicatorBox(
                            lineColor: routeColor,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: routeColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  modeIcon,
                                  size: 14,
                                  color: routeTextColor,
                                ),
                              ),
                            ),
                          );
                        }

                        final stop = item.stop!;
                        final stopIndex = stops.indexOf(stop);
                        final isPassed = stopIndex <= currentStopIndex;
                        final bool isTerminal =
                            stopIndex == 0 || stopIndex == stops.length - 1;
                        final double dotSize = isTerminal ? 16 : 12;
                        final Color dotColor = isPassed
                            ? routeColor.withValues(alpha: 0.6)
                            : routeColor;
                        final bool isVehicleHere =
                            showVehicle &&
                            isVehicleAtStation &&
                            stopIndex == vehicleStopIndex;
                        final bool isFirstStop = stopIndex == 0;
                        final bool isLastStop = stopIndex == stops.length - 1;

                        if (isVehicleHere) {
                          return TimelineIndicatorBox(
                            lineColor: dotColor,
                            centerGap: 28.0,
                            cutTop: isFirstStop,
                            cutBottom: isLastStop,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                DotIndicator(color: dotColor, size: dotSize),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: routeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    modeIcon,
                                    size: 14,
                                    color: routeTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return TimelineIndicatorBox(
                          lineColor: dotColor,
                          centerGap: dotSize,
                          cutTop: isFirstStop,
                          cutBottom: isLastStop,
                          child: Center(
                            child: DotIndicator(color: dotColor, size: dotSize),
                          ),
                        );
                      },
                      connectorBuilder: (context, index, connectorType) {
                        bool isPassed = false;
                        if (index < timelineItems.length) {
                          final item = timelineItems[index];
                          if (item.isVehicle) {
                            isPassed = true;
                          } else {
                            final stopIndex = stops.indexOf(item.stop!);
                            isPassed = stopIndex <= currentStopIndex;
                          }
                        }

                        return SolidLineConnector(
                          color: isPassed
                              ? routeColor.withValues(alpha: 0.6)
                              : routeColor,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  bool _isSameMinute(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day &&
        aLocal.hour == bLocal.hour &&
        aLocal.minute == bLocal.minute;
  }

  (int, bool, bool, bool) _estimateVehiclePosition(List<JourneyStop> stops) {
    if (stops.isEmpty) return (-1, false, false, false);
    final now = DateTime.now();

    final firstStop = stops.first;
    final firstDeparture = firstStop.departure ?? firstStop.arrival;
    if (firstDeparture != null &&
        !_isSameMinute(now, firstDeparture) &&
        now.isBefore(firstDeparture)) {
      return (0, true, true, false);
    }

    final lastStop = stops.last;
    final lastArrival = lastStop.arrival ?? lastStop.departure;
    if (lastArrival != null &&
        !_isSameMinute(now, lastArrival) &&
        now.isAfter(lastArrival)) {
      return (stops.length - 1, true, false, true);
    }

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final arrival = stop.arrival;
      final departure = stop.departure;

      if (departure != null && _isSameMinute(now, departure)) {
        return (i, true, false, false);
      }

      if (arrival != null && departure != null) {
        if (now.isAfter(arrival) && now.isBefore(departure)) {
          return (i, true, false, false);
        }
      }

      final nextTime = departure ?? arrival;
      if (nextTime != null &&
          now.isBefore(nextTime) &&
          !_isSameMinute(now, nextTime)) {
        return (i - 1, false, false, false);
      }
    }

    return (stops.length - 1, true, false, true);
  }
}

class _TimelineItem {
  final JourneyStop? stop;
  final bool isVehicle;

  _TimelineItem({this.stop, required this.isVehicle});
}

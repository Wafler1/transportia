import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../theme/app_colors.dart';
import '../buttons/pill_button.dart';
import '../pressable_highlight.dart';

class LongPressSelectionModal extends StatefulWidget {
  const LongPressSelectionModal({
    super.key,
    required this.latLng,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onDismissRequested,
    required this.onClosed,
    required this.isClosing,
  });

  final LatLng latLng;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onDismissRequested;
  final VoidCallback onClosed;
  final bool isClosing;

  @override
  State<LongPressSelectionModal> createState() =>
      _LongPressSelectionModalState();
}

class _LongPressSelectionModalState extends State<LongPressSelectionModal>
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
    _scaleAnim = Tween<double>(begin: 1.1, end: 1.0).animate(_curve);
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LongPressSelectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isClosing && widget.isClosing) {
      if (_controller.value == 0.0) {
        widget.onClosed();
      } else {
        _controller.reverse();
      }
    } else if (oldWidget.latLng != widget.latLng && !widget.isClosing) {
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
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: _LongPressModalCard(
                  latLng: widget.latLng,
                  onSelectFrom: widget.onSelectFrom,
                  onSelectTo: widget.onSelectTo,
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

class _LongPressModalCard extends StatelessWidget {
  const _LongPressModalCard({
    required this.latLng,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onDismiss,
  });

  final LatLng latLng;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double maxWidth = math.min(size.width - 48.0, 340.0);
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
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
                          'Use this spot',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}',
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
            const SizedBox(height: 24),
            Text(
              'Choose how to use this location:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
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
                    SizedBox(width: 8),
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

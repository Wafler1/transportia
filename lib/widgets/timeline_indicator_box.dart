import 'package:flutter/widgets.dart';

class TimelineIndicatorBox extends StatelessWidget {
  const TimelineIndicatorBox({
    super.key,
    required this.child,
    required this.lineColor,
    this.centerGap = 0.0,
    this.cutTop = false,
    this.cutBottom = false,
  });

  final Widget child;
  final Color lineColor;
  final double centerGap;
  final bool cutTop;
  final bool cutBottom;

  @override
  Widget build(BuildContext context) {
    final double gap = centerGap.clamp(0.0, 28.0);
    final double sideLen = (28.0 - gap) / 2.0;

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!cutTop && sideLen > 0)
            Positioned(
              top: 0,
              child: SizedBox(
                width: 2.5,
                height: sideLen,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lineColor),
                ),
              ),
            ),
          if (!cutBottom && sideLen > 0)
            Positioned(
              bottom: 0,
              child: SizedBox(
                width: 2.5,
                height: sideLen,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lineColor),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

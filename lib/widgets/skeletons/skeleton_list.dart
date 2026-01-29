import 'package:flutter/widgets.dart';

import 'skeleton_card.dart';
import 'skeleton_shimmer.dart';

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    required this.itemCount,
    required this.itemHeight,
    this.listPadding = EdgeInsets.zero,
    this.itemMargin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.baseColor,
    this.highlightColor,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry listPadding;
  final EdgeInsetsGeometry itemMargin;
  final BorderRadius borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      baseColor: baseColor ?? const Color(0x1A000000),
      highlightColor: highlightColor ?? const Color(0x0D000000),
      child: ListView.builder(
        padding: listPadding,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return SkeletonCard(
            height: itemHeight,
            borderRadius: borderRadius,
            margin: itemMargin,
          );
        },
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0x1A000000),
    this.highlightColor = const Color(0x0D000000),
    this.period,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration? period;

  @override
  Widget build(BuildContext context) {
    if (period == null) {
      return Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: child,
      );
    }
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: period!,
      child: child,
    );
  }
}

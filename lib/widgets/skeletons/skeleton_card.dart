import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.margin = EdgeInsets.zero,
    this.color,
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color ?? AppColors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

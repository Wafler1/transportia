import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin!,
      child: Container(
        padding: padding!,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33000000)),
        ),
        child: child,
      ),
    );
  }
}

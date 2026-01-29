import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';

enum CustomCardPreset { outlined, subtle, elevated, filled }

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final CustomCardPreset preset;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.preset = CustomCardPreset.outlined,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius,
    this.boxShadow,
  });

  const CustomCard.subtle({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius,
    this.boxShadow,
  }) : preset = CustomCardPreset.subtle;

  const CustomCard.elevated({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius,
    this.boxShadow,
  }) : preset = CustomCardPreset.elevated;

  const CustomCard.filled({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius,
    this.boxShadow,
  }) : preset = CustomCardPreset.filled;

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = borderRadius ?? BorderRadius.circular(12);
    final resolved = _resolveStyle(context);

    return Padding(
      padding: margin!,
      child: Container(
        padding: padding!,
        decoration: BoxDecoration(
          color: resolved.backgroundColor,
          borderRadius: resolvedRadius,
          border: resolved.borderColor == null
              ? null
              : Border.all(
                  color: resolved.borderColor!,
                  width: resolved.borderWidth,
                ),
          boxShadow: resolved.boxShadow,
        ),
        child: child,
      ),
    );
  }

  _CustomCardStyle _resolveStyle(BuildContext context) {
    final resolvedBackground = backgroundColor ?? _defaultBackground(context);
    final resolvedBorder = borderColor ?? _defaultBorder(context);
    final resolvedShadow = boxShadow ?? _defaultShadow();
    return _CustomCardStyle(
      backgroundColor: resolvedBackground,
      borderColor: resolvedBorder,
      borderWidth: borderWidth,
      boxShadow: resolvedShadow,
    );
  }

  Color _defaultBackground(BuildContext context) {
    switch (preset) {
      case CustomCardPreset.subtle:
        return AppColors.black.withValues(alpha: 0.02);
      case CustomCardPreset.elevated:
      case CustomCardPreset.filled:
      case CustomCardPreset.outlined:
        return AppColors.white;
    }
  }

  Color? _defaultBorder(BuildContext context) {
    switch (preset) {
      case CustomCardPreset.subtle:
        return AppColors.black.withValues(alpha: 0.04);
      case CustomCardPreset.elevated:
        return AppColors.black.withValues(alpha: 0.1);
      case CustomCardPreset.outlined:
        return AppColors.black.withValues(alpha: 0.2);
      case CustomCardPreset.filled:
        return null;
    }
  }

  List<BoxShadow>? _defaultShadow() {
    switch (preset) {
      case CustomCardPreset.elevated:
        return const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ];
      case CustomCardPreset.subtle:
      case CustomCardPreset.outlined:
      case CustomCardPreset.filled:
        return null;
    }
  }
}

class _CustomCardStyle {
  const _CustomCardStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.boxShadow,
  });

  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
}

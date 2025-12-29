import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import 'custom_app_bar.dart';

/// Shared page scaffold that wraps common secondary screens with a
/// consistent SafeArea, background and header. It keeps the navigation
/// stack handling in one place and cuts down the ad-hoc Column/SafeArea
/// wrappers scattered across the codebase.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.backgroundColor,
    this.scrollable = false,
    this.padding,
    this.footer,
    this.onBack,
  });

  final String title;
  final Widget body;
  final Color? backgroundColor;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        (scrollable
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
            : EdgeInsets.zero);
    final resolvedBackgroundColor = backgroundColor ?? AppColors.white;

    Widget content = body;
    if (scrollable) {
      content = SingleChildScrollView(padding: effectivePadding, child: body);
    } else if (effectivePadding != EdgeInsets.zero) {
      content = Padding(padding: effectivePadding, child: body);
    }

    return ColoredBox(
      color: resolvedBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomAppBar(
              title: title,
              onBackButtonPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
            Expanded(child: content),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

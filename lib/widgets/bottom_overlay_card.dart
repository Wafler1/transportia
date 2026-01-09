import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import 'pressable_highlight.dart';

class BottomOverlayCard extends StatefulWidget {
  const BottomOverlayCard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.title,
    this.showClose = true,
    this.maxHeightFactor = 0.6,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.decoration,
    this.backdropColor = const Color(0x66000000),
    this.animateCard = true,
    this.cardAnimationDuration = const Duration(milliseconds: 220),
    this.cardAnimationCurve = Curves.easeOutCubic,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final String? title;
  final bool showClose;
  final double maxHeightFactor;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final Color backdropColor;
  final bool animateCard;
  final Duration cardAnimationDuration;
  final Curve cardAnimationCurve;

  @override
  State<BottomOverlayCard> createState() => _BottomOverlayCardState();
}

class _BottomOverlayCardState extends State<BottomOverlayCard> {
  late bool _cardVisible;

  @override
  void initState() {
    super.initState();
    _cardVisible = !widget.animateCard;
    if (widget.animateCard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _cardVisible = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant BottomOverlayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animateCard && !_cardVisible) {
      setState(() => _cardVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.of(context).size.height * widget.maxHeightFactor;
    final cardDecoration =
        widget.decoration ??
        BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 30,
              offset: Offset(0, 20),
            ),
          ],
        );

    final accent = AppColors.accentOf(context);
    final hasHeader = widget.title != null || widget.showClose;
    Widget card = Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: cardDecoration,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader)
              Row(
                children: [
                  if (widget.title != null)
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (widget.showClose)
                    PressableHighlight(
                      onPressed: widget.onDismiss,
                      highlightColor: accent,
                      borderRadius: BorderRadius.circular(10),
                      enableHaptics: false,
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: AppColors.black.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            if (hasHeader) const SizedBox(height: 12),
            widget.child,
          ],
        ),
      ),
    );

    if (widget.animateCard) {
      card = AnimatedSlide(
        offset: _cardVisible ? Offset.zero : const Offset(0, 0.08),
        duration: widget.cardAnimationDuration,
        curve: widget.cardAnimationCurve,
        child: AnimatedOpacity(
          opacity: _cardVisible ? 1.0 : 0.0,
          duration: widget.cardAnimationDuration,
          curve: widget.cardAnimationCurve,
          child: card,
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: ColoredBox(color: widget.backdropColor),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(onTap: () {}, child: card),
          ),
        ),
      ],
    );
  }
}

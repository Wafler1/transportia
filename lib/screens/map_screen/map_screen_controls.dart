part of '../map_screen.dart';

class _MapControlPills extends StatelessWidget {
  const _MapControlPills({
    required this.quickButton,
    required this.onLocate,
    required this.onSettings,
  });

  final _QuickButtonConfig quickButton;
  final VoidCallback onLocate;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final TextStyle quickLabelStyle = TextStyle(
      color: quickButton.color,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(maxWidth: 350),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapControlChip(
              onTap: quickButton.onTap,
              width: 116,
              leading: Icon(
                quickButton.icon,
                size: 16,
                color: quickButton.color,
              ),
              label: Text(
                quickButton.label,
                textAlign: TextAlign.center,
                style: quickLabelStyle,
              ),
            ),
            const SizedBox(width: 8),
            _MapControlChip(
              onTap: onLocate,
              width: 92,
              leading: Icon(
                LucideIcons.locate,
                size: 16,
                color: AppColors.black,
              ),
              label: Text(
                'Locate',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MapControlIconChip(
              onTap: onSettings,
              icon: LucideIcons.settings2,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle({
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragStart: (_) => onDragStart(),
      onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
      onVerticalDragEnd: (d) => onDragEnd(d.velocity.pixelsPerSecond.dy),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _BottomSheetBackButton extends StatelessWidget {
  const _BottomSheetBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PressableHighlight(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(14),
          highlightColor: accent,
          enableHaptics: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.chevronLeft, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControlIconChip extends StatelessWidget {
  const _MapControlIconChip({
    required this.onTap,
    required this.icon,
    this.size = 40,
  });

  final VoidCallback onTap;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = 16.0;
    return PillButton(
      onTap: onTap,
      padding: EdgeInsets.all(9),
      restingColor: AppColors.white,
      pressedColor: AppColors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(size / 2),
      borderColor: AppColors.black.withValues(alpha: 0.1),
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: Center(
          child: Icon(icon, size: iconSize, color: AppColors.black),
        ),
      ),
    );
  }
}

class _MapControlChip extends StatelessWidget {
  const _MapControlChip({
    required this.onTap,
    required this.leading,
    required this.label,
    this.width = 124,
  });

  final VoidCallback onTap;
  final Widget leading;
  final Widget label;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget content = _ChipContent(leading: leading, label: label);

    return PillButton(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      restingColor: AppColors.white,
      pressedColor: AppColors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      borderColor: AppColors.black.withValues(alpha: 0.1),
      child: SizedBox(width: width, child: content),
    );
  }
}

class _ChipContent extends StatelessWidget {
  const _ChipContent({required this.leading, required this.label});

  final Widget leading;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 20, child: Center(child: leading)),
        const SizedBox(width: 6),
        Expanded(
          child: Align(alignment: Alignment.center, child: label),
        ),
      ],
    );
  }
}

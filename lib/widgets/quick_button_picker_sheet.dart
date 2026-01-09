import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';
import 'bottom_overlay_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class QuickButtonPickerOption<T> {
  const QuickButtonPickerOption({
    required this.value,
    required this.label,
    required this.icon,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? subtitle;
  final bool enabled;
}

class QuickButtonPickerSheet<T> extends StatelessWidget {
  const QuickButtonPickerSheet({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.title = 'Quick button',
  });

  final T selected;
  final List<QuickButtonPickerOption<T>> options;
  final ValueChanged<T> onSelected;
  final String title;

  @override
  Widget build(BuildContext context) {
    void dismiss() => Navigator.of(context).pop();

    return BottomOverlayCard(
      title: title,
      maxHeightFactor: 0.6,
      onDismiss: dismiss,
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                _QuickButtonOptionTile(
                  option: options[i],
                  selected: options[i].value == selected,
                  onTap: options[i].enabled
                      ? () {
                          dismiss();
                          onSelected(options[i].value);
                        }
                      : null,
                ),
                if (i != options.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickButtonOptionTile<T> extends StatelessWidget {
  const _QuickButtonOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QuickButtonPickerOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final enabled = option.enabled;
    final textColor = enabled
        ? (selected ? accent : AppColors.black)
        : AppColors.black.withValues(alpha: 0.4);
    final subtitleColor = enabled
        ? AppColors.black.withValues(alpha: 0.55)
        : AppColors.black.withValues(alpha: 0.35);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0x14000000),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                option.icon,
                size: 16,
                color: enabled ? accent : accent.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (option.subtitle != null)
                    Text(
                      option.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                ],
              ),
            ),
            if (!enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black.withValues(alpha: 0.4),
                  ),
                ),
              )
            else
              Icon(
                selected ? LucideIcons.check : LucideIcons.plus,
                size: 16,
                color: selected ? accent : const Color(0x33000000),
              ),
          ],
        ),
      ),
    );
  }
}

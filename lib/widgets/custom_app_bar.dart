import 'package:entaria_app/widgets/pressable_highlight.dart';
import 'package:flutter/widgets.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';


class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackButtonPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onBackButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Use a Stack so the title can be truly centered on the screen while the back
    // button stays left‑aligned.
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SizedBox(
        height: preferredSize.height,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PressableHighlight(
                onPressed:
                    onBackButtonPressed ?? () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      LucideIcons.chevronLeft,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56.0);
}

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import 'pressable_highlight.dart';

/// Wraps a screen that's normally only ever tab-hosted (and so has its own
/// inline header instead of a [CustomAppBar]) with a small back affordance,
/// for the rare case it's pushed standalone instead — e.g. when "Departures"
/// or "Saved trips" is demoted from a tab to a settings entry.
///
/// The back row sits *above* [child] in a [Column] rather than floating over
/// it — those screens start their own header content flush with the top, so
/// an overlaid back button would sit on top of it instead of beside it.
class PushedScreenBackOverlay extends StatelessWidget {
  const PushedScreenBackOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: PressableHighlight(
                onPressed: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.chevronLeft,
                      size: 20,
                      color: AppColors.accentOf(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

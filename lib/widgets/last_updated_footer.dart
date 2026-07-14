import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Small "Updated Xm ago" label shown on screens that support
/// pull-to-refresh. Renders nothing until [lastUpdated] is set.
///
/// By default it's centered with vertical padding, meant for the bottom of
/// a scrollable list. Pass [compact] to get a bare inline label instead,
/// for placing somewhere always visible (e.g. next to a fixed header) so
/// the user doesn't have to scroll to confirm a refresh happened.
class LastUpdatedFooter extends StatelessWidget {
  const LastUpdatedFooter({
    super.key,
    required this.lastUpdated,
    this.compact = false,
  });

  final DateTime? lastUpdated;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lastUpdated = this.lastUpdated;
    if (lastUpdated == null) return const SizedBox.shrink();
    final text = Text(
      'Updated ${_formatAgo(lastUpdated)}',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.black.withValues(alpha: 0.4),
      ),
    );
    if (compact) return text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: text),
    );
  }

  String _formatAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

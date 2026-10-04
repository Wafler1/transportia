import 'package:flutter/widgets.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

/// Small monospace line of raw GTFS identifiers (trip id, stop id, ...),
/// shown only when the "Show GTFS fields" advanced setting is on. Renders
/// nothing if the setting is off or none of [fields] have a value.
class GtfsFieldsRow extends StatelessWidget {
  const GtfsFieldsRow({super.key, required this.fields});

  /// Label -> value. Entries with a null/empty value are skipped.
  final Map<String, String?> fields;

  @override
  Widget build(BuildContext context) {
    if (ThemeProvider.instance?.showGtfsFields != true) {
      return const SizedBox.shrink();
    }
    final parts = fields.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        parts.join('  ·  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: AppColors.black.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

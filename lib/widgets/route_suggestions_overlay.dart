import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/route_field_kind.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/haptics.dart';

class RouteSuggestionsOverlay extends StatelessWidget {
  const RouteSuggestionsOverlay({
    super.key,
    required this.width,
    required this.activeField,
    required this.fromController,
    required this.toController,
    required this.suggestions,
    required this.isLoading,
    required this.onSuggestionTap,
    required this.onDismissRequest,
  });

  final double width;
  final RouteFieldKind? activeField;
  final TextEditingController fromController;
  final TextEditingController toController;
  final List<TransitousLocationSuggestion> suggestions;
  final bool isLoading;
  final void Function(
    RouteFieldKind field,
    TransitousLocationSuggestion suggestion,
  )
  onSuggestionTap;
  final VoidCallback onDismissRequest;

  @override
  Widget build(BuildContext context) {
    final field = activeField;
    if (field == null) return const SizedBox.shrink();
    final controller = field == RouteFieldKind.from
        ? fromController
        : toController;
    final query = controller.text.trim();

    Widget body;
    final bool hasQuery = query.length >= 3;
    final bool hasResults = hasQuery && suggestions.isNotEmpty;
    final bool showLoading = hasQuery && isLoading;

    if (!hasQuery) {
      body = const Center(
        child: _SuggestionPlaceholder(
          icon: LucideIcons.type,
          title: 'Keep typing',
          subtitle: 'Enter at least 3 characters to search.',
        ),
      );
    } else if (showLoading) {
      body = const Center(child: _SuggestionLoading());
    } else if (!hasResults) {
      body = const Center(
        child: _SuggestionPlaceholder(
          icon: LucideIcons.searchX,
          title: 'No matches found',
          subtitle: 'Try a nearby city or tweak the spelling.',
        ),
      );
    } else {
      body = ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return _SuggestionTile(
            suggestion: suggestion,
            onTap: () => onSuggestionTap(field, suggestion),
          );
        },
      );
    }

    final label = field == RouteFieldKind.to ? 'Destination' : 'Origin';
    final allowDismissTap = !hasResults && !showLoading;

    final card = SizedBox(
      width: width,
      child: Material(
        color: AppColors.white,
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        shadowColor: const Color(0x33000000),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: body,
              ),
            ],
          ),
        ),
      ),
    );

    if (!allowDismissTap) {
      return card;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismissRequest,
      child: card,
    );
  }
}

class _SuggestionPlaceholder extends StatelessWidget {
  const _SuggestionPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x0F000000),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x11000000)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.black, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x99000000), fontSize: 13),
        ),
      ],
    );
  }
}

class _SuggestionLoading extends StatelessWidget {
  const _SuggestionLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(LucideIcons.cloudDownload, size: 28, color: AppColors.black),
        SizedBox(height: 10),
        Text(
          'Fetching…',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final TransitousLocationSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = suggestion.subtitle.isNotEmpty
        ? suggestion.subtitle
        : (suggestion.country ?? '');
    final iconData = _iconForType(suggestion.type);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.lightTick();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x0F000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x11000000)),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, size: 18, color: AppColors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.name,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0x99000000),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String rawType) {
    final type = rawType.toLowerCase();
    if (type.contains('stop')) return LucideIcons.bus;
    if (type.contains('place')) return LucideIcons.map;
    if (type.contains('address')) return LucideIcons.locateFixed;
    return LucideIcons.mapPin;
  }
}

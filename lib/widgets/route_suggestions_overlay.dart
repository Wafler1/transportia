import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/route_field_kind.dart';
import '../models/saved_place.dart';
import '../services/favorites_service.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/favorite_icons.dart';
import '../utils/haptics.dart';

class RouteSuggestionsOverlay extends StatelessWidget {
  const RouteSuggestionsOverlay({
    super.key,
    required this.width,
    required this.activeField,
    required this.fromController,
    required this.toController,
    required this.suggestions,
    required this.savedPlaces,
    required this.favorites,
    required this.isLoading,
    required this.onSuggestionTap,
    required this.onDismissRequest,
    this.title,
  });

  final double width;
  final RouteFieldKind? activeField;
  final TextEditingController fromController;
  final TextEditingController toController;
  final List<TransitousLocationSuggestion> suggestions;
  final List<SavedPlace> savedPlaces;
  final List<FavoritePlace> favorites;
  final bool isLoading;
  final void Function(
    RouteFieldKind field,
    TransitousLocationSuggestion suggestion,
  )
  onSuggestionTap;
  final VoidCallback onDismissRequest;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final field = activeField;
    if (field == null) return const SizedBox.shrink();
    final controller = field == RouteFieldKind.from
        ? fromController
        : toController;
    final label =
        title ?? (field == RouteFieldKind.to ? 'Destination' : 'Origin');

    return _SuggestionsOverlayCard(
      width: width,
      label: label,
      query: controller.text.trim(),
      suggestions: suggestions,
      savedPlaces: savedPlaces,
      favorites: favorites,
      isLoading: isLoading,
      onSuggestionTap: (suggestion) => onSuggestionTap(field, suggestion),
      onDismissRequest: onDismissRequest,
    );
  }
}

class SingleFieldSuggestionsOverlay extends StatelessWidget {
  const SingleFieldSuggestionsOverlay({
    super.key,
    required this.width,
    required this.controller,
    required this.suggestions,
    required this.savedPlaces,
    this.favorites = const [],
    required this.isLoading,
    required this.onSuggestionTap,
    required this.onDismissRequest,
    this.title,
  });

  final double width;
  final TextEditingController controller;
  final List<TransitousLocationSuggestion> suggestions;
  final List<SavedPlace> savedPlaces;
  final List<FavoritePlace> favorites;
  final bool isLoading;
  final ValueChanged<TransitousLocationSuggestion> onSuggestionTap;
  final VoidCallback onDismissRequest;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return _SuggestionsOverlayCard(
      width: width,
      label: title ?? 'Suggestions',
      query: controller.text.trim(),
      suggestions: suggestions,
      savedPlaces: savedPlaces,
      favorites: favorites,
      isLoading: isLoading,
      onSuggestionTap: onSuggestionTap,
      onDismissRequest: onDismissRequest,
    );
  }
}

class _SuggestionsOverlayCard extends StatelessWidget {
  const _SuggestionsOverlayCard({
    required this.width,
    required this.label,
    required this.query,
    required this.suggestions,
    required this.savedPlaces,
    required this.favorites,
    required this.isLoading,
    required this.onSuggestionTap,
    required this.onDismissRequest,
  });

  final double width;
  final String label;
  final String query;
  final List<TransitousLocationSuggestion> suggestions;
  final List<SavedPlace> savedPlaces;
  final List<FavoritePlace> favorites;
  final bool isLoading;
  final ValueChanged<TransitousLocationSuggestion> onSuggestionTap;
  final VoidCallback onDismissRequest;

  @override
  Widget build(BuildContext context) {
    final savedMatches = _filterSavedPlaces(savedPlaces, query);
    final favMatches = _filterFavorites(favorites, query);

    Widget body;
    final bool hasFullQuery = query.length >= 3;
    final bool hasFavMatches = favMatches.isNotEmpty;
    final bool showSaved =
        !hasFullQuery && (hasFavMatches || savedMatches.isNotEmpty);
    final bool hasResults =
        hasFullQuery && (suggestions.isNotEmpty || hasFavMatches);
    final bool showLoading = hasFullQuery && isLoading && !hasFavMatches;

    if (showSaved) {
      final combined = [
        ...favMatches.map(_favToSuggestion),
        ...savedMatches.map(_toSuggestion),
      ];
      body = ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: combined.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final suggestion = combined[index];
          return _SuggestionTile(
            suggestion: suggestion,
            onTap: () => onSuggestionTap(suggestion),
          );
        },
      );
    } else if (!hasFullQuery) {
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
      final merged = [...favMatches.map(_favToSuggestion), ...suggestions];
      body = ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: merged.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final suggestion = merged[index];
          return _SuggestionTile(
            suggestion: suggestion,
            onTap: () => onSuggestionTap(suggestion),
          );
        },
      );
    }

    final allowDismissTap = !showSaved && !hasResults && !showLoading;

    final card = SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
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

List<FavoritePlace> _filterFavorites(List<FavoritePlace> favs, String query) {
  if (favs.isEmpty) return <FavoritePlace>[];
  final trimmed = query.trim().toLowerCase();
  final filtered = trimmed.isEmpty
      ? favs
      : favs.where((f) => f.name.toLowerCase().contains(trimmed)).toList();
  return filtered.take(5).toList(growable: false);
}

TransitousLocationSuggestion _favToSuggestion(FavoritePlace fav) {
  return TransitousLocationSuggestion(
    id: 'fav-${fav.id}',
    name: fav.name,
    lat: fav.lat,
    lon: fav.lon,
    type: fav.iconName,
    country: null,
    defaultArea: null,
  );
}

List<SavedPlace> _filterSavedPlaces(List<SavedPlace> places, String query) {
  if (places.isEmpty) return <SavedPlace>[];
  final trimmed = query.trim().toLowerCase();
  final filtered = trimmed.isEmpty
      ? places
      : places
            .where((place) => place.name.toLowerCase().contains(trimmed))
            .toList();
  return filtered.take(5).toList(growable: false);
}

TransitousLocationSuggestion _toSuggestion(SavedPlace place) {
  return TransitousLocationSuggestion(
    id: 'saved-${place.key}',
    name: place.name,
    lat: place.lat,
    lon: place.lon,
    type: place.type,
    country: place.countryCode,
    defaultArea: place.city,
  );
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
            color: AppColors.black.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.black, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black.withValues(alpha: 0.6),
            fontSize: 13,
          ),
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
      children: [
        Icon(LucideIcons.cloudDownload, size: 28, color: AppColors.black),
        const SizedBox(height: 10),
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
              color: AppColors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.black.withValues(alpha: 0.07),
              ),
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
                  style: TextStyle(
                    color: AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.6),
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
    return iconForFavorite(rawType);
  }
}

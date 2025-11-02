import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'favourites_map_screen.dart';
import '../services/favorites_service.dart';
import '../theme/app_colors.dart';
import '../utils/custom_page_route.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/edit_favorite_overlay.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String id) async {
    await FavoritesService.removeFavorite(id);
  }

  Future<void> _openAddFavoriteMap() async {
    final result = await Navigator.of(
      context,
    ).push(CustomPageRoute(child: const AddFavouriteMapScreen()));

    // Reload favorites if something was added
    if (result == true && mounted) {
      await FavoritesService.getFavorites();
    }
  }

  Future<void> _editFavorite(FavoritePlace favorite) async {
    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditFavoriteOverlay(
        favorite: favorite,
        onSaved: () {
          setState(() {}); // Trigger rebuild to show updated data
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Favourites',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const AppIconHeader(
            icon: LucideIcons.heart,
            title: 'Your favourite places',
            subtitle: 'Quickly reuse the stops and addresses you visit most.',
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else
            ValueListenableBuilder<List<FavoritePlace>>(
              valueListenable: FavoritesService.favoritesListenable,
              builder: (context, favorites, _) {
                if (favorites.isEmpty) {
                  return _buildEmptyState();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tap a saved place to edit its name and icon.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0x66000000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < favorites.length; i++) ...[
                      _FavouriteListEntry(
                        favorite: favorites[i],
                        onSelect: () => _editFavorite(favorites[i]),
                        onRemove: () => _removeFavorite(favorites[i].id),
                      ),
                      if (i != favorites.length - 1) const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildAddButton(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'No favourites yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Add the places you care about and they will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0x66000000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _openAddFavoriteMap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accentOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentOf(context).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 20, color: AppColors.white),
            SizedBox(width: 8),
            Text(
              'Add Favourite',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavouriteListEntry extends StatelessWidget {
  const _FavouriteListEntry({
    required this.favorite,
    required this.onSelect,
    required this.onRemove,
  });

  final FavoritePlace favorite;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  IconData _getIconData(String iconName) {
    const iconMap = {
      'mapPin': LucideIcons.mapPin,
      'home': LucideIcons.house,
      'briefcase': LucideIcons.briefcase,
      'school': LucideIcons.school,
      'shoppingBag': LucideIcons.shoppingBag,
      'coffee': LucideIcons.coffee,
      'utensils': LucideIcons.utensils,
      'dumbbell': LucideIcons.dumbbell,
      'heart': LucideIcons.heart,
      'star': LucideIcons.star,
      'music': LucideIcons.music,
      'plane': LucideIcons.plane,
    };
    return iconMap[iconName] ?? LucideIcons.mapPin;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x11000000)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(_getIconData(favorite.iconName), size: 24, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    favorite.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${favorite.lat.toStringAsFixed(4)}, ${favorite.lon.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0x66000000),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                child: const Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: Color(0xFFFF3B30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

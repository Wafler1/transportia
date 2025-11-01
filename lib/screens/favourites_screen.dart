import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../screens/add_favourite_map_screen.dart';
import '../services/favorites_service.dart';
import '../theme/app_colors.dart';
import '../utils/custom_page_route.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/validation_toast.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<FavoritePlace> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final favorites = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String id) async {
    await FavoritesService.removeFavorite(id);
    await _loadFavorites();
    if (mounted) {
      showValidationToast(context, "Removed from favourites");
    }
  }

  Future<void> _openAddFavoriteMap() async {
    final result = await Navigator.of(
      context,
    ).push(CustomPageRoute(child: const AddFavouriteMapScreen()));

    // Reload favorites if something was added
    if (result == true && mounted) {
      await _loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _isLoading
        ? const Center(
            child: Text(
              'Loading...',
              style: TextStyle(fontSize: 14, color: Color(0x66000000)),
            ),
          )
        : _favorites.isEmpty
        ? _buildEmptyState()
        : _buildFavoritesList();

    return AppPageScaffold(
      title: 'Favourites',
      body: content,
      footer: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildAddButton(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0x08000000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                LucideIcons.heart,
                size: 40,
                color: Color(0x66000000),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Favourites Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your favourite places for quick access',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0x66000000)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _favorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        return _buildFavoriteItem(favorite);
      },
    );
  }

  Widget _buildFavoriteItem(FavoritePlace favorite) {
    return GestureDetector(
      onTap: () {
        // Will be handled by parent screen
        Navigator.of(context).pop(favorite);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A000000)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentOf(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.mapPin,
                size: 24,
                color: AppColors.accentOf(context),
              ),
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
                  const SizedBox(height: 4),
                  Text(
                    '${favorite.lat.toStringAsFixed(4)}, ${favorite.lon.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0x66000000),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _removeFavorite(favorite.id),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x05000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  size: 20,
                  color: Color(0xFFFF3B30),
                ),
              ),
            ),
          ],
        ),
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

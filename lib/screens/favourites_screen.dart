import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
      scrollable: false,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            const Expanded(
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else
            Expanded(
              child: ValueListenableBuilder<List<FavoritePlace>>(
                valueListenable: FavoritesService.favoritesListenable,
                builder: (context, favorites, _) {
                  if (favorites.isEmpty) {
                    return _buildEmptyState();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Long press and drag to reorder your favourites. Tap to edit.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0x66000000),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _FavoritesReorderList(
                          favorites: favorites,
                          onSelect: _editFavorite,
                          onRemove: (favorite) => _removeFavorite(favorite.id),
                          onReorder: (oldIndex, newIndex) {
                            final updated =
                                List<FavoritePlace>.from(favorites);
                            final item = updated.removeAt(oldIndex);
                            updated.insert(newIndex, item);
                            unawaited(
                              FavoritesService.reorderFavorites(updated),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
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
          borderRadius: BorderRadius.circular(12),
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

class _FavoritesReorderList extends StatefulWidget {
  const _FavoritesReorderList({
    required this.favorites,
    required this.onSelect,
    required this.onRemove,
    required this.onReorder,
  });

  final List<FavoritePlace> favorites;
  final ValueChanged<FavoritePlace> onSelect;
  final ValueChanged<FavoritePlace> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_FavoritesReorderList> createState() => _FavoritesReorderListState();
}

class _FavoritesReorderListState extends State<_FavoritesReorderList> {
  String? _draggingId;
  int? _currentDropIndex;
  final Map<String, double> _itemHeights = <String, double>{};
  static const double _baseGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final children = <Widget>[];
        final favorites = widget.favorites;

        for (var i = 0; i < favorites.length; i++) {
          children.add(_buildDropZone(context, index: i, width: width));
          children.add(_buildDraggableTile(
            context,
            favorite: favorites[i],
            width: width,
          ));
        }
        children.add(
          _buildDropZone(
            context,
            index: favorites.length,
            width: width,
            isTerminal: true,
          ),
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: children,
        );
      },
    );
  }

  Widget _buildDropZone(
    BuildContext context, {
    required int index,
    required double width,
    bool isTerminal = false,
  }) {
    final favorites = widget.favorites;
    final bool isTop = index == 0;
    final bool isBottom = isTerminal;
    final double baseHeight = isTop ? _baseGap : (isBottom ? _baseGap : _baseGap);

    return DragTarget<FavoritePlace>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        final fromIndex = favorites.indexWhere((f) => f.id == data.id);
        if (fromIndex == -1) return false;
        if (index == fromIndex || index == fromIndex + 1) {
          return false;
        }
        setState(() => _currentDropIndex = index);
        return true;
      },
      onLeave: (_) {
        if (_currentDropIndex == index) {
          setState(() => _currentDropIndex = null);
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        final oldIndex = favorites.indexWhere((f) => f.id == data.id);
        if (oldIndex == -1) return;
        var newIndex = index;
        if (newIndex > oldIndex) newIndex -= 1;
        if (newIndex == oldIndex) {
          setState(() => _currentDropIndex = null);
          return;
        }
        widget.onReorder(oldIndex, newIndex);
        setState(() => _currentDropIndex = null);
      },
      builder: (context, candidateData, rejectedData) {
        final highlight =
            candidateData.isNotEmpty || _currentDropIndex == index;
        final double gapHeight =
            highlight ? _gapExtentFor(index) : baseHeight;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: gapHeight,
          child: Center(
            child: AnimatedOpacity(
              opacity: highlight ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Container(
                width: width,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accentOf(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableTile(
    BuildContext context, {
    required FavoritePlace favorite,
    required double width,
  }) {
    final isDragging = _draggingId == favorite.id;
    final entryHeight = _itemHeights[favorite.id];

    Widget buildEntry({required bool interactive}) {
      final entry = _FavouriteListEntry(
        favorite: favorite,
        onSelect: () => widget.onSelect(favorite),
        onRemove: () => widget.onRemove(favorite),
      );
      return interactive ? entry : IgnorePointer(child: entry);
    }

    final interactiveEntry = buildEntry(interactive: true);

    return LongPressDraggable<FavoritePlace>(
      data: favorite,
      axis: Axis.vertical,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: buildEntry(interactive: false),
          ),
        ),
      ),
      childWhenDragging: SizedBox(
        height: (entryHeight ?? 112.0) + _baseGap,
      ),
      onDragStarted: () {
        setState(() {
          _draggingId = favorite.id;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingId = null;
          _currentDropIndex = null;
        });
      },
      onDraggableCanceled: (_, __) {
        setState(() {
          _draggingId = null;
          _currentDropIndex = null;
        });
      },
      onDragCompleted: () {
        setState(() {
          _draggingId = null;
          _currentDropIndex = null;
        });
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isDragging ? 0.35 : 1.0,
        curve: Curves.easeOutCubic,
        child: _SizeReporter(
          id: favorite.id,
          onSize: (size) {
            if (size == null) return;
            final height = size.height;
            if (height <= 0) return;
            final current = _itemHeights[favorite.id];
            if (current == null || (height - current).abs() > 0.5) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_itemHeights[favorite.id] == height) return;
                setState(() {
                  _itemHeights[favorite.id] = height;
                });
              });
            }
          },
          child: interactiveEntry,
        ),
      ),
    );
  }

  double _gapExtentFor(int index) {
    final draggingId = _draggingId;
    if (draggingId == null) return _baseGap * 2;
    final draggingHeight = _itemHeights[draggingId];
    if (draggingHeight == null) return _baseGap * 2;
    return draggingHeight + _baseGap;
  }
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({
    required this.id,
    required this.onSize,
    required Widget child,
  }) : super(child: child);

  final String id;
  final ValueChanged<Size?> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeReporter(onSize: onSize);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter({required this.onSize});

  ValueChanged<Size?> onSize;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final currentSize = size;
    if (_lastSize == currentSize) return;
    _lastSize = currentSize;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      onSize(currentSize);
    });
  }
}

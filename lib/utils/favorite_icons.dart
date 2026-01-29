import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FavoriteIconOption {
  const FavoriteIconOption(this.name, this.icon);

  final String name;
  final IconData icon;
}

const List<FavoriteIconOption> favoriteIconOptions = [
  FavoriteIconOption('mapPin', LucideIcons.mapPin),
  FavoriteIconOption('home', LucideIcons.house),
  FavoriteIconOption('briefcase', LucideIcons.briefcase),
  FavoriteIconOption('school', LucideIcons.school),
  FavoriteIconOption('shoppingBag', LucideIcons.shoppingBag),
  FavoriteIconOption('coffee', LucideIcons.coffee),
  FavoriteIconOption('utensils', LucideIcons.utensils),
  FavoriteIconOption('dumbbell', LucideIcons.dumbbell),
  FavoriteIconOption('heart', LucideIcons.heart),
  FavoriteIconOption('star', LucideIcons.star),
  FavoriteIconOption('music', LucideIcons.music),
  FavoriteIconOption('plane', LucideIcons.plane),
];

const Map<String, IconData> _favoriteIconMap = {
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

IconData iconForFavorite(String iconName) {
  return _favoriteIconMap[iconName] ?? LucideIcons.mapPin;
}

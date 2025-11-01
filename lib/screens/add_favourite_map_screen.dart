import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/favorites_service.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/validation_toast.dart';

class AddFavouriteMapScreen extends StatefulWidget {
  const AddFavouriteMapScreen({super.key});

  @override
  State<AddFavouriteMapScreen> createState() => _AddFavouriteMapScreenState();
}

class _AddFavouriteMapScreenState extends State<AddFavouriteMapScreen> {
  LatLng? _selectedLocation;
  String? _selectedLocationName;
  bool _isLoadingName = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CustomAppBar(
                  title: 'Add Favourite',
                  onBackButtonPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    styleString: themeProvider.mapStyleUrl,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(50.087, 14.420),
                      zoom: 13.0,
                    ),
                    myLocationEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    compassEnabled: false,
                    onMapLongClick: _onMapLongClick,
                  ),
                ),
              ],
            ),
            if (_selectedLocation != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: _buildSelectionCard(),
              ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {}

  void _onMapLongClick(math.Point<double> point, LatLng coordinates) {
    setState(() {
      _selectedLocation = coordinates;
      _selectedLocationName = null;
      _isLoadingName = true;
    });

    // Fetch location name
    _fetchLocationName(coordinates);
  }

  Future<void> _fetchLocationName(LatLng coordinates) async {
    try {
      final suggestion = await TransitousGeocodeService.reverseGeocode(
        place: coordinates,
      );
      if (mounted && _selectedLocation == coordinates) {
        setState(() {
          _selectedLocationName =
              suggestion?.name ??
              '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
          _isLoadingName = false;
        });
      }
    } catch (e) {
      if (mounted && _selectedLocation == coordinates) {
        setState(() {
          _selectedLocationName =
              '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
          _isLoadingName = false;
        });
      }
    }
  }

  Future<void> _saveFavourite() async {
    if (_selectedLocation == null) return;

    final name =
        _selectedLocationName ??
        '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}';

    final favorite = FavoritePlace(
      id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      lat: _selectedLocation!.latitude,
      lon: _selectedLocation!.longitude,
      addedAt: DateTime.now(),
    );

    try {
      await FavoritesService.saveFavorite(favorite);
      if (mounted) {
        showValidationToast(context, "Added to favourites");
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        showValidationToast(context, "Failed to add favourite");
      }
    }
  }

  Widget _buildSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0x66000000),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingName
                        ? const Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          )
                        : Text(
                            _selectedLocationName ?? 'Unknown location',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLocation = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x08000000),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _isLoadingName ? null : _saveFavourite,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isLoadingName
                          ? const Color(0x1A000000)
                          : AppColors.accentOf(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isLoadingName
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.accentOf(
                                  context,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: const Center(
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

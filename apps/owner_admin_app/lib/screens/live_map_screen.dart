import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_features/map_features.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/shop_detail_modal.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _mapController;
  String? _filterZoneId;
  String? _filterCategory;
  String? _filterUploadState; // null, 'verified', 'submitted', 'not_uploaded', 'rejected'
  Map<String, BitmapDescriptor> _categoryMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryMarkerIcons();
  }

  void _loadCategoryMarkerIcons() async {
    final markers = await CategoryMarkerHelper.preloadCategoryMarkerBitmaps();
    if (mounted) {
      setState(() {
        _categoryMarkers = markers;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);

    // Dhaka centroid default
    const defaultCenter = LatLng(23.8103, 90.3700);

    var filteredShops = dataProvider.shops;
    if (_filterZoneId != null) {
      filteredShops = filteredShops.where((s) => s.zoneId == _filterZoneId).toList();
    }
    if (_filterCategory != null) {
      filteredShops = filteredShops.where((s) => s.category == _filterCategory).toList();
    }
    if (_filterUploadState != null) {
      filteredShops = filteredShops.where((s) => s.todayUploadState == _filterUploadState).toList();
    }

    // Build Google Map vector markers
    final markers = filteredShops.map((shop) {
      final cat = ShopCategory.fromString(shop.category);
      final customIcon = _categoryMarkers[cat.displayName.toLowerCase()] ??
          _categoryMarkers[cat.name.toLowerCase()] ??
          CategoryMarkerHelper.getMarkerSync(cat);

      return Marker(
        markerId: MarkerId(shop.id),
        position: LatLng(shop.latitude, shop.longitude),
        icon: customIcon,
        infoWindow: InfoWindow(
          title: shop.shopName,
          snippet: '${cat.displayName} • ${shop.todayUploadState}',
          onTap: () => ShopDetailModal.show(context, shop),
        ),
        onTap: () => ShopDetailModal.show(context, shop),
      );
    }).toSet();

    return Stack(
      children: [
        // Interactive Google Map Vector Engine
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: defaultCenter,
            zoom: 12.5,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
          markers: markers,
          mapType: MapType.normal,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          onMapCreated: (controller) => _mapController = controller,
        ),

        // Floating Top Filter Bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: PointerInterceptor(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 12),

                    // Zone Filter
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _filterZoneId,
                          hint: Text(
                            locale.isBengali ? 'জোন নির্বাচন' : 'Filter Zone',
                            style: const TextStyle(fontSize: 12),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                locale.isBengali ? 'সকল জোন' : 'All Zones',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            ...dataProvider.zones.map(
                              (z) => DropdownMenuItem(
                                value: z.id,
                                child: Text(z.name, style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _filterZoneId = val);
                            if (val != null) {
                              final zoneShops = dataProvider.shops
                                  .where((s) => s.zoneId == val)
                                  .toList();
                              if (zoneShops.isNotEmpty) {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(zoneShops.first.latitude, zoneShops.first.longitude),
                                    14.0,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 20),

                    // Category Filter
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _filterCategory,
                          hint: Text(
                            locale.isBengali ? 'ক্যাটেগরি' : 'Category',
                            style: const TextStyle(fontSize: 12),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                locale.isBengali ? 'সকল ক্যাটেগরি' : 'All Categories',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'tea_stall',
                              child: Text(
                                locale.t('cat_tea_stall'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'food_stall',
                              child: Text(
                                locale.t('cat_food_stall'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'vegetable_shop',
                              child: Text(
                                locale.t('cat_vegetable_shop'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'fish_shop',
                              child: Text(
                                locale.t('cat_fish_shop'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'grocery_shop',
                              child: Text(
                                locale.t('cat_grocery_shop'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'pharmacy',
                              child: Text(
                                locale.t('cat_pharmacy'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _filterCategory = val),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 20),

                    // Upload Status Filter
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _filterUploadState,
                          hint: Text(
                            locale.isBengali ? 'আপলোড অবস্থা' : 'Upload Status',
                            style: const TextStyle(fontSize: 12),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                locale.isBengali ? 'সকল অবস্থা' : 'All States',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'verified',
                              child: Text(
                                locale.t('status_verified'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'submitted',
                              child: Text(
                                locale.t('status_submitted'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'not_uploaded',
                              child: Text(
                                locale.t('status_not_uploaded'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'rejected',
                              child: Text(
                                locale.t('status_rejected'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _filterUploadState = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating Legend at Bottom-Left
        Positioned(
          bottom: 24,
          left: 24,
          child: PointerInterceptor(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locale.isBengali ? 'মার্কার নির্দেশিকা' : 'Status Legend',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(AppTheme.statusGreen, locale.t('status_verified')),
                    const SizedBox(height: 4),
                    _buildLegendItem(AppTheme.accent, locale.t('status_submitted')),
                    const SizedBox(height: 4),
                    _buildLegendItem(AppTheme.statusYellow, locale.t('status_not_uploaded')),
                    const SizedBox(height: 4),
                    _buildLegendItem(AppTheme.statusRed, locale.t('status_rejected')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

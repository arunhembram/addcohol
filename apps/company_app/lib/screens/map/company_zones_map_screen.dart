import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_features/map_features.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:go_router/go_router.dart';
import '../../providers/company_state_providers.dart';
import '../shops/company_shop_detail_modal.dart';
import '../shops/company_enlarged_photo_dialog.dart';
import 'widgets/campaign_timeline_widget.dart';
import 'widgets/company_profile_dialog.dart';

class CompanyZonesMapScreen extends ConsumerStatefulWidget {
  const CompanyZonesMapScreen({super.key});

  @override
  ConsumerState<CompanyZonesMapScreen> createState() =>
      _CompanyZonesMapScreenState();
}

class _CompanyZonesMapScreenState extends ConsumerState<CompanyZonesMapScreen> {
  static const double kZoneDetailZoomThreshold = 15.0;

  double _zoom = 12.8;
  double _centerLat = 22.5850;
  double _centerLng = 88.3550; // Centered to frame all Kolkata, Howrah & Salt Lake zones
  String? _selectedZoneId;
  String? _hoveredZoneId;
  String? _selectedFilter; // null = All, 'shops' = Shops, 'saloons' = Saloons
  GoogleMapController? _googleMapController;
  Timer? _remoteSyncTimer;

  Map<String, BitmapDescriptor> _categoryMarkers = {};
  final Map<String, BitmapDescriptor> _zoneBadgeMarkers = {};
  final Map<String, BitmapDescriptor> _photoMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryMarkerIcons();

    // 1. Initial live synchronization from sync server
    CanonicalZones.syncWithRemote().then((_) {
      if (mounted) {
        ref.invalidate(companyAllZonesProvider);
        ref.invalidate(companyAssignedZonesProvider);
        ref.invalidate(companyAssignedShopsProvider);
      }
    });

    // 2. Periodic sync timer every 2 seconds to dynamically capture Master Admin changes
    _remoteSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final updated = await CanonicalZones.syncWithRemote();
      if (updated && mounted) {
        ref.invalidate(companyAllZonesProvider);
        ref.invalidate(companyAssignedZonesProvider);
        ref.invalidate(companyAssignedShopsProvider);
      }
    });
  }

  void _loadCategoryMarkerIcons() async {
    final markers = await CategoryMarkerHelper.preloadCategoryMarkerBitmaps();
    if (mounted) {
      setState(() {
        _categoryMarkers = markers;
      });
    }
  }

  void _loadZoneBadgeMarkers(List<Zone> zones) async {
    for (final zone in zones) {
      if (!_zoneBadgeMarkers.containsKey(zone.id)) {
        final icon = await ZoneBadgeMarkerHelper.getZoneBadgeBitmap(
          zoneId: zone.id,
          zoneName: zone.name,
          color: _parseHexColor(zone.colorHex),
        );
        if (mounted) {
          setState(() {
            _zoneBadgeMarkers[zone.id] = icon;
          });
        }
      }
    }
  }

  void _loadPhotoMarkers(List<CompanyVisibleShop> shops) async {
    final missing = shops.where((s) => s.hasPhoto && !_photoMarkers.containsKey(s.id)).toList();
    if (missing.isEmpty) return;

    for (final shop in missing) {
      if (!mounted) return;
      final category = ShopCategory.fromString(shop.category);
      final formattedDate = shop.photoUpdatedAt != null
          ? '${shop.photoUpdatedAt!.day} ${_monthName(shop.photoUpdatedAt!.month)} ${shop.photoUpdatedAt!.year}'
          : '10 Oct 2026';

      final marker = await PhotoMarkerHelper.getPhotoMarkerBitmap(
        shopId: shop.id,
        categoryName: category.displayName,
        formattedDate: formattedDate,
      );
      if (mounted) {
        setState(() {
          _photoMarkers[shop.id] = marker;
        });
      }
    }
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  LatLng _getZoneCenter(Zone zone) {
    if (zone.vertices.isEmpty) return const LatLng(22.5726, 88.3639);
    final avgLat = zone.vertices.map((v) => v.latitude).reduce((a, b) => a + b) /
        zone.vertices.length;
    final avgLng = zone.vertices.map((v) => v.longitude).reduce((a, b) => a + b) /
        zone.vertices.length;
    return LatLng(avgLat, avgLng);
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) {
      return AppColors.primary;
    }
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _focusOnZone(Zone zone, {double zoomLevel = 16.5}) {
    setState(() {
      _selectedZoneId = zone.id;
      _hoveredZoneId = zone.id;
    });
    if (zone.vertices.isNotEmpty) {
      final center = _getZoneCenter(zone);
      _centerLat = center.latitude;
      _centerLng = center.longitude;
      _zoom = zoomLevel;
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          center,
          zoomLevel,
        ),
      );
    }
  }

  void _fitAllZones(List<Zone> zones) {
    if (zones.isEmpty) return;
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    int vertexCount = 0;
    for (final z in zones) {
      for (final v in z.vertices) {
        if (v.latitude < minLat) minLat = v.latitude;
        if (v.latitude > maxLat) maxLat = v.latitude;
        if (v.longitude < minLng) minLng = v.longitude;
        if (v.longitude > maxLng) maxLng = v.longitude;
        vertexCount++;
      }
    }
    if (vertexCount > 0) {
      final centerLat = (minLat + maxLat) / 2.0;
      final centerLng = (minLng + maxLng) / 2.0;
      setState(() {
        _centerLat = centerLat;
        _centerLng = centerLng;
        _zoom = 13.8;
        _selectedZoneId = null;
        _hoveredZoneId = null;
      });
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(centerLat, centerLng),
          13.8,
        ),
      );
    }
  }

  void _detectZoneAtCameraCenter(List<Zone> zones) {
    if (zones.isEmpty) return;

    final targetVertex = ZoneVertex(
      sequenceOrder: 0,
      latitude: _centerLat,
      longitude: _centerLng,
    );

    // 1. Primary check: Is camera center coordinate directly inside a zone?
    for (final z in zones) {
      if (z.vertices.length >= 3 &&
          PolygonGeometry.isPointInsidePolygon(targetVertex, z.vertices)) {
        if (_hoveredZoneId != z.id) {
          setState(() {
            _hoveredZoneId = z.id;
          });
        }
        return;
      }
    }

    // 2. Proximity check: If not inside any polygon (e.g. zoomed out or in-between),
    // find the zone whose center is closest to current camera position
    Zone? closestZone;
    double minDistanceSquared = double.infinity;

    for (final z in zones) {
      final center = _getZoneCenter(z);
      final dLat = center.latitude - _centerLat;
      final dLng = center.longitude - _centerLng;
      final distSq = (dLat * dLat) + (dLng * dLng);

      if (distSq < minDistanceSquared) {
        minDistanceSquared = distSq;
        closestZone = z;
      }
    }

    if (closestZone != null && _hoveredZoneId != closestZone.id) {
      setState(() {
        _hoveredZoneId = closestZone!.id;
      });
    }
  }

  Set<Polygon> _buildGoogleMapPolygons(List<Zone> zones) {
    final activeId = _hoveredZoneId ?? _selectedZoneId;
    final isZoomedIn = _zoom >= kZoneDetailZoomThreshold;

    return zones.where((z) => z.vertices.length >= 3).map((z) {
      final color = _parseHexColor(z.colorHex);
      final isHovered = (z.id == activeId);

      return Polygon(
        polygonId: PolygonId(z.id),
        points: z.vertices.map((v) => LatLng(v.latitude, v.longitude)).toList(),
        fillColor: color.withValues(alpha: isHovered ? 0.35 : 0.18),
        strokeColor: color,
        strokeWidth: isHovered ? 4 : 2,
        geodesic: true,
        consumeTapEvents: !isZoomedIn,
        onTap: isZoomedIn ? null : () => _focusOnZone(z, zoomLevel: 16.5),
      );
    }).toSet();
  }

  Set<Marker> _buildGoogleMapMarkers({
    required List<Zone> zones,
    required List<CompanyVisibleShop> allShops,
    required bool canViewDailyProof,
  }) {
    final Set<Marker> markers = {};

    // Mutually exclusive Level-of-Detail (LOD):
    // When zoomed out (< 15.0):
    //   Show ONLY the "Select [Zone Name]" center button.
    //   DO NOT show ANY shop icons, completely preventing accidental taps on shops!
    // When zoomed in (>= 15.0):
    //   "Select [Zone Name]" button disappears.
    //   Shop icons appear on the streets.
    final isZoomedIn = _zoom >= kZoneDetailZoomThreshold;

    if (!isZoomedIn) {
      // 1. In-map Zone Center "Select [Zone Name]" Buttons
      for (final zone in zones) {
        final center = _getZoneCenter(zone);
        final badgeIcon = _zoneBadgeMarkers[zone.id];

        markers.add(
          Marker(
            markerId: MarkerId('zone_center_badge_${zone.id}'),
            position: center,
            icon: badgeIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 10,
            infoWindow: InfoWindow(
              title: 'Select ${zone.name}',
              snippet: 'Tap to zoom in and view retail shops',
              onTap: () {
                _focusOnZone(zone, zoomLevel: 16.5);
              },
            ),
            onTap: () {
              _focusOnZone(zone, zoomLevel: 16.5);
            },
          ),
        );
      }
    } else {
      // 2. Retail Shop Category Markers (Only visible when zoomed in >= 15.0)
      // Strictly Agreed & Active shops for Company (Never show follow-ups or un-agreed leads)
      final agreedShops = allShops.where((s) => s.isActive).toList();
      final filtered = _selectedFilter == 'shops'
          ? agreedShops
              .where((s) =>
                  ShopCategory.fromString(s.category) != ShopCategory.saloon)
              .toList()
          : _selectedFilter == 'saloons'
              ? agreedShops
                  .where((s) =>
                      ShopCategory.fromString(s.category) == ShopCategory.saloon)
                  .toList()
              : agreedShops;

      for (final shop in filtered) {
        final category = ShopCategory.fromString(shop.category);
        final hasPhoto = shop.hasPhoto;
        final photoMarker = _photoMarkers[shop.id];

        // When photo is uploaded, category icon disappears and is replaced by square photo marker!
        // When no photo (e.g. closed on Monday / missed), standard category icon remains.
        final iconToUse = (hasPhoto && photoMarker != null)
            ? photoMarker
            : (_categoryMarkers[category.displayName.toLowerCase()] ??
                _categoryMarkers[category.name.toLowerCase()] ??
                CategoryMarkerHelper.getMarkerSync(category));

        markers.add(
          Marker(
            markerId: MarkerId(shop.id),
            position: LatLng(shop.latitude, shop.longitude),
            icon: iconToUse,
            anchor: hasPhoto ? const Offset(0.5, 1.0) : const Offset(0.5, 0.5),
            zIndexInt: hasPhoto ? 10 : 5,
            infoWindow: InfoWindow(
              title: shop.shopName,
              snippet: hasPhoto
                  ? '${category.displayName} • Tap to enlarge photo proof'
                  : '${category.displayName} • Tap for details',
              onTap: () {
                if (hasPhoto) {
                  CompanyEnlargedPhotoDialog.show(context, shop: shop);
                } else {
                  CompanyShopDetailModal.show(
                    context,
                    shop: shop,
                    canViewDailyProof: canViewDailyProof,
                  );
                }
              },
            ),
            onTap: () {
              if (hasPhoto) {
                CompanyEnlargedPhotoDialog.show(context, shop: shop);
              } else {
                CompanyShopDetailModal.show(
                  context,
                  shop: shop,
                  canViewDailyProof: canViewDailyProof,
                );
              }
            },
          ),
        );
      }
    }

    return markers;
  }

  @override
  void dispose() {
    _remoteSyncTimer?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(companyAuthProvider);
    final company = authState.company;
    final zonesAsync = ref.watch(companyAllZonesProvider);
    final shopsAsync = ref.watch(companyAssignedShopsProvider);
    final theme = Theme.of(context);

    final canViewDailyProof = company?.canViewDailyProof ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Left: No Company Logo, No Company Name
        centerTitle: true,
        // Center: Active Zone Selector Dropdown
        title: zonesAsync.when(
          data: (zones) {
            if (zones.isEmpty) {
              return const Text('Booked Territories');
            }
            final activeZoneId = _hoveredZoneId ?? _selectedZoneId ?? zones.first.id;
            final activeZone = zones.firstWhere(
              (z) => z.id == activeZoneId,
              orElse: () => zones.first,
            );
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1.0,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (_selectedZoneId == null && _hoveredZoneId == null)
                      ? 'all_zones'
                      : activeZone.id,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                  dropdownColor: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all_zones',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_rounded, color: Color(0xFF38BDF8), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'All Assigned Territories',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...zones.map((z) {
                      final color = _parseHexColor(z.colorHex);
                      return DropdownMenuItem<String>(
                        value: z.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              z.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (newZoneId) {
                    if (newZoneId == 'all_zones') {
                      _fitAllZones(zones);
                    } else if (newZoneId != null) {
                      final target = zones.firstWhere((z) => z.id == newZoneId);
                      _focusOnZone(target);
                    }
                  },
                ),
              ),
            );
          },
          loading: () => const Text('Loading...'),
          error: (e, s) => const Text('Advertising Territories'),
        ),
        actions: [
          // Right: Profile Avatar / Dropdown with company name
          PopupMenuButton<String>(
            tooltip: company?.tradeName ?? 'Company Profile',
            offset: const Offset(0, 48),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            onSelected: (val) {
              if (val == 'profile' && company != null) {
                CompanyProfileDialog.show(context, company: company);
              } else if (val == 'audit_report') {
                final currentZoneName = zonesAsync.value?.firstWhere(
                      (z) => z.id == (_hoveredZoneId ?? _selectedZoneId ?? ''),
                      orElse: () => zonesAsync.value!.first,
                    ).name ?? 'Campaign Zone';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0F172A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                    content: Row(
                      children: [
                        const Icon(Icons.file_download_done_rounded, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Downloading Campaign Audit Report (PDF/Excel) for $currentZoneName...',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.business_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '${company?.tradeName ?? "Company"} Profile',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'audit_report',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Download Campaign Audit Report (PDF/Excel)',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: const Color(0xFF334155), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (company?.tradeName.isNotEmpty == true)
                          ? company!.tradeName[0].toUpperCase()
                          : 'B',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    company?.tradeName ?? 'Britannia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      body: zonesAsync.when(
        data: (zones) {
          if (zones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: AppColors.neutral400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Assigned Zones Available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Your company account is awaiting zone allocation by the Master Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.neutral600),
                    ),
                  ],
                ),
              ),
            );
          }

          // Preload center badges for all assigned zones
          _loadZoneBadgeMarkers(zones);

          final allShops = shopsAsync.value ?? [];

          // Preload custom square photo markers for verified shops
          if (allShops.isNotEmpty) {
            _loadPhotoMarkers(allShops);
          }

          // Active zone determination (defaults to first zone if none explicitly selected)
          final activeZoneId = _hoveredZoneId ?? _selectedZoneId ?? zones.first.id;
          final activeZone = zones.firstWhere(
            (z) => z.id == activeZoneId,
            orElse: () => zones.first,
          );
          final activeZoneShops =
              allShops.where((s) => s.zoneId == activeZone.id).toList();

          final saloonsCount = allShops
              .where((s) =>
                  ShopCategory.fromString(s.category) == ShopCategory.saloon)
              .length;
          final retailShopsCount = allShops
              .where((s) =>
                  ShopCategory.fromString(s.category) != ShopCategory.saloon)
              .length;

          return Stack(
            children: [
              // 1. Google Maps Vector Map - ALL assigned zones rendered simultaneously
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_centerLat, _centerLng),
                    zoom: _zoom,
                  ),
                  mapType: MapType.normal,
                  polygons: _buildGoogleMapPolygons(zones), // Always render ALL assigned zone polygons!
                  markers: _buildGoogleMapMarkers(
                    zones: zones,
                    allShops: allShops,
                    canViewDailyProof: canViewDailyProof,
                  ),
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                  },
                  onCameraMove: (position) {
                    final oldZoom = _zoom;
                    _centerLat = position.target.latitude;
                    _centerLng = position.target.longitude;
                    _zoom = position.zoom;

                    // Immediately re-render when crossing 15.0 threshold
                    // to toggle between Select Zone buttons and shop icons
                    final crossedThreshold =
                        (oldZoom < kZoneDetailZoomThreshold &&
                            _zoom >= kZoneDetailZoomThreshold) ||
                        (oldZoom >= kZoneDetailZoomThreshold &&
                            _zoom < kZoneDetailZoomThreshold);

                    if (crossedThreshold) {
                      setState(() {});
                    }

                    // Dynamically update the active zone based on which zone the camera is closest to / covering
                    _detectZoneAtCameraCenter(zones);
                  },
                  onCameraIdle: () {
                    _detectZoneAtCameraCenter(zones);
                    setState(() {});
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),

              // 2. Dynamic Brand Takeover Banner & Interactive Campaign Slot Timeline
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: PointerInterceptor(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: CampaignTimelineWidget(
                        companyName: company?.tradeName ?? 'Britannia',
                        zoneName: activeZone.name,
                        onActiveSlotTap: () {
                          // Center/zoom on shops with live photo proof in this zone
                          final shopsWithPhoto = activeZoneShops.where((s) => s.hasPhoto).toList();
                          if (shopsWithPhoto.isNotEmpty) {
                            _googleMapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(shopsWithPhoto.first.latitude, shopsWithPhoto.first.longitude),
                                16.5,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Filter Buttons: Only 3 options (All, Shops, Saloons)
              Positioned(
                top: 136,
                left: 12,
                right: 12,
                child: PointerInterceptor(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. All Button
                          ActionChip(
                            avatar: Icon(
                              Icons.apps_rounded,
                              size: 16,
                              color: _selectedFilter == null
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            label: Text('All (${allShops.length})'),
                            backgroundColor: _selectedFilter == null
                                ? AppColors.primary
                                : Colors.white,
                            labelStyle: TextStyle(
                              color: _selectedFilter == null
                                  ? Colors.white
                                  : AppColors.neutral800,
                              fontWeight: _selectedFilter == null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onPressed: () =>
                                setState(() => _selectedFilter = null),
                          ),
                          const SizedBox(width: AppSpacing.xs),

                          // 2. Shops Button (covers meat, fish, grocery, pharmacy, clothing, etc.)
                          ActionChip(
                            avatar: Icon(
                              Icons.storefront_rounded,
                              size: 16,
                              color: _selectedFilter == 'shops'
                                  ? Colors.white
                                  : const Color(0xFF2E7D32),
                            ),
                            label: Text('Shops ($retailShopsCount)'),
                            backgroundColor: _selectedFilter == 'shops'
                                ? AppColors.primary
                                : Colors.white,
                            labelStyle: TextStyle(
                              color: _selectedFilter == 'shops'
                                  ? Colors.white
                                  : AppColors.neutral800,
                              fontWeight: _selectedFilter == 'shops'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedFilter =
                                    _selectedFilter == 'shops' ? null : 'shops';
                              });
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),

                          // 3. Saloons Button
                          ActionChip(
                            avatar: Icon(
                              Icons.content_cut_rounded,
                              size: 16,
                              color: _selectedFilter == 'saloons'
                                  ? Colors.white
                                  : const Color(0xFF7B1FA2),
                            ),
                            label: Text('Saloons ($saloonsCount)'),
                            backgroundColor: _selectedFilter == 'saloons'
                                ? AppColors.primary
                                : Colors.white,
                            labelStyle: TextStyle(
                              color: _selectedFilter == 'saloons'
                                  ? Colors.white
                                  : AppColors.neutral800,
                              fontWeight: _selectedFilter == 'saloons'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedFilter =
                                    _selectedFilter == 'saloons' ? null : 'saloons';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Floating Zoom & Recenter Controls (Above bottom dock)
              Positioned(
                right: AppSpacing.sm,
                bottom: 88,
                child: PointerInterceptor(
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'companyMapZoomIn',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.neutral900,
                        tooltip: 'Zoom in',
                        child: const Icon(Icons.add),
                        onPressed: () {
                          _googleMapController?.animateCamera(
                            CameraUpdate.zoomIn(),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FloatingActionButton.small(
                        heroTag: 'companyMapZoomOut',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.neutral900,
                        tooltip: 'Zoom out',
                        child: const Icon(Icons.remove),
                        onPressed: () {
                          _googleMapController?.animateCamera(
                            CameraUpdate.zoomOut(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 5. FIXED-SIZE BOTTOM-CENTER FLOATING ACTION DOCK
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: PointerInterceptor(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                            color: _parseHexColor(activeZone.colorHex),
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _parseHexColor(activeZone.colorHex)
                                    .withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeZone.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${activeZoneShops.length} Agreed Partner Shops Active',
                                    style: const TextStyle(
                                      color: AppColors.neutral400,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Dropdown button: "View more zones"
                                  PopupMenuButton<Zone>(
                                    tooltip: 'View more zones',
                                    color: const Color(0xFF1E293B),
                                    elevation: 8,
                                    offset: const Offset(0, -10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.md),
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    onSelected: (selectedZone) {
                                      _focusOnZone(selectedZone, zoomLevel: 13.8);
                                    },
                                    itemBuilder: (context) {
                                      return zones.map((z) {
                                        final isCurrent = z.id == activeZone.id;
                                        final shopCount = allShops
                                            .where((s) => s.zoneId == z.id)
                                            .length;
                                        return PopupMenuItem<Zone>(
                                          value: z,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: _parseHexColor(z.colorHex),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  z.name,
                                                  style: TextStyle(
                                                    color: isCurrent
                                                        ? AppColors.primary
                                                        : Colors.white,
                                                    fontWeight: isCurrent
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$shopCount shops',
                                                style: const TextStyle(
                                                  color: AppColors.neutral400,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              if (isCurrent) ...[
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(AppRadii.sm),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'View more zones',
                                              style: TextStyle(
                                                color: _parseHexColor(activeZone.colorHex),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 16,
                                            color: _parseHexColor(activeZone.colorHex),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.md),
                                ),
                              ),
                              icon: const Icon(Icons.touch_app_rounded,
                                  size: 16),
                              label: const Text(
                                'Book Zone',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () {
                                context.push(
                                  '/book-ad-space',
                                  extra: activeZone,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: AppSpacing.sm),
              Text('Failed to load assigned territories: $err'),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: () {
                  ref.invalidate(companyAssignedZonesProvider);
                  ref.invalidate(companyAssignedShopsProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

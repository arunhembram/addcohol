import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_features/map_features.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../providers/master_admin_providers.dart';
import 'widgets/zone_admin_dashboard_panel.dart';

/// Full-screen interactive Map Cockpit for Master Admin.
/// Opens directly to Kolkata/West Bengal vector map with zero clutter.
///
/// Features:
/// - Clean map screen (No top search bar, No drawer button, No reset/recenter button).
/// - Floating "Create Zone" button on map (opens existing polygon creator).
/// - Floating "Materials" button on map (opens universal materials screen).
/// - Clicking any zone polygon or center badge marker opens the Assigned Admin Dashboard
///   with live toggles (Normal/Distribution mode, Ad campaigns, Material drives)
///   plus Master Admin superpowers:
///   1. Zone Pricing Configuration (Stand/Saloon A5/A6, Design & Print fee) strictly isolated to that zone.
///   2. Change Admin Code & Expel button (zero disruption to field operations or ad schedules).
class MasterZonesMapScreen extends ConsumerStatefulWidget {
  final String? initialZoneId;

  const MasterZonesMapScreen({super.key, this.initialZoneId});

  @override
  ConsumerState<MasterZonesMapScreen> createState() =>
      _MasterZonesMapScreenState();
}

class _MasterZonesMapScreenState extends ConsumerState<MasterZonesMapScreen> {
  static const double kZoneDetailZoomThreshold = 15.8;

  double _zoom = 13.8;
  double _centerLat = 22.5760;
  double _centerLng = 88.4020; // Overview of Kolkata

  String? _selectedZoneId;
  String? _hoveredZoneId;
  Zone? _selectedZoneForDashboard;

  // Google Maps Controller
  GoogleMapController? _googleMapController;

  // Selected Shop for preview sheet
  Shop? _selectedShop;

  // Custom Category Markers & Zone Badge Markers
  Map<String, BitmapDescriptor> _categoryMarkers = {};
  final Map<String, BitmapDescriptor> _zoneBadgeMarkers = {};
  bool _blinkToggle = false;
  Timer? _blinkTimer;

  // Real-time dragging state for moving zones from the middle
  final Map<String, List<ZoneVertex>> _draggedZoneVertices = {};
  final Map<String, LatLng> _draggedZoneCenters = {};

  @override
  void initState() {
    super.initState();
    _selectedZoneId = widget.initialZoneId;
    _hoveredZoneId = widget.initialZoneId;
    _loadCategoryMarkerIcons();

    // 700ms interval for blinking overdue follow-up markers
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() {
        _blinkToggle = !_blinkToggle;
      });
    });
  }

  void _loadCategoryMarkerIcons() async {
    await CategoryMarkerHelper.preloadAllMarkers();
    final markers = await CategoryMarkerHelper.preloadCategoryMarkerBitmaps();
    if (mounted) {
      setState(() {
        _categoryMarkers = markers;
      });
    }
  }

  void _loadZoneBadgeMarkers(List<Zone> zones) async {
    for (final zone in zones) {
      final hasAdmin = zone.assignedAdminId != null && zone.assignedAdminId!.isNotEmpty;
      final badgeKey = '${zone.id}_${hasAdmin ? "admin" : "no_admin"}';
      if (!_zoneBadgeMarkers.containsKey(badgeKey)) {
        final icon = await ZoneBadgeMarkerHelper.getZoneBadgeBitmap(
          zoneId: zone.id,
          zoneName: zone.name,
          color: _parseHexColor(zone.colorHex),
          isDraggable: false,
          hasAdmin: hasAdmin,
        );
        if (mounted) {
          setState(() {
            _zoneBadgeMarkers[badgeKey] = icon;
          });
        }
      }
    }
  }

  LatLng _getZoneCenter(Zone zone) {
    final effectiveVertices = _draggedZoneVertices[zone.id] ?? zone.vertices;
    if (effectiveVertices.isEmpty) return const LatLng(22.5726, 88.3639);
    final avgLat = effectiveVertices.map((v) => v.latitude).reduce((a, b) => a + b) /
        effectiveVertices.length;
    final avgLng = effectiveVertices.map((v) => v.longitude).reduce((a, b) => a + b) /
        effectiveVertices.length;
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

  void _focusOnZone(Zone zone, {double zoomLevel = 15.8}) {
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
        CameraUpdate.newLatLngZoom(center, zoomLevel),
      );
    }
  }

  void _openZoneDashboard(Zone zone) {
    _focusOnZone(zone, zoomLevel: 15.8);
    setState(() {
      _selectedZoneForDashboard = zone;
      _selectedShop = null;
    });
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

    // 2. Proximity check: If not inside any polygon, find closest zone center
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

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  Set<Polygon> _buildGoogleMapPolygons(List<Zone> zones) {
    final activeId = _selectedZoneForDashboard?.id ?? _hoveredZoneId ?? _selectedZoneId;

    return zones.where((z) => z.vertices.length >= 3).map((zone) {
      final color = _parseHexColor(zone.colorHex);
      final isHovered = (zone.id == activeId);
      final effectiveVertices = _draggedZoneVertices[zone.id] ?? zone.vertices;

      return Polygon(
        polygonId: PolygonId(zone.id),
        points: effectiveVertices.map((v) => LatLng(v.latitude, v.longitude)).toList(),
        strokeColor: color,
        strokeWidth: isHovered ? 4 : 2,
        fillColor: color.withValues(alpha: isHovered ? 0.35 : 0.18),
        geodesic: true,
        consumeTapEvents: true,
        onTap: () => _openZoneDashboard(zone),
      );
    }).toSet();
  }

  Set<Marker> _buildGoogleMapMarkers({
    required List<Zone> zones,
    required List<Shop> shops,
  }) {
    final markers = <Marker>{};
    final isZoomedIn = _zoom >= kZoneDetailZoomThreshold;

    // 1. Zone Center Badge Markers (Tap opens Zone Dashboard. Middle dragging is strictly enabled in Zone Editor)
    for (final zone in zones) {
      final center = _draggedZoneCenters[zone.id] ?? _getZoneCenter(zone);
      final hasAdmin = zone.assignedAdminId != null && zone.assignedAdminId!.isNotEmpty;
      final badgeKey = '${zone.id}_${hasAdmin ? "admin" : "no_admin"}';
      final badgeIcon = _zoneBadgeMarkers[badgeKey];

      markers.add(
        Marker(
          markerId: MarkerId('zone_center_badge_${zone.id}'),
          position: center,
          draggable: false,
          icon: badgeIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 25,
          infoWindow: InfoWindow(
            title: zone.name,
            snippet: hasAdmin ? 'Assigned • Tap to open dashboard' : '⚪ No Admin • Tap to configure',
            onTap: () => _openZoneDashboard(zone),
          ),
          onTap: () => _openZoneDashboard(zone),
        ),
      );
    }

    if (isZoomedIn) {
      // 2. Retail Shop Category Markers
      for (final shop in shops) {
        final cat = ShopCategory.fromString(shop.category);
        final isClosedToday = CanonicalShops.isShopClosedToday(shop.id);
        final isWeeklyClosed = shop.isWeeklyClosedToday();
        final BitmapDescriptor customIcon;
        if (shop.isFollowup) {
          customIcon = CategoryMarkerHelper.getShopMarkerSync(
            shop: shop,
            blinkToggle: _blinkToggle,
          );
        } else if (isClosedToday || isWeeklyClosed) {
          customIcon = CategoryMarkerHelper.getClosedShopMarkerSync();
        } else {
          customIcon = _categoryMarkers[cat.displayName.toLowerCase()] ??
              _categoryMarkers[cat.name.toLowerCase()] ??
              CategoryMarkerHelper.getMarkerSync(cat);
        }

        markers.add(
          Marker(
            markerId: MarkerId(shop.id),
            position: LatLng(shop.latitude, shop.longitude),
            icon: customIcon,
            zIndexInt: shop.isFollowup ? 10 : 1,
            infoWindow: InfoWindow(
              title: shop.shopName,
              snippet: shop.isFollowup
                  ? (shop.isFollowupMissed
                      ? '⚠️ Overdue Follow-up • ${cat.displayName}'
                      : (shop.isFollowupToday
                          ? '🔔 Follow-up Today • ${cat.displayName}'
                          : '📅 Follow-up Scheduled • ${cat.displayName}'))
                  : '${shop.ownerName ?? "Unknown"} • ${cat.displayName} (${shop.status.toUpperCase()})',
            ),
            onTap: () {
              setState(() {
                _selectedShop = shop;
              });
            },
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesListProvider);
    final shopsAsync = ref.watch(masterAdminShopsProvider);

    return Scaffold(
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text('Failed to load zones: $error'),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(zonesListProvider),
                ),
              ],
            ),
          ),
        ),
        data: (allZones) {
          final activeZones = allZones.where((z) => !z.isArchived).toList();
          final zonesList = activeZones.isNotEmpty ? activeZones : allZones;

          if (zonesList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No zones configured in the system.'),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Create First Zone',
                    icon: Icons.add_location_alt,
                    onPressed: () => context.push(
                        '/zones/create?lat=$_centerLat&lng=$_centerLng&zoom=$_zoom'),
                  ),
                ],
              ),
            );
          }

          _loadZoneBadgeMarkers(zonesList);

          // If initial zone ID requested and not set
          if (widget.initialZoneId != null && _selectedZoneForDashboard == null) {
            final match = zonesList.where((z) => z.id == widget.initialZoneId).firstOrNull;
            if (match != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedZoneForDashboard == null) {
                  _openZoneDashboard(match);
                }
              });
            }
          }

          final allShops = shopsAsync.asData?.value ?? [];
          final isLargeScreen = MediaQuery.of(context).size.width >= 820;
          final totalBookingsCount = CanonicalZones.all
              .fold<int>(0, (sum, z) => sum + CanonicalZones.getCompanyAdRuns(z.id).length);

          return Stack(
            children: [
              // 1. Google Maps Vector View
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_centerLat, _centerLng),
                    zoom: _zoom,
                  ),
                  mapType: MapType.normal,
                  polygons: _buildGoogleMapPolygons(zonesList),
                  markers: _buildGoogleMapMarkers(
                    zones: zonesList,
                    shops: allShops,
                  ),
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                  },
                  onCameraMove: (position) {
                    final oldZoom = _zoom;
                    _centerLat = position.target.latitude;
                    _centerLng = position.target.longitude;
                    _zoom = position.zoom;

                    final crossedThreshold =
                        (oldZoom < kZoneDetailZoomThreshold &&
                            _zoom >= kZoneDetailZoomThreshold) ||
                        (oldZoom >= kZoneDetailZoomThreshold &&
                            _zoom < kZoneDetailZoomThreshold);

                    if (crossedThreshold) {
                      setState(() {});
                    }

                    _detectZoneAtCameraCenter(zonesList);
                  },
                  onCameraIdle: () {
                    _detectZoneAtCameraCenter(zonesList);
                    setState(() {});
                  },
                  onTap: (_) {
                    if (_selectedShop != null) {
                      setState(() => _selectedShop = null);
                    }
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),

              // 2. FLOATING ACTION BUTTONS (Create Zone & Materials)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: PointerInterceptor(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Floating Button 1: Create Zone
                          Material(
                            elevation: 5,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            color: const Color(0xFF0F2A43),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.full),
                              onTap: () async {
                                await context.push(
                                    '/zones/create?lat=$_centerLat&lng=$_centerLng&zoom=$_zoom');
                                ref.invalidate(zonesListProvider);
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Create Zone',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Floating Button 2: Materials (Universal materials created screen)
                          Material(
                            elevation: 5,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.full),
                              onTap: () => context.push('/distribution/materials'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F9D8A), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Materials',
                                      style: TextStyle(
                                        color: Color(0xFF0F2A43),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F9D8A).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${CanonicalZones.getAllMaterials().length}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F9D8A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Floating Button: Admins (Admin Directory & Code generator)
                          Material(
                            elevation: 5,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.full),
                              onTap: () => context.push('/admins'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_outlined, color: Color(0xFF7C3AED), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Admins',
                                      style: TextStyle(
                                        color: Color(0xFF0F2A43),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Floating Button 3: View All Bookings (Prominent Cockpit Pill Button)
                          Material(
                            elevation: 5,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.full),
                              onTap: () => context.push('/bookings'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadii.full),
                                  border: Border.all(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7), size: 19),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'View All Bookings',
                                      style: TextStyle(
                                        color: Color(0xFF0F2A43),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '$totalBookingsCount',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. SELECTED SHOP PREVIEW (if clicked while zoomed in)
              if (_selectedShop != null)
                Positioned(
                  left: 16,
                  right: isLargeScreen && _selectedZoneForDashboard != null ? 500 : 16,
                  bottom: 24,
                  child: PointerInterceptor(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _MasterShopPreviewCard(
                          shop: _selectedShop!,
                          onClose: () => setState(() => _selectedShop = null),
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. ASSIGNED ADMIN ZONE DASHBOARD & MASTER CONTROLS
              // Appears when any existing zone is clicked
              if (_selectedZoneForDashboard != null)
                isLargeScreen
                    ? Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: 480,
                        child: PointerInterceptor(
                          child: ZoneAdminDashboardPanel(
                            zone: _selectedZoneForDashboard!,
                            shops: allShops
                                .where((s) => s.zoneId == _selectedZoneForDashboard!.id)
                                .toList(),
                            onClose: () => setState(() => _selectedZoneForDashboard = null),
                            onEditPolygon: () =>
                                context.push('/zones/${_selectedZoneForDashboard!.id}/edit'),
                          ),
                        ),
                      )
                    : Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: MediaQuery.of(context).size.height * 0.75,
                        child: PointerInterceptor(
                          child: ZoneAdminDashboardPanel(
                            zone: _selectedZoneForDashboard!,
                            shops: allShops
                                .where((s) => s.zoneId == _selectedZoneForDashboard!.id)
                                .toList(),
                            onClose: () => setState(() => _selectedZoneForDashboard = null),
                            onEditPolygon: () =>
                                context.push('/zones/${_selectedZoneForDashboard!.id}/edit'),
                          ),
                        ),
                      ),
            ],
          );
        },
      ),
    );
  }
}

class _MasterShopPreviewCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onClose;

  const _MasterShopPreviewCard({required this.shop, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final category = ShopCategory.fromString(shop.category);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(category.icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    shop.shopName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (shop.shopCode != null) ...[
                AppBadge(
                  label: 'Code: ${shop.shopCode}',
                  variant: AppBadgeVariant.success,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              AppBadge(
                label: shop.isAgreed ? 'Agreed & Active' : 'Pending Agreement',
                variant: shop.isAgreed ? AppBadgeVariant.success : AppBadgeVariant.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Category: ${category.displayName}',
                style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Owner: ${shop.ownerName ?? "N/A"} • Phone: ${shop.phoneNumber ?? "N/A"}',
            style: const TextStyle(fontSize: 12, color: AppColors.neutral800),
          ),
          Text(
            'Address: ${shop.address}',
            style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_features/map_features.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/admin_state_providers.dart';
import 'widgets/distribution_category_select_dialog.dart';
import 'widgets/zone_distribution_sheet.dart';

class ControlledZoneMapScreen extends ConsumerStatefulWidget {
  final String zoneId;

  const ControlledZoneMapScreen({super.key, required this.zoneId});

  @override
  ConsumerState<ControlledZoneMapScreen> createState() =>
      _ControlledZoneMapScreenState();
}

class _ControlledZoneMapScreenState
    extends ConsumerState<ControlledZoneMapScreen> {
  static const double kZoneDetailZoomThreshold = 15.8;

  double _zoom = 13.8;
  double _centerLat = 22.5760;
  double _centerLng = 88.4020; // Centered overview matching Company Map

  String? _selectedZoneId;
  String? _hoveredZoneId;

  // Google Maps Controller
  GoogleMapController? _googleMapController;

  // Places Search state
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  bool _isSearching = false;
  List<PlaceSearchResult> _searchResults = [];
  bool _showSearchResults = false;
  PlaceSearchResult? _selectedSearchedPlace;

  // Selected Shop for preview sheet
  Shop? _selectedShop;

  // Custom Category Markers & Zone Badge Markers
  Map<String, BitmapDescriptor> _categoryMarkers = {};
  final Map<String, BitmapDescriptor> _zoneBadgeMarkers = {};
  bool _blinkToggle = false;
  Timer? _blinkTimer;
  Timer? _remoteSyncTimer;
  DateTime? _lastLocalToggleTime;

  @override
  void initState() {
    super.initState();
    _selectedZoneId = widget.zoneId;
    _hoveredZoneId = widget.zoneId;

    // Auto-center map camera position directly on the target zone
    final targetZone = CanonicalZones.all.firstWhere(
      (z) => z.id == widget.zoneId,
      orElse: () => CanonicalZones.kolkataCentral,
    );
    if (targetZone.vertices.isNotEmpty) {
      final center = _getZoneCenter(targetZone);
      _centerLat = center.latitude;
      _centerLng = center.longitude;
      _zoom = 15.5;
    }

    _loadCategoryMarkerIcons();

    // 700ms interval for blinking overdue follow-up markers (alternates blue and orange)
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() {
        _blinkToggle = !_blinkToggle;
      });
    });

    // 2-second interval to sync distribution state across ports
    _remoteSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      if (_lastLocalToggleTime != null &&
          DateTime.now().difference(_lastLocalToggleTime!).inSeconds < 4) {
        return;
      }
      final updated = await CanonicalZones.syncWithRemote();
      if (updated && mounted) {
        ref.read(zoneDistributionModeStateProvider(widget.zoneId).notifier).state =
            CanonicalZones.isDistributionModeActive(widget.zoneId);
        ref.read(zoneDistributionCategoriesProvider(widget.zoneId).notifier).state =
            CanonicalZones.getDistributionCategories(widget.zoneId);
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(ControlledZoneMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoneId != widget.zoneId) {
      _selectedZoneId = widget.zoneId;
      _hoveredZoneId = widget.zoneId;
      final targetZone = CanonicalZones.all.firstWhere(
        (z) => z.id == widget.zoneId,
        orElse: () => CanonicalZones.kolkataCentral,
      );
      if (targetZone.vertices.isNotEmpty) {
        _focusOnZone(targetZone, zoomLevel: 15.5);
      }
    }
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
      final hasEmp = CanonicalZones.hasAssignedEmployee(zone.id);
      final cacheKey = '${zone.id}_emp_$hasEmp';
      if (!_zoneBadgeMarkers.containsKey(cacheKey)) {
        final icon = await ZoneBadgeMarkerHelper.getZoneBadgeBitmap(
          zoneId: zone.id,
          zoneName: zone.name,
          color: _parseHexColor(zone.colorHex),
          hasEmployee: hasEmp,
        );
        if (mounted) {
          setState(() {
            _zoneBadgeMarkers[cacheKey] = icon;
            _zoneBadgeMarkers[zone.id] = icon;
          });
        }
      }
    }
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
        CameraUpdate.newLatLngZoom(center, zoomLevel),
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
    _remoteSyncTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounceTimer?.cancel();
    final clean = query.trim();
    if (clean.length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await PlaceSearchService.search(clean);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _showSearchResults = results.isNotEmpty;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _onSelectPlace(PlaceSearchResult place) {
    setState(() {
      _selectedSearchedPlace = place;
      _searchController.text = place.name;
      _showSearchResults = false;
      _centerLat = place.latitude;
      _centerLng = place.longitude;
      _zoom = 15.5;
    });

    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.latitude, place.longitude), 15.5),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigated to "${place.name}".'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAdminDirections(Shop shop) async {
    final lat = shop.latitude;
    final lng = shop.longitude;
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleAdminCall(Shop shop) async {
    final phone = shop.phoneNumber?.replaceAll(RegExp(r'\D'), '');
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for this shop.')),
      );
    }
  }

  void _handleAdminApprove(Shop shop) {
    CanonicalShops.approveShop(shop.id);
    ref.invalidate(controlledShopsProvider);
    setState(() {
      _selectedShop = CanonicalShops.getShopById(shop.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ "${shop.shopName}" approved successfully and is now Live!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _handleAdminDelete(Shop shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shop?'),
        content: Text('Are you sure you want to permanently delete "${shop.shopName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              CanonicalShops.deleteShop(shop.id);
              ref.invalidate(controlledShopsProvider);
              setState(() {
                _selectedShop = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ "${shop.shopName}" deleted.'),
                  backgroundColor: const Color(0xFFEF4444),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    setState(() => _zoom = (_zoom + 1).clamp(2.0, 19.0));
    _googleMapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    setState(() => _zoom = (_zoom - 1).clamp(2.0, 19.0));
    _googleMapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Set<Polygon> _buildGoogleMapPolygons(List<Zone> zones) {
    final activeId = _hoveredZoneId ?? _selectedZoneId;
    final isZoomedIn = _zoom >= kZoneDetailZoomThreshold;

    return zones.where((z) => z.vertices.length >= 3).map((zone) {
      final color = _parseHexColor(zone.colorHex);
      final isHovered = (zone.id == activeId);

      return Polygon(
        polygonId: PolygonId(zone.id),
        points: zone.vertices.map((v) => LatLng(v.latitude, v.longitude)).toList(),
        strokeColor: color,
        strokeWidth: isHovered ? 4 : 2,
        fillColor: color.withValues(alpha: isHovered ? 0.35 : 0.18),
        geodesic: true,
        consumeTapEvents: !isZoomedIn,
        onTap: isZoomedIn ? null : () => _focusOnZone(zone, zoomLevel: 16.5),
      );
    }).toSet();
  }

  Set<Marker> _buildGoogleMapMarkers({
    required List<Zone> zones,
    required List<Shop> shops,
    required bool isDistributionMode,
  }) {
    final markers = <Marker>{};
    final isZoomedIn = _zoom >= kZoneDetailZoomThreshold;

    if (!isZoomedIn) {
      // 1. In-map Zone Center "Select [Zone Name]" Badge Markers (Overview mode)
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
              onTap: () => _focusOnZone(zone, zoomLevel: 16.5),
            ),
            onTap: () => _focusOnZone(zone, zoomLevel: 16.5),
          ),
        );
      }
    } else {
      // 2. Retail Shop Category Markers (Only visible when zoomed in >= 15.0)
      for (final shop in shops) {
        // When in distribution mode:
        // 1. Strictly hide follow-up shops
        // 2. Vanish already distributed shops
        if (isDistributionMode) {
          if (shop.isFollowup) continue;
          if (shop.isDistributed) continue;
          if (!CanonicalZones.isShopCategoryTargeted(shop.zoneId, shop.category)) continue;
        }

        final cat = ShopCategory.fromString(shop.category);
        final isClosedToday = CanonicalShops.isShopClosedToday(shop.id);
        final isWeeklyClosed = shop.isWeeklyClosedToday();
        final isCrossed = CanonicalZones.isShopCrossed(shop.zoneId, shop.id);
        final BitmapDescriptor customIcon;
        if (shop.isFollowup) {
          customIcon = CategoryMarkerHelper.getShopMarkerSync(
            shop: shop,
            blinkToggle: _blinkToggle,
          );
        } else if (isClosedToday || isWeeklyClosed) {
          customIcon = CategoryMarkerHelper.getClosedShopMarkerSync();
        } else if (isCrossed) {
          customIcon = CategoryMarkerHelper.getRedCrossMarkerSync();
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
              snippet: isDistributionMode
                  ? '📦 Distribution Target • ${cat.displayName}'
                  : (shop.isFollowup
                      ? (shop.isFollowupMissed
                          ? '⚠️ Overdue Follow-up • ${cat.displayName}'
                          : (shop.isFollowupToday
                              ? '🔔 Follow-up Today • ${cat.displayName}'
                              : '📅 Follow-up Scheduled • ${cat.displayName}'))
                      : '${shop.ownerName ?? "Unknown"} • ${cat.displayName} (${shop.status.toUpperCase()})'),
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

    if (_selectedSearchedPlace != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('searched_place_marker'),
          position: LatLng(
            _selectedSearchedPlace!.latitude,
            _selectedSearchedPlace!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: _selectedSearchedPlace!.name,
            snippet: _selectedSearchedPlace!.displayName,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final zoneDetailAsync = ref.watch(controlledZoneDetailProvider(widget.zoneId));
    final controlledZonesAsync = ref.watch(controlledZonesProvider);
    final employeesAsync = ref.watch(controlledEmployeesProvider);
    final shopsAsync = ref.watch(controlledShopsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: zoneDetailAsync.when(
          data: (zone) {
            final activeName = _hoveredZoneId == zone.id || _hoveredZoneId == null
                ? zone.name
                : (controlledZonesAsync.asData?.value
                        .firstWhere(
                          (z) => z.id == _hoveredZoneId,
                          orElse: () => zone,
                        )
                        .name ??
                    zone.name);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$activeName (Controlled)',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppBadge(
                    label: 'Read-Only Boundary',
                    variant: AppBadgeVariant.neutral,
                  ),
                ],
              ),
            );
          },
          loading: () => const Text('Loading Controlled Zone...'),
          error: (err, st) => const Text('Zone Access Restricted'),
        ),
        actions: [
          // Distribution Mode Switch
          Builder(
            builder: (context) {
              final isDist = ref.watch(zoneDistributionModeStateProvider(widget.zoneId));
              final selectedCats = ref.watch(zoneDistributionCategoriesProvider(widget.zoneId));
              final adminId = ref.watch(currentAdminIdProvider);
              final allShops = shopsAsync.asData?.value ?? [];
              final currentZoneShops = allShops.where((s) => s.zoneId == widget.zoneId).toList();

              final totalShopsCount = currentZoneShops.where((s) => ShopCategory.fromString(s.category) != ShopCategory.saloon).length;
              final totalSaloonsCount = currentZoneShops.where((s) => ShopCategory.fromString(s.category) == ShopCategory.saloon).length;

              final bool isShopsEnabled = isDist && (
                selectedCats.isEmpty ||
                selectedCats.contains('All') ||
                selectedCats.contains('all') ||
                selectedCats.contains('Shops') ||
                selectedCats.contains('shops')
              );

              final bool isSaloonsEnabled = isDist && (
                selectedCats.isEmpty ||
                selectedCats.contains('All') ||
                selectedCats.contains('all') ||
                selectedCats.contains('Saloons') ||
                selectedCats.contains('saloon') ||
                selectedCats.contains('Saloon')
              );

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDist
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDist
                        ? const Color(0xFF2E7D32)
                        : Colors.grey.shade400,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 16,
                      color: isDist ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Distribution',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDist ? const Color(0xFF2E7D32) : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: isDist,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (val) {
                        _lastLocalToggleTime = DateTime.now();
                        if (val) {
                          if (CanonicalZones.isZoneDriveCompleted(widget.zoneId)) {
                            CanonicalZones.resetDistributionDrive(widget.zoneId);
                          }
                          final newCats = {'Shops', 'Saloons'};
                          CanonicalZones.setDistributionMode(widget.zoneId, true, categories: newCats);
                          ref.read(zoneDistributionModeStateProvider(widget.zoneId).notifier).state = true;
                          ref.read(zoneDistributionCategoriesProvider(widget.zoneId).notifier).state = newCats;
                          setState(() {});
                          unawaited(ref.read(adminRepositoryProvider).setZoneDistributionMode(
                                adminId: adminId,
                                zoneId: widget.zoneId,
                                enabled: true,
                                categories: newCats,
                              ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('সামগ্রী ও বিজ্ঞাপন বিতরণ চালু করা হয়েছে'),
                              backgroundColor: Color(0xFF2E7D32),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          CanonicalZones.setDistributionMode(widget.zoneId, false);
                          ref.read(zoneDistributionModeStateProvider(widget.zoneId).notifier).state = false;
                          setState(() {});
                          unawaited(ref.read(adminRepositoryProvider).setZoneDistributionMode(
                                adminId: adminId,
                                zoneId: widget.zoneId,
                                enabled: false,
                              ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('সামগ্রী ও বিজ্ঞাপন বিতরণ বন্ধ করা হয়েছে'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    if (isDist) ...[
                      const SizedBox(width: 8),
                      // Shops Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_outlined, size: 14, color: isShopsEnabled ? const Color(0xFF2E7D32) : Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            'Shops ($totalShopsCount)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isShopsEnabled ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                            ),
                          ),
                          Switch(
                            value: isShopsEnabled,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            activeColor: const Color(0xFF2E7D32),
                            onChanged: (val) {
                              _lastLocalToggleTime = DateTime.now();
                              final Set<String> newCats = {};
                              if (val) newCats.add('Shops');
                              if (isSaloonsEnabled) newCats.add('Saloons');

                              final bool newDist = newCats.isNotEmpty;
                              CanonicalZones.setDistributionMode(widget.zoneId, newDist, categories: newCats);
                              ref.read(zoneDistributionModeStateProvider(widget.zoneId).notifier).state = newDist;
                              ref.read(zoneDistributionCategoriesProvider(widget.zoneId).notifier).state = newCats;
                              setState(() {});

                              unawaited(ref.read(adminRepositoryProvider).setZoneDistributionMode(
                                    adminId: adminId,
                                    zoneId: widget.zoneId,
                                    enabled: newDist,
                                    categories: newCats,
                                  ));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      // Saloons Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_cut_outlined, size: 14, color: isSaloonsEnabled ? const Color(0xFF2E7D32) : Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            'Saloons ($totalSaloonsCount)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSaloonsEnabled ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                            ),
                          ),
                          Switch(
                            value: isSaloonsEnabled,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            activeColor: const Color(0xFF2E7D32),
                            onChanged: (val) {
                              _lastLocalToggleTime = DateTime.now();
                              final Set<String> newCats = {};
                              if (isShopsEnabled) newCats.add('Shops');
                              if (val) newCats.add('Saloons');

                              final bool newDist = newCats.isNotEmpty;
                              CanonicalZones.setDistributionMode(widget.zoneId, newDist, categories: newCats);
                              ref.read(zoneDistributionModeStateProvider(widget.zoneId).notifier).state = newDist;
                              ref.read(zoneDistributionCategoriesProvider(widget.zoneId).notifier).state = newCats;
                              setState(() {});

                              unawaited(ref.read(adminRepositoryProvider).setZoneDistributionMode(
                                    adminId: adminId,
                                    zoneId: widget.zoneId,
                                    enabled: newDist,
                                    categories: newCats,
                                  ));
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Manage Distribution & Print QR (A4 PDF)',
            icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0F2A43)),
            onPressed: () {
              final allShops = shopsAsync.asData?.value ?? [];
              final currentZoneShops = allShops.where((s) => s.zoneId == widget.zoneId).toList();
              final targetZone = zoneDetailAsync.asData?.value ??
                  controlledZonesAsync.asData?.value.firstWhere(
                    (z) => z.id == widget.zoneId,
                    orElse: () => CanonicalZones.kolkataCentral,
                  ) ??
                  CanonicalZones.kolkataCentral;
              ZoneDistributionSheet.show(
                context,
                zone: targetZone,
                shops: currentZoneShops,
              );
            },
          ),
          IconButton(
            tooltip: 'Reset Map View',
            icon: const Icon(Icons.my_location),
            onPressed: () {
              final targetZone = zoneDetailAsync.asData?.value ??
                  controlledZonesAsync.asData?.value.firstWhere(
                    (z) => z.id == (_selectedZoneId ?? widget.zoneId),
                    orElse: () => CanonicalZones.all.firstWhere(
                      (z) => z.id == (_selectedZoneId ?? widget.zoneId),
                      orElse: () => CanonicalZones.kolkataCentral,
                    ),
                  ) ??
                  CanonicalZones.all.firstWhere(
                    (z) => z.id == (_selectedZoneId ?? widget.zoneId),
                    orElse: () => CanonicalZones.kolkataCentral,
                  );
              _focusOnZone(targetZone, zoomLevel: 15.5);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: zoneDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final isForbidden = error is ForbiddenZoneException;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.gpp_bad_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      isForbidden ? 'Zone Access Denied' : 'Error Loading Zone',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.security, size: 20, color: AppColors.warning),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Security Rule: Admins cannot view or manage zones outside their explicit Master Admin assignment.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.neutral800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Return to My Controlled Zones',
                      icon: Icons.arrow_back,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        data: (initialZone) {
          // List of all controlled zones for this admin
          final allControlled = controlledZonesAsync.asData?.value ?? [initialZone];
          final activeZoneId = _hoveredZoneId ?? _selectedZoneId ?? initialZone.id;
          final activeZone = allControlled.firstWhere(
            (z) => z.id == activeZoneId,
            orElse: () => initialZone,
          );

          // Preload badge markers
          _loadZoneBadgeMarkers(allControlled);

          // All shops in controlled jurisdiction
          final allShops = shopsAsync.asData?.value ?? [];
          final activeZoneShops = allShops.where((s) => s.zoneId == activeZone.id).toList();

          final isDistMode = ref.watch(zoneDistributionModeStateProvider(widget.zoneId));
          final selectedCats = ref.watch(zoneDistributionCategoriesProvider(widget.zoneId));
          final targetShopsForZone = activeZoneShops.where((s) {
            if (s.isFollowup) return false;
            if (isDistMode && !CanonicalZones.isShopCategoryTargeted(s.zoneId, s.category)) return false;
            return true;
          }).toList();
          final totalDistCount = targetShopsForZone.length;
          final distributedDoneCount = targetShopsForZone.where((s) => s.isDistributed).length;
          final undistributedCount = totalDistCount - distributedDoneCount;

          // Filter employees assigned to this active zone
          final assignedEmployees = employeesAsync.maybeWhen(
            data: (list) => list.where((emp) {
              final zids = emp.metadata['assigned_zones'] as List<dynamic>? ?? [];
              return zids.contains(activeZone.id);
            }).toList(),
            orElse: () => <UserProfile>[],
          );

          final activeColor = _parseHexColor(activeZone.colorHex);

          return Stack(
            children: [
              // 1. Google Maps Vector View with LOD Zoom Threshold & Dynamic Polygons
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_centerLat, _centerLng),
                    zoom: _zoom,
                  ),
                  mapType: MapType.normal,
                  polygons: _buildGoogleMapPolygons(allControlled),
                  markers: _buildGoogleMapMarkers(
                    zones: allControlled,
                    shops: allShops,
                    isDistributionMode: isDistMode,
                  ),
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                    if (activeZone.vertices.isNotEmpty) {
                      _focusOnZone(activeZone, zoomLevel: 15.5);
                    }
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

                    _detectZoneAtCameraCenter(allControlled);
                  },
                  onCameraIdle: () {
                    _detectZoneAtCameraCenter(allControlled);
                    setState(() {});
                  },
                  onTap: (_) {
                    if (_showSearchResults) {
                      setState(() => _showSearchResults = false);
                    }
                    if (_selectedShop != null) {
                      setState(() => _selectedShop = null);
                    }
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),

              // 2. Floating Places Search Bar with live autocomplete
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: PointerInterceptor(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.full),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchQueryChanged,
                              decoration: InputDecoration(
                                hintText: 'Search place (e.g. Salt Lake, Howrah)...',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              _onSearchQueryChanged('');
                                            },
                                          )
                                        : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.full),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ),
                          if (_showSearchResults && _searchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _searchResults.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final place = _searchResults[idx];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                                    title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text(
                                      place.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onTap: () => _onSelectPlace(place),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2.5. Distribution Mode Progress Banner (when active)
              if (isDistMode)
                Positioned(
                  top: 72,
                  left: 16,
                  right: 16,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: PointerInterceptor(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_rounded, color: Colors.greenAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'সামগ্রী ও বিজ্ঞাপন বিতরণ মোড সক্রিয় (Distribution Mode Active)',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          (() {
                                            final hasShops = selectedCats.any((c) => c.toLowerCase() == 'shops' || c.toLowerCase() == 'shop');
                                            final hasSaloons = selectedCats.any((c) => c.toLowerCase() == 'saloons' || c.toLowerCase() == 'saloon');
                                            if (selectedCats.isEmpty || selectedCats.contains('All') || (hasShops && hasSaloons)) {
                                              return '🏷️ ক্যাটাগরি: সব দোকান ও সেলুন (Shops & Saloons)';
                                            } else if (hasShops) {
                                              return '🏷️ ক্যাটাগরি: দোকানসমূহ (Shops - সেলুন বাদে)';
                                            } else {
                                              return '🏷️ ক্যাটাগরি: সেলুনসমূহ (Saloons)';
                                            }
                                          })(),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.white12,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    ),
                                    icon: const Icon(Icons.tune_rounded, size: 13, color: Colors.white),
                                    label: const Text('ক্যাটাগরি বাছুন', style: TextStyle(fontSize: 11)),
                                    onPressed: () async {
                                      final adminId = ref.read(currentAdminIdProvider);
                                      final cats = await DistributionCategorySelectDialog.show(
                                        context,
                                        zoneId: widget.zoneId,
                                        zoneName: activeZone.name,
                                        initialCategories: selectedCats,
                                        zoneShops: activeZoneShops,
                                      );
                                      if (cats != null) {
                                        await ref.read(adminRepositoryProvider).setZoneDistributionMode(
                                              adminId: adminId,
                                              zoneId: widget.zoneId,
                                              enabled: true,
                                              categories: cats,
                                            );
                                        ref.read(zoneDistributionCategoriesProvider(widget.zoneId).notifier).state = cats;
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded, size: 13, color: Colors.white70),
                                    label: const Text('Reset', style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      CanonicalShops.resetDistributionForZone(widget.zoneId);
                                      ref.invalidate(controlledShopsProvider);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: totalDistCount == 0 ? 0 : (distributedDoneCount / totalDistCount),
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'বাকি আছে: $undistributedCount টি • বিতরণ সম্পন্ন: $distributedDoneCount / $totalDistCount টি',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(totalDistCount == 0 ? 0 : (distributedDoneCount * 100 / totalDistCount)).toStringAsFixed(0)}% সম্পন্ন',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Zoom Controls
              Positioned(
                right: AppSpacing.md,
                bottom: _selectedShop != null ? 360 : 180,
                child: PointerInterceptor(
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'adminZoomInBtn',
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FloatingActionButton.small(
                        heroTag: 'adminZoomOutBtn',
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Selected Shop Preview Card (if clicked)
              if (_selectedShop != null)
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: 180,
                  child: PointerInterceptor(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: _AdminShopPreviewCard(
                          shop: _selectedShop!,
                          onClose: () => setState(() => _selectedShop = null),
                          onDirections: () => _handleAdminDirections(_selectedShop!),
                          onApprove: () => _handleAdminApprove(_selectedShop!),
                          onCall: () => _handleAdminCall(_selectedShop!),
                          onDelete: () => _handleAdminDelete(_selectedShop!),
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Assigned Employees Card above bottom dock
              if (_selectedShop == null)
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: 84,
                  child: PointerInterceptor(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Assigned Employees in this Zone:',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.neutral700,
                                    ),
                                  ),
                                  AppBadge(
                                    label: '${assignedEmployees.length} Staff',
                                    variant: AppBadgeVariant.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (assignedEmployees.isEmpty)
                                Row(
                                  children: [
                                    const Text(
                                      'No employees assigned to this zone yet.',
                                      style: TextStyle(fontSize: 11, color: AppColors.neutral500),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      icon: const Icon(Icons.person_add_alt_1, size: 14),
                                      label: const Text('Assign Staff', style: TextStyle(fontSize: 11)),
                                      onPressed: () => context.push('/employees'),
                                    ),
                                  ],
                                )
                              else
                                SizedBox(
                                  height: 38,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: assignedEmployees.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: AppSpacing.xs),
                                    itemBuilder: (context, idx) {
                                      final emp = assignedEmployees[idx];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.neutral100,
                                          borderRadius:
                                              BorderRadius.circular(AppRadii.sm),
                                          border: Border.all(color: AppColors.neutral300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: AppColors.primary
                                                  .withValues(alpha: 0.15),
                                              child: Text(
                                                emp.fullName[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              emp.fullName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 6. Synchronized Bottom-Center Floating Action Dock (Same design as Company & Employee apps)
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
                            color: activeColor,
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
                                color: activeColor.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
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
                                    '${activeZoneShops.length} Registered Shops Active',
                                    style: const TextStyle(
                                      color: AppColors.neutral400,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  PopupMenuButton<Zone>(
                                    tooltip: 'View more zones',
                                    color: const Color(0xFF1E293B),
                                    elevation: 8,
                                    offset: const Offset(0, -10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadii.md),
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    onSelected: (selectedZone) {
                                      _focusOnZone(selectedZone, zoomLevel: 14.5);
                                    },
                                    itemBuilder: (context) {
                                      return allControlled.map((z) {
                                        final isCurrent = z.id == activeZone.id;
                                        final count = allShops.where((s) => s.zoneId == z.id).length;
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
                                                    color: isCurrent ? AppColors.primary : Colors.white,
                                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$count shops',
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
                                        borderRadius: BorderRadius.circular(AppRadii.sm),
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
                                                color: activeColor,
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
                                            color: activeColor,
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
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                ),
                              ),
                              icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                              label: const Text(
                                'Manage Staff',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () => context.push('/employees'),
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
      ),
    );
  }
}

class _AdminShopPreviewCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onClose;
  final VoidCallback? onDirections;
  final VoidCallback? onApprove;
  final VoidCallback? onCall;
  final VoidCallback? onDelete;

  const _AdminShopPreviewCard({
    required this.shop,
    required this.onClose,
    this.onDirections,
    this.onApprove,
    this.onCall,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = ShopCategory.fromString(shop.category);
    final isUnderProcess = shop.isUnderProcess;

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
              if (isUnderProcess)
                const AppBadge(
                  label: '⏳ Under Process',
                  variant: AppBadgeVariant.warning,
                )
              else
                AppBadge(
                  label: shop.isAgreed
                      ? 'Agreed & Active'
                      : (shop.isOverdue ? 'Overdue Follow-up' : 'Follow-up Pending'),
                  variant: shop.isAgreed
                      ? AppBadgeVariant.success
                      : (shop.isOverdue ? AppBadgeVariant.error : AppBadgeVariant.warning),
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
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          if (isUnderProcess) ...[
            // 3 options: Approve, Call, Delete
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: onApprove,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: onCall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Regular shop options: Direction and Call
            Row(
              children: [
                if (onDirections != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 18),
                      label: const Text('Direction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: onDirections,
                    ),
                  ),
                if (onDirections != null && onCall != null)
                  const SizedBox(width: 8),
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: onCall,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
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
import '../../providers/employee_state_providers.dart';
import 'services/map_reverse_geocode_service.dart';
import 'shop_operational_status.dart';
import 'widgets/full_size_photo_dialog.dart';
import 'widgets/shop_category_picker_modal.dart';
import 'widgets/shop_details_modal.dart';
import 'widgets/shop_distribution_handover_sheet.dart';
import 'widgets/shop_floating_action_card.dart';

class EmployeeZoneMapScreen extends ConsumerStatefulWidget {
  const EmployeeZoneMapScreen({super.key});

  @override
  ConsumerState<EmployeeZoneMapScreen> createState() =>
      _EmployeeZoneMapScreenState();
}

class _EmployeeZoneMapScreenState extends ConsumerState<EmployeeZoneMapScreen> {
  double _zoom = 13.8;
  double _centerLat = 22.5760;
  double _centerLng = 88.4020; // Centered overview matching Company Map
  bool _hasCenteredOnZone = false;
  Shop? _selectedShop;
  Timer? _liveClockTimer;
  String _lastKolkataBusinessDate = '';

  // Google Maps Controller
  GoogleMapController? _googleMapController;

  // Places Search state
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearching = false;
  List<PlaceSearchResult> _searchResults = [];
  bool _showSearchResults = false;
  PlaceSearchResult? _selectedSearchedPlace;

  // Selected Location for Shop Assignment (from Touch & Hold or Tap)
  LatLng? _pendingShopLocation;
  Zone? _pendingShopZone;

  // Place Shop Flow state (Ola/Uber style fixed center-pin flow)
  bool _isPlacingShop = false;
  ShopCategory? _placingCategory;
  LatLng? _placementOriginalPoint;
  bool _isPlacementInsideZone = false;
  Zone? _activePlacementZone;
  String? _placementResolvedAddress;
  bool _isResolvingAddress = false;
  Timer? _addressDebounce;
  bool _isLongPressProcessing = false;
  final Map<String, BitmapDescriptor> _categoryMarkerBitmaps = {};
  bool _blinkToggle = false;
  Timer? _blinkTimer;
  Timer? _remoteSyncTimer;

  static const double kZoneDetailZoomThreshold = 15.8;
  String? _selectedZoneId;
  String? _hoveredZoneId;
  String? _selectedCategoryFilter; // null = all, 'shops', 'saloons'
  final Map<String, BitmapDescriptor> _zoneBadgeMarkers = {};

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
  void initState() {
    super.initState();
    _lastKolkataBusinessDate = ShopOperationalService.getKolkataBusinessDate();
    _loadCategoryMarkerIcons();

    // 1-second interval to update live countdown in DD:HH:MM:SS and detect midnight rollover in Asia/Kolkata
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final currentKolkataDate = ShopOperationalService.getKolkataBusinessDate();
      if (currentKolkataDate != _lastKolkataBusinessDate) {
        _lastKolkataBusinessDate = currentKolkataDate;
        // Midnight rollover in Asia/Kolkata! Refresh status and daily uploads
        ref.invalidate(assignedShopsProvider);
        ref.invalidate(assignedShopsDailyUploadsProvider);
      }
      setState(() {});
    });

    // 700ms interval for blinking overdue follow-up markers (alternates blue and orange)
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() {
        _blinkToggle = !_blinkToggle;
      });
    });

    // Initial sync of zone distribution mode and distributed shops from Admin App
    CanonicalZones.syncWithRemote();

    int lastZonesRev = CanonicalZones.zonesRevision.value;
    int lastShopsRev = CanonicalShops.shopsRevision.value;

    // 2-second interval to sync distribution state across ports in real time
    _remoteSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      await CanonicalZones.syncWithRemote();
      if (!mounted) return;
      final zonesChanged = lastZonesRev != CanonicalZones.zonesRevision.value;
      final shopsChanged = lastShopsRev != CanonicalShops.shopsRevision.value;
      if (zonesChanged || shopsChanged) {
        lastZonesRev = CanonicalZones.zonesRevision.value;
        lastShopsRev = CanonicalShops.shopsRevision.value;
        ref.invalidate(assignedZonesProvider);
        ref.invalidate(assignedShopsProvider);
        ref.invalidate(filteredAssignedShopsProvider);
        setState(() {});
      }
    });
  }

  void _loadCategoryMarkerIcons() async {
    await CategoryMarkerHelper.preloadAllMarkers();
    for (final cat in ShopCategory.values) {
      final bitmap = await CategoryMarkerHelper.getCategoryMarkerBitmap(
        category: cat,
        color: AppColors.primary,
      );
      if (mounted) {
        setState(() {
          _categoryMarkerBitmaps[cat.displayName] = bitmap;
        });
      }
    }
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _blinkTimer?.cancel();
    _remoteSyncTimer?.cancel();
    _searchDebounce?.cancel();
    _addressDebounce?.cancel();
    _searchController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // 1. Also update shop search filter
    ref.read(shopSearchQueryProvider.notifier).state = query;

    // 2. Places autocomplete debounce
    _searchDebounce?.cancel();
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
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
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
        content: Text('Navigated to "${place.name}". Long-press to add a shop here if inside your zone.'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
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
    final isDistMode = ref.watch(employeeGlobalDistributionModeProvider);

    return zones.where((z) => z.vertices.length >= 3).map((zone) {
      final color = _parseHexColor(zone.colorHex);
      final isHovered = (zone.id == activeId);

      return Polygon(
        polygonId: PolygonId(zone.id),
        points: zone.vertices.map((v) => LatLng(v.latitude, v.longitude)).toList(),
        strokeColor: isDistMode ? const Color(0xFF0F9D8A) : color,
        strokeWidth: isHovered ? 4 : 2,
        fillColor: (isDistMode ? const Color(0xFF0F9D8A) : color)
            .withValues(alpha: isHovered ? 0.35 : 0.18),
        geodesic: true,
        consumeTapEvents: !isZoomedIn,
        onTap: isZoomedIn ? null : () => _focusOnZone(zone, zoomLevel: 16.5),
      );
    }).toSet();
  }

  void _setGlobalDistributionMode(bool enabled) {
    ref.read(employeeGlobalDistributionModeProvider.notifier).state = enabled;
    if (!enabled) {
      ref.read(selectedDistributionItemIdProvider.notifier).state = null;
      setState(() => _selectedCategoryFilter = null);
      ref.read(shopCategoryFilterProvider.notifier).state = null;
    }

    setState(() {
      if (enabled && _selectedShop != null && (_selectedShop!.isDistributed || _selectedShop!.isFollowup)) {
        _selectedShop = null;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              enabled ? Icons.local_shipping_rounded : Icons.storefront_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled
                        ? '📦 Distribution Mode ON (সকল অ্যাসাইন করা জোনে)'
                        : '🏬 Normal Mode ON (সকল অ্যাসাইন করা জোনে)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    enabled
                        ? 'সকল জোনের বাকি ডেলিভারির দোকানগুলি দৃশ্যমান (ডেলিভারি হলে ভ্যানিশ হবে)।'
                        : 'সকল জোনের সব দোকান দৃশ্যমান। নতুন দোকান যোগ বা তথ্য দেখতে পারেন।',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: enabled ? const Color(0xFF0F9D8A) : const Color(0xFF0F2A43),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Set<Marker> _buildGoogleMapMarkers({
    required List<Zone> zones,
    required List<Shop> shops,
    required Map<String, ShopDailyUpload> uploadsMap,
    required int graceMinutes,
    required DateTime? referenceTime,
    LocationCoords? gpsLocation,
  }) {
    final markers = <Marker>{};
    final isZoomedIn = _zoom >= kZoneDetailZoomThreshold;

    if (!isZoomedIn) {
      // 1. In-map Zone Center "Select [Zone Name]" Buttons (Overview mode)
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
      final catFilter = ref.read(shopCategoryFilterProvider) ?? _selectedCategoryFilter;
      final filtered = (catFilter?.toLowerCase() == 'shops' || catFilter?.toLowerCase() == 'shop')
          ? shops
              .where((s) =>
                  ShopCategory.fromString(s.category) != ShopCategory.saloon)
              .toList()
          : (catFilter?.toLowerCase() == 'saloons' || catFilter?.toLowerCase() == 'saloon')
              ? shops
                  .where((s) =>
                      ShopCategory.fromString(s.category) == ShopCategory.saloon)
                  .toList()
              : shops;

      final distItemId = ref.read(selectedDistributionItemIdProvider);

      for (final shop in filtered) {
        if (CanonicalShops.isShopGone(shop.id)) continue;

        final isDistActive = ref.read(employeeGlobalDistributionModeProvider);
        final isCrossed = CanonicalZones.isShopCrossed(shop.zoneId, shop.id);
        final isClosedToday = CanonicalShops.isShopClosedToday(shop.id);
        final isWeeklyClosed = shop.isWeeklyClosedToday(referenceTime);
        final isEffectivelyClosedToday = isClosedToday || isWeeklyClosed;

        // When in distribution mode for this shop's zone:
        // 1. Strictly hide follow-up shops
        // 2. Strictly hide under-process shops
        // 3. Vanish already distributed shops (or specific item distributed shops)
        if (isDistActive) {
          if (shop.isFollowup) continue;
          if (shop.isUnderProcess) continue;
          if (!CanonicalZones.isShopCategoryTargeted(shop.zoneId, shop.category)) continue;

          if (distItemId != null) {
            final itemTarget = CanonicalZones.getItemTargetBusinessType(shop.zoneId, distItemId);
            final isSaloon = ShopCategory.fromString(shop.category) == ShopCategory.saloon;
            if (itemTarget == 'saloon' && !isSaloon) continue;
            if (itemTarget == 'shop' && isSaloon) continue;

            // Vanish if this specific item is already distributed!
            if (CanonicalZones.isShopItemDistributed(shop.id, distItemId)) continue;
          } else {
            if (shop.isDistributed) continue;
          }
        }

        final todayUpload = uploadsMap[shop.id];
        final operationalStatus = ShopOperationalService.calculateStatus(
          shop: shop,
          todayUpload: todayUpload,
          referenceTime: referenceTime,
          gracePeriodMinutes: graceMinutes,
        );
        final category = ShopCategory.fromString(shop.category);
        final BitmapDescriptor markerIcon;
        if (isEffectivelyClosedToday) {
          markerIcon = CategoryMarkerHelper.getClosedShopMarkerSync();
        } else if (isCrossed) {
          markerIcon = CategoryMarkerHelper.getRedCrossMarkerSync();
        } else if (shop.isFollowup) {
          markerIcon = CategoryMarkerHelper.getShopMarkerSync(
            shop: shop,
            blinkToggle: _blinkToggle,
          );
        } else {
          final customIcon = _categoryMarkerBitmaps[category.displayName];
          markerIcon = customIcon ??
              BitmapDescriptor.defaultMarkerWithHue(operationalStatus.markerHue);
        }

        final String snippetText;
        if (isClosedToday) {
          snippetText = '🔒 দোকান আজ বন্ধ হিসেবে চিহ্নিত করা হয়েছে (কাল পুনরায় যাবেন) • ${shop.category}';
        } else if (isWeeklyClosed) {
          snippetText = '🔒 সাপ্তাহিক বন্ধ (Weekly Holiday: ${shop.weeklyClosedDay}) • ${shop.category}';
        } else if (isCrossed) {
          snippetText = '⚠️ আগের দিনের বিতরণ বাকি • ১০০ মিটারে গিয়ে সমাধান করুন';
        } else if (isDistActive) {
          snippetText = '📦 Distribution Target • ${shop.category}';
        } else if (shop.isUnderProcess) {
          snippetText = '⏳ Under Process (অনুমোদনাধীন) • ${shop.category}';
        } else if (shop.isFollowup) {
          if (shop.isFollowupMissed) {
            snippetText = '⚠️ Follow-up Missed (দেরি হয়ে গেছে) • ${shop.category}';
          } else if (shop.isFollowupToday) {
            snippetText = '🔔 Follow-up Today (আজকে ফলো-আপ) • ${shop.category}';
          } else {
            snippetText = '📅 Follow-up Scheduled • ${shop.category}';
          }
        } else {
          snippetText = '${operationalStatus.badgeText} (${operationalStatus.bengaliBadgeText}) • ${shop.category}';
        }

        markers.add(
          Marker(
            markerId: MarkerId(shop.id),
            position: LatLng(shop.latitude, shop.longitude),
            icon: markerIcon,
            zIndexInt: isEffectivelyClosedToday ? 20 : (isCrossed ? 15 : (shop.isFollowup ? 10 : 1)),
            infoWindow: InfoWindow(
              title: isClosedToday
                  ? '🔒 ${shop.shopName} (আজ বন্ধ • Visited)'
                  : (isWeeklyClosed
                      ? '🔒 ${shop.shopName} (সাপ্তাহিক বন্ধ • ${shop.weeklyClosedDay})'
                      : (isCrossed ? '❌ ${shop.shopName} (বিতরণ বাকি)' : shop.shopName)),
              snippet: snippetText,
              onTap: () {
                if (!_isPlacingShop) {
                  setState(() {
                    _selectedShop = shop;
                    _pendingShopLocation = null;
                    _pendingShopZone = null;
                  });
                }
              },
            ),
            onTap: () {
              if (!_isPlacingShop) {
                setState(() {
                  _selectedShop = shop;
                  _pendingShopLocation = null;
                  _pendingShopZone = null;
                });
              }
            },
          ),
        );
      }
    }

    if (gpsLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_device_gps_pin'),
          position: LatLng(gpsLocation.latitude, gpsLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndexInt: 105,
          infoWindow: const InfoWindow(
            title: 'My Position',
            snippet: 'Current device GPS coordinates',
          ),
        ),
      );
    }

    if (_selectedSearchedPlace != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('searched_place_location_pin'),
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

    if (_pendingShopLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pending_shop_assignment_pin'),
          position: _pendingShopLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: 'Selected Spot (${_pendingShopZone?.name ?? "Zone"})',
            snippet: 'Tap "Assign Shop at this Spot" to register',
          ),
        ),
      );
    }

    return markers;
  }

  void _openCategoryPickerForZone(Zone zone) async {
    final pickedCategory = await ShopCategoryPickerModal.show(context);
    if (pickedCategory == null || !mounted) return;
    final center = _getZoneCenter(zone);
    _enterPlacementMode(
      category: pickedCategory,
      initialPoint: center,
      initialZone: zone,
    );
  }

  void _recenterOnGps(LocationCoords? gps) {
    if (gps != null) {
      setState(() {
        _centerLat = gps.latitude;
        _centerLng = gps.longitude;
        _zoom = 15.0;
      });
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(gps.latitude, gps.longitude), 15.0),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered on current GPS device position.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acquiring device GPS location... Please ensure GPS is enabled.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  /// Handle map tap to drop proposed shop pin if inside assigned zone,
  /// or dismiss selected shop card when tapping elsewhere.
  void _onMapTapped(
    LatLng latLng,
    List<Zone> zones,
    LocationCoords? currentGps,
  ) {
    if (_showSearchResults) {
      setState(() => _showSearchResults = false);
      return;
    }

    // Dismiss selected shop floating card when tapping elsewhere
    if (_selectedShop != null) {
      setState(() => _selectedShop = null);
      return;
    }

    // Check if tapped inside an assigned zone
    final targetVertex = ZoneVertex(
      sequenceOrder: 0,
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
    Zone? matchedZone;
    for (final zone in zones) {
      if (PolygonGeometry.isPointInsidePolygon(targetVertex, zone.vertices)) {
        matchedZone = zone;
        break;
      }
    }

    if (matchedZone != null) {
      setState(() {
        _pendingShopLocation = latLng;
        _pendingShopZone = matchedZone;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location selected in "${matchedZone.name}". Tap "Assign Shop" below or Touch & Hold to create shop.',
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (_pendingShopLocation != null) {
        setState(() {
          _pendingShopLocation = null;
          _pendingShopZone = null;
        });
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Selected location is outside your assigned zones. Field employees can only add shops within authorized boundaries.',
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Handle long-press on map to add a new shop
  void _handleMapLongPress({
    required double lat,
    required double lng,
    required List<Zone> assignedZones,
    LocationCoords? gpsLocation,
  }) async {
    if (_isLongPressProcessing || _isPlacingShop) return;
    _isLongPressProcessing = true;

    try {
      // 1. Point-in-polygon containment check for assigned zones
      Zone? matchingZone;
      final targetVertex = ZoneVertex(sequenceOrder: 0, latitude: lat, longitude: lng);
      for (final zone in assignedZones) {
        if (PolygonGeometry.isPointInsidePolygon(targetVertex, zone.vertices)) {
          matchingZone = zone;
          break;
        }
      }

      if (matchingZone == null) {
        // PROHIBITED: Location is outside assigned zones!
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 48),
            title: const Text('Forbidden Location'),
            content: Text(
              'The selected location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}) '
              'is outside all of your assigned territory zones.\n\n'
              'Field Employees are strictly prohibited from adding shops outside assigned boundaries.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              AppButton(
                label: 'Understood',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
        return;
      }

      // 2. Check distance from device GPS
      if (gpsLocation != null) {
        final distanceMeters = _calculateDistanceMeters(
          lat,
          lng,
          gpsLocation.latitude,
          gpsLocation.longitude,
        );

        if (distanceMeters > 500) {
          // Warning: Far from device location
          if (!mounted) return;
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
              title: const Text('GPS Proximity Warning'),
              content: Text(
                'Selected point is ${distanceMeters.toStringAsFixed(0)} meters away from your current GPS position.\n\n'
                'Are you physically at or near this shop? Adding shops far from your real location may flag compliance audit.',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel / Re-select'),
                ),
                AppButton(
                  label: 'Proceed Anyway',
                  variant: AppButtonVariant.primary,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          );

          if (proceed != true) return;
        }
      }

      // 3. Open Category Picker before opening shop details form
      if (!mounted) return;
      final pickedCategory = await ShopCategoryPickerModal.show(context);
      if (pickedCategory == null || !mounted) return;

      // 4. Enter "Place Shop" mode
      _enterPlacementMode(
        category: pickedCategory,
        initialPoint: LatLng(lat, lng),
        initialZone: matchingZone,
      );
    } finally {
      _isLongPressProcessing = false;
    }
  }

  /// Enter Ola-style "Place Shop" mode with fixed center pin
  void _enterPlacementMode({
    required ShopCategory category,
    required LatLng initialPoint,
    required Zone initialZone,
  }) {
    setState(() {
      _isPlacingShop = true;
      _placingCategory = category;
      _placementOriginalPoint = initialPoint;
      _centerLat = initialPoint.latitude;
      _centerLng = initialPoint.longitude;
      _activePlacementZone = initialZone;
      _isPlacementInsideZone = true;
      _selectedShop = null;
      _pendingShopLocation = null;
      _pendingShopZone = null;
      _showSearchResults = false;
      _placementResolvedAddress = null;
    });

    _googleMapController?.animateCamera(
      CameraUpdate.newLatLng(initialPoint),
    );

    _triggerReverseGeocode(initialPoint.latitude, initialPoint.longitude);
  }

  /// Exit placement mode and restore normal map view
  void _cancelPlacementMode() {
    _addressDebounce?.cancel();
    setState(() {
      _isPlacingShop = false;
      _placingCategory = null;
      _placementOriginalPoint = null;
      _activePlacementZone = null;
      _placementResolvedAddress = null;
      _isResolvingAddress = false;
    });
  }

  /// Recenter the map to the original long-press coordinates
  void _recenterPlacement() {
    if (_placementOriginalPoint != null) {
      final orig = _placementOriginalPoint!;
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLng(orig),
      );
      setState(() {
        _centerLat = orig.latitude;
        _centerLng = orig.longitude;
        final targetVertex = ZoneVertex(
          sequenceOrder: 0,
          latitude: orig.latitude,
          longitude: orig.longitude,
        );
        Zone? matched;
        final zones = ref.read(assignedZonesProvider).asData?.value ?? [];
        for (final z in zones) {
          if (PolygonGeometry.isPointInsidePolygon(targetVertex, z.vertices)) {
            matched = z;
            break;
          }
        }
        _activePlacementZone = matched;
        _isPlacementInsideZone = matched != null;
      });
      _triggerReverseGeocode(orig.latitude, orig.longitude);
    }
  }

  /// Debounced reverse geocode for center coordinates
  void _triggerReverseGeocode(double lat, double lng) {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted || !_isPlacingShop) return;
      setState(() => _isResolvingAddress = true);
      final addr = await MapReverseGeocodeService.reverseGeocode(
        latitude: lat,
        longitude: lng,
      );
      if (mounted && _isPlacingShop) {
        setState(() {
          _placementResolvedAddress = addr;
          _isResolvingAddress = false;
        });
      }
    });
  }

  /// Validate and confirm location, navigating to /shop/add
  void _confirmPlacementLocation() {
    if (!_isPlacementInsideZone || _activePlacementZone == null || _placingCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot confirm location outside assigned zone boundaries.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmedLat = _centerLat;
    final confirmedLng = _centerLng;
    final zone = _activePlacementZone!;
    final category = _placingCategory!;

    // Exit placement mode
    _cancelPlacementMode();

    // Navigate to Add Shop form with prefilled values
    context.push(
      '/shop/add?zoneId=${zone.id}&zoneName=${Uri.encodeComponent(zone.name)}&lat=$confirmedLat&lng=$confirmedLng&category=${Uri.encodeComponent(category.displayName)}',
    );
  }

  double _calculateDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaPhi = (lat2 - lat1) * math.pi / 180.0;
    final deltaLambda = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // --- ACTIONS ---

  /// Action 1: Open official Google Maps navigation directly for destination shop
  Future<void> _handleDirections(Shop shop) async {
    setState(() => _selectedShop = null);

    final lat = shop.latitude;
    final lng = shop.longitude;
    final encodedTitle = Uri.encodeComponent(shop.shopName);

    // 1. Google Maps turn-by-turn navigation URI
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    // 2. Official Google Maps web directions URL
    final googleMapsDirUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    // 3. Fallback geo URI
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedTitle)');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleMapsDirUri)) {
        await launchUrl(googleMapsDirUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Maps app.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Google Maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Action: Confirm and mark pamphlet distribution complete for a shop
  Future<void> _confirmAndMarkDistributed(Shop shop) async {
    // 1. Verify current device GPS position
    final gpsLocation = ref.read(deviceLocationProvider).asData?.value;

    if (gpsLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ GPS অবস্থান পাওয়া যায়নি। দোকানে উপস্থিত হয়ে GPS অন করে আবার চেষ্টা করুন।',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Strict 100-meter physical proximity validation
    final distanceMeters = _calculateDistanceMeters(
      shop.latitude,
      shop.longitude,
      gpsLocation.latitude,
      gpsLocation.longitude,
    );

    if (distanceMeters > 100.0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.wrong_location_rounded, color: AppColors.error, size: 48),
          title: const Text('দোকানের ১০০ মিটারের মধ্যে যেতে হবে'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আপনি "${shop.shopName}" থেকে ${distanceMeters.toStringAsFixed(0)} মিটার দূরে আছেন।',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'বিতরণ সম্পন্ন মার্ক করতে হলে এমপ্লয়িকে শারীরিকভাবে দোকানে উপস্থিত হয়ে ১০০ মিটারের মধ্যে থাকতে হবে।\n\n'
                'অনুগ্রহ করে দোকানে পৌঁছান এবং তারপর "Done" চাপুন।',
                style: TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.social_distance, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      'বর্তমান দূরত্ব: ${distanceMeters.toStringAsFixed(0)}m (অনুমতি: ≤ 100m)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ঠিক আছে (Understood)'),
            ),
          ],
        ),
      );
      return;
    }

    // 3. Physically verified within 100 meters -> Two-step Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('বিতরণ নিশ্চিতকরণ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distributed to ${shop.shopName}?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '📍 দোকানের কাছে অবস্থান যাচাইকৃত (${distanceMeters.toStringAsFixed(0)} মি)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'আপনি কি নিশ্চিত যে "${shop.shopName}" দোকানে সামগ্রী ও বিজ্ঞাপন বিতরণ সম্পন্ন হয়েছে?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No / না', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes / হ্যাঁ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);
      await repo.markShopDistributed(
        employeeId: empId,
        shopId: shop.id,
      );
      final zoneId = shop.zoneId ?? '';
      final autoCompleted = CanonicalZones.checkAndAutoCompleteZone(zoneId);
      ref.invalidate(assignedShopsProvider);
      ref.invalidate(filteredAssignedShopsProvider);
      if (!mounted) return;
      setState(() {
        _selectedShop = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(autoCompleted
              ? '🎉 জোনের সব দোকানে বিতরণ সম্পন্ন! বিতরণ মোড স্বয়ংক্রিয়ভাবে বন্ধ হলো।'
              : '✅ Distributed to ${shop.shopName} (বিতরণ সম্পন্ন)'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _openHandoverChecklist(Shop shop) {
    ShopDistributionHandoverSheet.show(
      context,
      shop: shop,
      onSubmitted: () {
        final zoneId = shop.zoneId ?? '';
        final autoCompleted = CanonicalZones.checkAndAutoCompleteZone(zoneId);
        ref.invalidate(assignedShopsProvider);
        ref.invalidate(filteredAssignedShopsProvider);
        setState(() => _selectedShop = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(autoCompleted
                ? '🎉 জোনের সব দোকানে বিতরণ সম্পন্ন! বিতরণ মোড স্বয়ংক্রিয়ভাবে বন্ধ হলো।'
                : '✅ Distributed to ${shop.shopName} (বিতরণ সম্পন্ন)'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      },
      onMarkGone: () {
        final zoneId = shop.zoneId ?? '';
        final autoCompleted = CanonicalZones.checkAndAutoCompleteZone(zoneId);
        ref.invalidate(assignedShopsProvider);
        ref.invalidate(filteredAssignedShopsProvider);
        setState(() => _selectedShop = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${shop.shopName} দোকানটি নেই/স্থায়ীভাবে বন্ধ মার্ক করা হয়েছে'),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  /// Action: Mark shop closed today with opening time and 100-meter proximity validation
  Future<void> _handleMarkClosedToday(Shop shop) async {
    final refTime = ref.read(serverTimeReferenceProvider);

    // 0. Weekly holiday validation
    if (shop.isWeeklyClosedToday(refTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 "${shop.shopName}" আজ সাপ্তাহিক ছুটিতে বন্ধ (${shop.weeklyClosedDay})। এটি ইতিমধ্যেই বন্ধ হিসেবে প্রদর্শিত হচ্ছে।'),
          backgroundColor: const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // 1. Opening time validation (cannot mark closed if shop opens later today)
    final nowIst = ShopOperationalService.getKolkataNow(refTime);
    final openingIst = shop.parseOpeningTimeToday(refTime);

    if (openingIst != null && nowIst.isBefore(openingIst)) {
      final formattedOpening = shop.openingTime ?? 'সময় উল্লেখ নেই';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(
            Icons.access_time_filled_rounded,
            color: Color(0xFFE65100),
            size: 48,
          ),
          title: Text(
            "Shop's opening time is $formattedOpening",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'দোকান খোলার সময়: $formattedOpening\n(এখন বন্ধ চিহ্নিত করা যাবে না)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'দোকানটি খোলার নির্ধারিত সময় $formattedOpening। '
                'খোলার সময়ের আগে দোকানটিকে "আজ বন্ধ" (Closed Today) হিসেবে চিহ্নিত করা যাবে না।\n\n'
                'দোকান খোলার পর পুনরায় পরিদর্শন করে স্ট্যাটাস আপডেট করুন।',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ঠিক আছে (Understood)'),
            ),
          ],
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Shop's opening time is $formattedOpening (দোকান খোলার সময় $formattedOpening)"),
            backgroundColor: const Color(0xFFE65100),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // 2. GPS Proximity validation
    final gpsLocation = ref.read(deviceLocationProvider).asData?.value;
    if (gpsLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ GPS অবস্থান পাওয়া যায়নি। দোকানে গিয়ে GPS অন করুন।'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final distanceMeters = _calculateDistanceMeters(
      shop.latitude,
      shop.longitude,
      gpsLocation.latitude,
      gpsLocation.longitude,
    );

    if (distanceMeters > 100.0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.wrong_location_rounded, color: AppColors.error, size: 48),
          title: const Text('দোকানের ১০০ মিটারের মধ্যে যেতে হবে'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আপনি "${shop.shopName}" থেকে ${distanceMeters.toStringAsFixed(0)} মিটার দূরে আছেন।',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'দোকানটি আজ বন্ধ মার্ক করতে হলে শারীরিকভাবে দোকানে উপস্থিত হয়ে ১০০ মিটারের মধ্যে থাকতে হবে।',
                style: TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ঠিক আছে (Understood)'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('দোকান আজ বন্ধ?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${shop.shopName} - Closed Today?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              '📍 অবস্থান যাচাইকৃত (${distanceMeters.toStringAsFixed(0)} মিটারের মধ্যে)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'আপনি কি নিশ্চিত যে আজ দোকানটি বন্ধ আছে?\n\n'
              'এটি সংরক্ষণ করা হবে এবং ম্যাপে বন্ধ আইকন (🔒) হিসেবে প্রদর্শিত হবে যাতে আপনি বুঝতে পারেন আজ দোকানটিতে যাওয়া হয়েছিল কিন্তু বন্ধ ছিল। আগামীকাল আবার বিতরণ তালিকায় আসবে।',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('না / No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('হ্যাঁ, বন্ধ / Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);
      await repo.markShopClosedToday(employeeId: empId, shopId: shop.id);
      ref.invalidate(assignedShopsProvider);
      ref.invalidate(filteredAssignedShopsProvider);
      if (!mounted) return;
      setState(() {
        _selectedShop = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 "${shop.shopName}" আজ বন্ধ হিসেবে সংরক্ষিত (কাল আবার বিতরণ তালিকায় থাকবে)'),
          backgroundColor: const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Action: Mark shop GONE (permanently closed / vacated) with 100m proximity & danger confirmation
  Future<void> _confirmAndMarkGone(Shop shop) async {
    // 1. GPS Proximity validation
    final gpsLocation = ref.read(deviceLocationProvider).asData?.value;
    if (gpsLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ GPS অবস্থান পাওয়া যায়নি। দোকানে গিয়ে GPS অন করুন।'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final distanceMeters = _calculateDistanceMeters(
      shop.latitude,
      shop.longitude,
      gpsLocation.latitude,
      gpsLocation.longitude,
    );

    if (distanceMeters > 100.0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.wrong_location_rounded, color: AppColors.error, size: 48),
          title: const Text('দোকানের ১০০ মিটারের মধ্যে যেতে হবে'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আপনি "${shop.shopName}" থেকে ${distanceMeters.toStringAsFixed(0)} মিটার দূরে আছেন।',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'দোকানটি স্থায়ীভাবে বন্ধ বা স্থানান্তরিত মার্ক করতে হলে শারীরিকভাবে দোকানে উপস্থিত হয়ে ১০০ মিটারের মধ্যে থাকতে হবে।',
                style: TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ঠিক আছে (Understood)'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Permanent deletion / Gone confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text('দোকান স্থায়ীভাবে বন্ধ (Gone)?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permanently remove "${shop.shopName}"?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              '📍 অবস্থান যাচাইকৃত (${distanceMeters.toStringAsFixed(0)} মি)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.3)),
              ),
              child: const Text(
                '⚠️ সতর্কবার্তা: দোকান মালিক যদি দোকান চিরতরে বন্ধ করে থাকেন বা খালি করে থাকেন, তবেই "Gone" নির্বাচন করুন। এর ফলে দোকানটি ম্যাপ থেকে স্থায়ীভাবে মুছে যাবে!',
                style: TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('বাতিল / Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('স্থায়ীভাবে মুছুন (Confirm Gone)'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);
      await repo.markShopGone(employeeId: empId, shopId: shop.id);
      final zoneId = shop.zoneId ?? '';
      final autoCompleted = CanonicalZones.checkAndAutoCompleteZone(zoneId);
      ref.invalidate(assignedShopsProvider);
      ref.invalidate(filteredAssignedShopsProvider);
      if (!mounted) return;
      setState(() {
        _selectedShop = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(autoCompleted
              ? '🚫 "${shop.shopName}" মুছে ফেলা হয়েছে। 🎉 জোনের সকল বিতরণ সম্পন্ন হওয়ায় বিতরণ মোড বন্ধ হলো!'
              : '🚫 "${shop.shopName}" ম্যাপ থেকে মুছে ফেলা হয়েছে (Gone)'),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Action 4: Call Shopkeeper with missing-phone safety handling
  Future<void> _handleCallShop(Shop shop) async {
    final phone = shop.phoneNumber?.trim();
    if (phone == null || phone.isEmpty || phone == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number registered for this shop.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer for $phone.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open phone dialer for $phone.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Convert an existing follow-up shop to Agreed status
  void _convertFollowupToAgreed(Shop shop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update to Agreed Shop'),
        content: Text(
          'Are you sure you want to mark "${shop.shopName}" as Agreed?\n\n'
          'This will generate an immutable 8-digit Shop Code and activate this shop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Confirm & Generate Code',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);
      final updated = await repo.updateFollowupToAgreed(
        employeeId: empId,
        shopId: shop.id,
      );

      if (!mounted) return;

      setState(() => _selectedShop = updated);
      ref.invalidate(assignedShopsProvider);
      ref.invalidate(followupsTodayProvider);
      ref.invalidate(overdueFollowupsProvider);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 54),
          title: const Text('Shop Successfully Activated!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Server-Generated Immutable Shop Code for "${updated.shopName}":'),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: Text(
                  updated.shopCode ?? 'UNKNOWN',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Done',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update shop: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(employeeAuthProvider);
    final zonesAsync = ref.watch(assignedZonesProvider);
    final filteredShopsAsync = ref.watch(filteredAssignedShopsProvider);
    final gpsAsync = ref.watch(deviceLocationProvider);
    final followupsTodayAsync = ref.watch(followupsTodayProvider);
    final overdueAsync = ref.watch(overdueFollowupsProvider);
    final draftsAsync = ref.watch(offlineDraftsProvider);
    final currentCatFilter = ref.watch(shopCategoryFilterProvider);
    final dailyUploadsAsync = ref.watch(assignedShopsDailyUploadsProvider);
    final graceMinutes = ref.watch(photoGracePeriodMinutesProvider);
    final refTime = ref.watch(serverTimeReferenceProvider);
    final uploadsMap = dailyUploadsAsync.asData?.value ?? const {};
    final currentGps = gpsAsync.asData?.value;
    final zonesList = zonesAsync.asData?.value ?? [];
    final allShopsList = filteredShopsAsync.asData?.value ?? [];
    final activeZoneId = _hoveredZoneId ?? _selectedZoneId ?? (zonesList.isNotEmpty ? zonesList.first.id : '');
    final Zone? activeZone = zonesList.isNotEmpty
        ? zonesList.firstWhere(
            (z) => z.id == activeZoneId,
            orElse: () => zonesList.first,
          )
        : null;
    final activeZoneShops = activeZone != null
        ? allShopsList.where((s) => s.zoneId == activeZone.id).toList()
        : <Shop>[];

    final isGlobalDistActive = ref.watch(employeeGlobalDistributionModeProvider);
    final isDistributionModeActiveForCurrentZone = isGlobalDistActive;

    // Target distribution shops across ALL assigned zones
    final allAssignedDistributionShops = allShopsList.where((s) {
      if (s.isFollowup) return false;
      if (isGlobalDistActive && !CanonicalZones.isShopCategoryTargeted(s.zoneId, s.category)) {
        return false;
      }
      return true;
    }).toList();
    final totalUndistributedAllZones =
        allAssignedDistributionShops.where((s) => !s.isDistributed).length;

    final targetDistributionShops = activeZoneShops.where((s) {
      if (s.isFollowup) return false;
      if (isGlobalDistActive &&
          !CanonicalZones.isShopCategoryTargeted(s.zoneId, s.category)) {
        return false;
      }
      return true;
    }).toList();
    final totalDistCount = targetDistributionShops.length;
    final distributedDoneCount =
        targetDistributionShops.where((s) => s.isDistributed).length;
    final undistributedCount = totalDistCount - distributedDoneCount;

    // Calculate status for currently selected shop
    ShopOperationalStatus? selectedShopStatus;
    if (_selectedShop != null) {
      final upload = uploadsMap[_selectedShop!.id];
      selectedShopStatus = ShopOperationalService.calculateStatus(
        shop: _selectedShop!,
        todayUpload: upload,
        referenceTime: refTime,
        gracePeriodMinutes: graceMinutes,
      );
    }

    return PopScope(
      canPop: !_isPlacingShop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isPlacingShop) {
          _cancelPlacementMode();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Interactive Google Map with Assigned Zones and Shop Pins
            zonesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Failed to load assigned zones: $err'),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Retry',
                        onPressed: () => ref.invalidate(assignedZonesProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (zones) {
                _loadZoneBadgeMarkers(zones);
                return filteredShopsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading shops: $err')),
                  data: (shops) {
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_centerLat, _centerLng),
                        zoom: _zoom,
                      ),
                      mapType: MapType.normal,
                      polygons: _buildGoogleMapPolygons(zones),
                      markers: _buildGoogleMapMarkers(
                        zones: zones,
                        shops: shops,
                        uploadsMap: uploadsMap,
                        graceMinutes: graceMinutes,
                        referenceTime: refTime,
                        gpsLocation: currentGps,
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

                        _detectZoneAtCameraCenter(zones);

                        if (_isPlacingShop) {
                          final targetVertex = ZoneVertex(
                            sequenceOrder: 0,
                            latitude: _centerLat,
                            longitude: _centerLng,
                          );
                          Zone? matched;
                          for (final z in zones) {
                            if (PolygonGeometry.isPointInsidePolygon(targetVertex, z.vertices)) {
                              matched = z;
                              break;
                            }
                          }
                          if (matched?.id != _activePlacementZone?.id || (_isPlacementInsideZone != (matched != null))) {
                            setState(() {
                              _activePlacementZone = matched;
                              _isPlacementInsideZone = matched != null;
                            });
                          }
                        }
                      },
                      onCameraIdle: () {
                        _detectZoneAtCameraCenter(zones);
                        setState(() {});
                        if (_isPlacingShop) {
                          _triggerReverseGeocode(_centerLat, _centerLng);
                        }
                      },
                      onLongPress: (latLng) {
                        if (_isPlacingShop) return;
                        setState(() {
                          _pendingShopLocation = null;
                          _pendingShopZone = null;
                        });
                        _handleMapLongPress(
                          lat: latLng.latitude,
                          lng: latLng.longitude,
                          assignedZones: zones,
                          gpsLocation: currentGps,
                        );
                      },
                      onTap: (latLng) {
                        if (_isPlacingShop) return;
                        _onMapTapped(latLng, zones, currentGps);
                      },
                      compassEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    );
                  },
                );
              },
            ),

            // 1.5. Fixed Center Pin for Place Shop Mode (Ola/Uber pickup style)
            if (_isPlacingShop && _placingCategory != null)
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 58),
                    child: _FixedCenterPin(
                      category: _placingCategory!,
                      isInsideZone: _isPlacementInsideZone,
                    ),
                  ),
                ),
              ),

            // 2. Top Bar (Placement mode header or Normal Employee Header)
            if (_isPlacingShop)
              _buildPlacementTopBar()
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
            child: PointerInterceptor(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // =========================================================================
                    // PERMANENT TOP MODE TOGGLE SWITCH (NORMAL MODE <-> DISTRIBUTION MODE)
                    // Controls mode across ALL assigned zones
                    // =========================================================================
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: isGlobalDistActive ? const Color(0xFF0F9D8A) : const Color(0xFF0F2A43),
                          width: 1.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Normal Mode Button
                          InkWell(
                            onTap: () => _setGlobalDistributionMode(false),
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: !isGlobalDistActive
                                    ? const Color(0xFF0F2A43)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.storefront_rounded,
                                    size: 16,
                                    color: !isGlobalDistActive ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Normal Mode',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !isGlobalDistActive ? FontWeight.bold : FontWeight.w600,
                                      color: !isGlobalDistActive ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          // Toggle Switch
                          Switch(
                            value: isGlobalDistActive,
                            activeThumbColor: const Color(0xFF0F9D8A),
                            activeTrackColor: const Color(0xFF0F9D8A).withValues(alpha: 0.35),
                            inactiveThumbColor: const Color(0xFF0F2A43),
                            inactiveTrackColor: const Color(0xFFCBD5E1),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => _setGlobalDistributionMode(val),
                          ),

                          const SizedBox(width: 6),

                          // Distribution Mode Button
                          InkWell(
                            onTap: () => _setGlobalDistributionMode(true),
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isGlobalDistActive
                                    ? const Color(0xFF0F9D8A)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_shipping_rounded,
                                    size: 16,
                                    color: isGlobalDistActive ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isGlobalDistActive
                                        ? 'Distribution Mode ($totalUndistributedAllZones)'
                                        : 'Distribution Mode',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isGlobalDistActive ? FontWeight.bold : FontWeight.w600,
                                      color: isGlobalDistActive ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Profile & Quick stats row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Employee info chip
                          Container(
                            constraints: const BoxConstraints(maxWidth: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.full),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    (authState.currentEmployee?.fullName ?? 'E')[0],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        authState.currentEmployee?.fullName ?? 'Field Employee',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'ID: ${authState.currentEmployee?.displayId ?? "20001"} • Active',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),

                          // Follow-ups Today Quick Pill
                          followupsTodayAsync.maybeWhen(
                            data: (list) => _QuickCountBadge(
                              label: 'Today',
                              count: list.length,
                              color: AppColors.secondary,
                              icon: Icons.calendar_today,
                              onTap: () => context.push('/followups?tab=0'),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 4),

                          // Overdue Quick Pill
                          overdueAsync.maybeWhen(
                            data: (list) => _QuickCountBadge(
                              label: 'Overdue',
                              count: list.length,
                              color: AppColors.error,
                              icon: Icons.alarm_off,
                              isAlert: list.isNotEmpty,
                              onTap: () => context.push('/followups?tab=1'),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 4),

                          // Drafts Quick Pill
                          draftsAsync.maybeWhen(
                            data: (list) => _QuickCountBadge(
                              label: 'Drafts',
                              count: list.length,
                              color: AppColors.neutral700,
                              icon: Icons.drafts_outlined,
                              onTap: () => context.push('/drafts'),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 4),

                          // Payment Done Action Button
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(8),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            tooltip: 'Payment Done (Scan QR)',
                            onPressed: () => context.push('/payment/scan'),
                          ),
                          const SizedBox(width: 4),


                          // Logout button
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(8),
                            ),
                            icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                            tooltip: 'Logout',
                            onPressed: () {
                              ref.read(employeeAuthProvider.notifier).logout();
                              context.go('/login');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Category filter pills: ONLY 3 filters (All, Shops, Saloons)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryFilterChip(
                            label: 'All',
                            icon: Icons.grid_view_rounded,
                            isSelected: (currentCatFilter == null && _selectedCategoryFilter == null),
                            onTap: () {
                              setState(() => _selectedCategoryFilter = null);
                              ref.read(shopCategoryFilterProvider.notifier).state = null;
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryFilterChip(
                            label: 'Shops',
                            icon: Icons.storefront_outlined,
                            isSelected: (currentCatFilter == 'shops' || _selectedCategoryFilter == 'shops'),
                            onTap: () {
                              setState(() => _selectedCategoryFilter = 'shops');
                              ref.read(shopCategoryFilterProvider.notifier).state = 'shops';
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryFilterChip(
                            label: 'Saloons',
                            icon: Icons.content_cut_outlined,
                            isSelected: (currentCatFilter == 'saloons' || _selectedCategoryFilter == 'saloons'),
                            onTap: () {
                              setState(() => _selectedCategoryFilter = 'saloons');
                              ref.read(shopCategoryFilterProvider.notifier).state = 'saloons';
                            },
                          ),
                        ],
                      ),
                    ),

                    // Distribution Mode Items Filter Strip (when active)
                    if (isDistributionModeActiveForCurrentZone) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final selectedDistItemId = ref.watch(selectedDistributionItemIdProvider);
                          final distItems = _getDistributionItemFiltersForZone(
                            activeZone?.id,
                            activeZoneShops,
                          );

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.95), // Slate 900
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
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
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_rounded,
                                      size: 14,
                                      color: Color(0xFFFACC15),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'DISTRIBUTION ITEM FILTER:',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFDE68A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (selectedDistItemId != null)
                                      GestureDetector(
                                        onTap: () {
                                          ref.read(selectedDistributionItemIdProvider.notifier).state = null;
                                        },
                                        child: const Text(
                                          'Show All Items',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFFFACC15),
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // All Items chip
                                      _DistributionItemChip(
                                        label: 'All Items',
                                        icon: Icons.all_inbox_rounded,
                                        isSelected: selectedDistItemId == null,
                                        badgeText: '$undistributedCount left',
                                        onTap: () {
                                          ref.read(selectedDistributionItemIdProvider.notifier).state = null;
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      ...distItems.map((item) {
                                        final isSelected = selectedDistItemId == item.id;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: _DistributionItemChip(
                                            label: item.name,
                                            imageUrl: item.imageUrl,
                                            icon: item.icon,
                                            targetType: item.targetBusinessType,
                                            isSelected: isSelected,
                                            badgeText: '${item.pendingCount} left',
                                            isCompleted: item.pendingCount == 0,
                                            onTap: () {
                                              if (isSelected) {
                                                ref.read(selectedDistributionItemIdProvider.notifier).state = null;
                                              } else {
                                                ref.read(selectedDistributionItemIdProvider.notifier).state = item.id;
                                                if (item.targetBusinessType == 'saloon') {
                                                  setState(() => _selectedCategoryFilter = 'saloons');
                                                  ref.read(shopCategoryFilterProvider.notifier).state = 'saloons';
                                                } else if (item.targetBusinessType == 'shop') {
                                                  setState(() => _selectedCategoryFilter = 'shops');
                                                  ref.read(shopCategoryFilterProvider.notifier).state = 'shops';
                                                }
                                              }
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // Distribution Mode Progress Banner (when active)
                    if (isDistributionModeActiveForCurrentZone) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_rounded,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'সামগ্রী ও বিজ্ঞাপন বিতরণ মোড সক্রিয় (${activeZone?.name ?? "Zone"})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalDistCount == 0
                                    ? 0
                                    : (distributedDoneCount / totalDistCount),
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.greenAccent,
                                ),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final activeCats = activeZone != null
                                    ? CanonicalZones.getDistributionCategories(activeZone.id)
                                    : <String>{};
                                final hasShops = activeCats.any((c) => c.toLowerCase() == 'shops' || c.toLowerCase() == 'shop');
                                final hasSaloons = activeCats.any((c) => c.toLowerCase() == 'saloons' || c.toLowerCase() == 'saloon');
                                final catLabel = (activeCats.isEmpty || activeCats.contains('All') || (hasShops && hasSaloons))
                                    ? 'সব দোকান ও সেলুন (Shops & Saloons)'
                                    : hasShops
                                        ? 'দোকানসমূহ (Shops - সেলুন বাদে)'
                                        : 'সেলুনসমূহ (Saloons)';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'বাকি আছে: $undistributedCount টি • বিতরণ সম্পন্ন: $distributedDoneCount / $totalDistCount টি',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '🏷️ টার্গেট ক্যাটাগরি: $catLabel',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Guidance Banner ("Touch & hold or tap inside zone to add shop")
          if (!_isPlacingShop && _selectedShop == null && _pendingShopLocation == null)
            Positioned(
              bottom: zonesList.isNotEmpty ? 92 : 80,
              left: AppSpacing.md,
              right: 80,
              child: PointerInterceptor(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app, size: 16, color: Colors.white),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Long-press inside your assigned zone to add a shop',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Zoom & GPS Floating Buttons (Usable while shop is selected or in placement mode)
          Positioned(
            right: AppSpacing.md,
            bottom: _isPlacingShop
                ? 210
                : (_selectedShop != null || _pendingShopLocation != null)
                    ? 220
                    : (zonesList.isNotEmpty ? 152 : 80),
            child: PointerInterceptor(
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'recenterGpsBtn',
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    tooltip: 'Center on GPS',
                    child: const Icon(Icons.my_location),
                    onPressed: () => _recenterOnGps(currentGps),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FloatingActionButton.small(
                    heroTag: 'zoomInBtn',
                    onPressed: _zoomIn,
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FloatingActionButton.small(
                    heroTag: 'zoomOutBtn',
                    onPressed: _zoomOut,
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ),

          // 4.2. Synchronized Fixed-Size Bottom-Center Floating Action Dock (Same layout as Company Map)
          if (!_isPlacingShop && _selectedShop == null && _pendingShopLocation == null && activeZone != null)
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
                                    _focusOnZone(selectedZone, zoomLevel: 13.8);
                                  },
                                  itemBuilder: (context) {
                                    return zonesList.map((z) {
                                      final isCurrent = z.id == activeZone.id;
                                      final shopCount = allShopsList.where((s) => s.zoneId == z.id).length;
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
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                            ),
                            icon: const Icon(Icons.add_business_rounded, size: 16),
                            label: const Text(
                              'Add Shop',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () {
                              _openCategoryPickerForZone(activeZone);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4.5. Proposed Shop Location Confirmation Card (from Touch & Hold or Tap)
          if (!_isPlacingShop && _pendingShopLocation != null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: PointerInterceptor(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_location_alt_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assign Shop in ${_pendingShopZone?.name ?? "Assigned Zone"}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Coordinates: ${_pendingShopLocation!.latitude.toStringAsFixed(5)}, ${_pendingShopLocation!.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.neutral600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _pendingShopLocation = null;
                                _pendingShopZone = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Cancel',
                              variant: AppButtonVariant.outlined,
                              onPressed: () {
                                setState(() {
                                  _pendingShopLocation = null;
                                  _pendingShopZone = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: AppButton(
                              label: 'Assign Shop at this Spot',
                              icon: Icons.check,
                              variant: AppButtonVariant.primary,
                              onPressed: () {
                                final loc = _pendingShopLocation!;
                                setState(() {
                                  _pendingShopLocation = null;
                                  _pendingShopZone = null;
                                });
                                zonesAsync.whenData((zones) {
                                  _handleMapLongPress(
                                    lat: loc.latitude,
                                    lng: loc.longitude,
                                    assignedZones: zones,
                                    gpsLocation: currentGps,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4.8. Place Shop Mode Bottom Confirmation Card
          if (_isPlacingShop)
            _buildPlacementBottomCard(),

          // 5. Compact Floating Action Card Anchored at Bottom Center
          if (!_isPlacingShop && _selectedShop != null && selectedShopStatus != null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: PointerInterceptor(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Builder(
                    builder: (context) {
                      final distanceMeters = currentGps != null
                          ? _calculateDistanceMeters(
                              _selectedShop!.latitude,
                              _selectedShop!.longitude,
                              currentGps.latitude,
                              currentGps.longitude,
                            )
                          : null;
                      final isCrossed = CanonicalZones.isShopCrossed(_selectedShop!.zoneId, _selectedShop!.id);
                      final isClosedToday = CanonicalShops.isShopClosedToday(_selectedShop!.id);
                      final isWeeklyClosed = _selectedShop!.isWeeklyClosedToday(refTime);
                      return ShopFloatingActionCard(
                        shop: _selectedShop!,
                        status: selectedShopStatus!,
                        isDistributionMode: ref.watch(employeeGlobalDistributionModeProvider),
                        isCrossed: isCrossed,
                        isClosedToday: isClosedToday,
                        isWeeklyClosed: isWeeklyClosed,
                        distanceMeters: distanceMeters,
                        onClose: () => setState(() => _selectedShop = null),
                        onDirections: () => _handleDirections(_selectedShop!),
                        onScanQr: () => _openHandoverChecklist(_selectedShop!),
                        onMarkDistributed: () => _openHandoverChecklist(_selectedShop!),
                        onClosedToday: () => _handleMarkClosedToday(_selectedShop!),
                        onMarkGone: () => _confirmAndMarkGone(_selectedShop!),
                        onDetails: () => ShopDetailsModal.show(
                          context,
                          shop: _selectedShop!,
                          status: selectedShopStatus!,
                          onConvertFollowupToAgreed: _selectedShop!.isFollowup
                              ? () => _convertFollowupToAgreed(_selectedShop!)
                              : null,
                        ),
                        onMakePayment: () => context.push('/payment/scan'),
                        onCall: () => _handleCallShop(_selectedShop!),
                        onThumbnailTap: () => FullSizePhotoDialog.show(
                          context,
                          shop: _selectedShop!,
                          status: selectedShopStatus!,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  /// Placement Mode Top Bar with category badge, change category button, and cancel
  Widget _buildPlacementTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: PointerInterceptor(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            topPadding + AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.neutral800),
                  tooltip: 'Cancel Placement',
                  onPressed: _cancelPlacementMode,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Place Shop Pin',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                      Text(
                        'Pan map to adjust center pin',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_placingCategory != null)
                  InkWell(
                    onTap: () async {
                      final picked = await ShopCategoryPickerModal.show(context);
                      if (picked != null && mounted) {
                        setState(() => _placingCategory = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_placingCategory!.icon, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            _placingCategory!.displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Placement Mode Bottom Card with dynamic Zone validation, coordinates, and action buttons
  Widget _buildPlacementBottomCard() {
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: AppSpacing.md,
      child: PointerInterceptor(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zone Compliance Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isPlacementInsideZone
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: _isPlacementInsideZone ? AppColors.success : AppColors.error,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isPlacementInsideZone
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _isPlacementInsideZone ? AppColors.success : AppColors.error,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPlacementInsideZone
                                ? 'Inside Zone: ${_activePlacementZone?.name ?? "Assigned"}'
                                : 'Outside Assigned Territory!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isPlacementInsideZone
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          Text(
                            _isPlacementInsideZone
                                ? 'Ready to confirm location for ${_placingCategory?.displayName ?? "Shop"}'
                                : 'Shops must be inside an assigned zone. Move map to enter zone.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isPlacementInsideZone
                                  ? AppColors.neutral700
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Coordinates and Resolved Address
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppColors.neutral700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coords: ${_centerLat.toStringAsFixed(5)}, ${_centerLng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutral800,
                          ),
                        ),
                        Text(
                          _isResolvingAddress
                              ? 'Resolving landmark / address...'
                              : (_placementResolvedAddress != null && _placementResolvedAddress!.isNotEmpty)
                                  ? _placementResolvedAddress!
                                  : 'Coordinates selected',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Buttons: Recenter & Cancel Row, followed by prominent full-width Confirm Location
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Recenter',
                      icon: Icons.restore,
                      variant: AppButtonVariant.outlined,
                      onPressed: _recenterPlacement,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      icon: Icons.close,
                      variant: AppButtonVariant.outlined,
                      onPressed: _cancelPlacementMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Confirm Location',
                icon: Icons.check_circle,
                variant: AppButtonVariant.primary,
                onPressed: _isPlacementInsideZone ? _confirmPlacementLocation : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DistributionItemFilterInfo> _getDistributionItemFiltersForZone(
    String? zoneId,
    List<Shop> allZoneShops,
  ) {
    final targetZoneId = zoneId ?? CanonicalZones.kolkataCentralId;
    final items = <DistributionItemFilterInfo>[];

    // 1. Material Runs (Paper, Pens, Cello Tape, etc.)
    final matRuns = CanonicalZones.getMaterialRuns(targetZoneId);
    for (final mat in matRuns) {
      if (mat.status != 'active') continue;
      IconData icon = Icons.inventory_2_outlined;
      final lower = mat.materialName.toLowerCase();
      if (lower.contains('paper')) {
        icon = Icons.description_outlined;
      } else if (lower.contains('pen')) {
        icon = Icons.edit_outlined;
      } else if (lower.contains('tape')) {
        icon = Icons.album_outlined;
      } else if (lower.contains('pin')) {
        icon = Icons.push_pin_outlined;
      } else if (lower.contains('stand')) {
        icon = Icons.qr_code_2_rounded;
      }

      final eligibleShops = allZoneShops.where((s) {
        if (CanonicalShops.isShopGone(s.id)) return false;
        final isSaloon = ShopCategory.fromString(s.category) == ShopCategory.saloon;
        if ((mat.targetBusinessType == 'saloon' || mat.targetBusinessType == 'saloons') && !isSaloon) {
          return false;
        }
        if ((mat.targetBusinessType == 'shop' || mat.targetBusinessType == 'shops') && isSaloon) {
          return false;
        }
        return true;
      }).toList();

      final pendingCount = eligibleShops.where((s) => !CanonicalZones.isShopItemDistributed(s.id, mat.materialId) && !CanonicalZones.isShopItemDistributed(s.id, mat.id)).length;

      items.add(DistributionItemFilterInfo(
        id: mat.materialId,
        name: mat.materialName,
        targetBusinessType: mat.targetBusinessType.toLowerCase(),
        icon: icon,
        totalCount: eligibleShops.length,
        pendingCount: pendingCount,
      ));
    }

    // 2. Company Ad Runs (With Printout proof image or ad creative)
    final adRuns = CanonicalZones.getCompanyAdRuns(targetZoneId);
    for (final ad in adRuns) {
      if (ad.status != 'active') continue;
      final displayImg = ad.printoutProofImageUrl ?? ad.adCreativeImageUrl;
      final name = ad.companyName.contains('(')
          ? ad.companyName.split('(').first.trim()
          : ad.companyName;

      final eligibleShops = allZoneShops.where((s) {
        if (CanonicalShops.isShopGone(s.id)) return false;
        final isSaloon = ShopCategory.fromString(s.category) == ShopCategory.saloon;
        if (ad.businessType.toLowerCase() == 'saloon' && !isSaloon) return false;
        if (ad.businessType.toLowerCase() == 'shop' && isSaloon) return false;
        return true;
      }).toList();

      final pendingCount = eligibleShops.where((s) => !CanonicalZones.isShopItemDistributed(s.id, ad.id) && !CanonicalZones.isShopItemDistributed(s.id, ad.companyId)).length;

      items.add(DistributionItemFilterInfo(
        id: ad.id,
        name: name,
        targetBusinessType: ad.businessType.toLowerCase(),
        imageUrl: displayImg,
        icon: Icons.photo_size_select_actual_outlined,
        totalCount: eligibleShops.length,
        pendingCount: pendingCount,
      ));
    }

    return items;
  }
}

class _FixedCenterPin extends StatelessWidget {
  final ShopCategory category;
  final bool isInsideZone;

  const _FixedCenterPin({
    required this.category,
    required this.isInsideZone,
  });

  @override
  Widget build(BuildContext context) {
    final color = isInsideZone ? AppColors.primary : AppColors.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin Category Bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.full),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                category.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Pin Needle Stem
        CustomPaint(
          size: const Size(16, 12),
          painter: _PinTrianglePainter(color: color),
        ),
        // Ground Contact Dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;
  const _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.neutral300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.neutral800,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.neutral800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isAlert;
  final VoidCallback onTap;

  const _QuickCountBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    this.isAlert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAlert ? AppColors.error : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isAlert ? Colors.white : color),
            const SizedBox(width: 3),
            Text(
              '$label: $count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAlert ? Colors.white : AppColors.neutral900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DistributionItemFilterInfo {
  final String id;
  final String name;
  final String targetBusinessType; // 'all', 'shop', 'saloon'
  final String? imageUrl;
  final IconData icon;
  final int totalCount;
  final int pendingCount;

  const DistributionItemFilterInfo({
    required this.id,
    required this.name,
    required this.targetBusinessType,
    this.imageUrl,
    required this.icon,
    required this.totalCount,
    required this.pendingCount,
  });
}

class _DistributionItemChip extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final IconData icon;
  final String? targetType;
  final bool isSelected;
  final String badgeText;
  final bool isCompleted;
  final VoidCallback onTap;

  const _DistributionItemChip({
    required this.label,
    this.imageUrl,
    required this.icon,
    this.targetType,
    required this.isSelected,
    required this.badgeText,
    this.isCompleted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color targetColor = const Color(0xFF38BDF8); // Sky blue
    String targetBadge = '';
    if (targetType == 'saloon') {
      targetColor = const Color(0xFFC084FC); // Purple
      targetBadge = '✂️ Saloon';
    } else if (targetType == 'shop') {
      targetColor = const Color(0xFF38BDF8); // Blue
      targetBadge = '🏬 Shop';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFACC15).withValues(alpha: 0.22)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFACC15)
                  : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    imageUrl!,
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      icon,
                      size: 16,
                      color: isSelected ? const Color(0xFFFACC15) : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ] else ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? const Color(0xFFFACC15) : Colors.white70,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFACC15) : Colors.white,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (targetBadge.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: targetColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: targetColor.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Text(
                    targetBadge,
                    style: TextStyle(
                      color: targetColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.2)
                      : (isSelected
                          ? const Color(0xFFFACC15).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCompleted ? '✅ Done' : badgeText,
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.greenAccent
                        : (isSelected ? const Color(0xFFFACC15) : Colors.white70),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


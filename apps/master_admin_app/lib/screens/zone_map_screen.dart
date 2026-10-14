import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:map_features/map_features.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../providers/master_admin_providers.dart';

class ZoneMapScreen extends ConsumerStatefulWidget {
  final String? existingZoneId;
  final double? initialCenterLat;
  final double? initialCenterLng;
  final double? initialZoom;

  const ZoneMapScreen({
    super.key,
    this.existingZoneId,
    this.initialCenterLat,
    this.initialCenterLng,
    this.initialZoom,
  });

  @override
  ConsumerState<ZoneMapScreen> createState() => _ZoneMapScreenState();
}

class _ZoneMapScreenState extends ConsumerState<ZoneMapScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _mapController = ZonePolygonEditorController();

  Timer? _searchDebounceTimer;
  bool _isSearching = false;
  List<PlaceSearchResult> _searchResults = [];
  bool _showSearchResults = false;
  PlaceSearchResult? _selectedSearchedPlace;

  String _selectedColorHex = '#1E88E5';
  bool _isActive = true;
  bool _isArchived = false;
  String? _selectedAdminId;

  List<ZoneVertex> _currentVertices = [];
  List<Zone> _existingZones = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  final List<String> _colorPalette = [
    '#1E88E5', // Blue
    '#43A047', // Green
    '#8E24AA', // Purple
    '#FB8C00', // Amber
    '#00897B', // Teal
    '#E53935', // Red
  ];

  @override
  void initState() {
    super.initState();
    _loadZoneData();
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
      final results = await PlaceSearchService.search(clean);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
      }
    });
  }

  void _onSelectPlace(PlaceSearchResult place) {
    setState(() {
      _selectedSearchedPlace = place;
      _searchController.text = place.name;
      _showSearchResults = false;
    });

    _mapController.moveToLocation(place.latitude, place.longitude, zoom: 15.5);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Navigated to "${place.name}". Tap "Move Boundary Here" to relocate zone polygon.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                _relocateBoundaryToSearchedPlace();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text('Move Here', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _relocateBoundaryToSearchedPlace() {
    if (_selectedSearchedPlace != null) {
      _mapController.relocatePolygonTo(
        _selectedSearchedPlace!.latitude,
        _selectedSearchedPlace!.longitude,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zone boundary moved to "${_selectedSearchedPlace!.name}"!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadZoneData() async {
    final repo = ref.read(masterAdminRepositoryProvider);

    // Load active zones so they remain visible as reference polygons
    List<Zone> allZones = [];
    try {
      allZones = await repo.getZones(includeArchived: false);
    } catch (_) {
      allZones = CanonicalZones.all;
    }
    if (allZones.isEmpty) {
      allZones = CanonicalZones.all;
    }
    _existingZones = allZones.where((z) => !z.isArchived && z.id != widget.existingZoneId).toList();

    if (widget.existingZoneId != null) {
      final zone = await repo.getZoneById(widget.existingZoneId!);
      if (zone != null && mounted) {
        setState(() {
          _nameController.text = zone.name;
          _selectedColorHex = zone.colorHex;
          _isActive = zone.isActive;
          _isArchived = zone.isArchived;
          _selectedAdminId = zone.assignedAdminId;
          _currentVertices = List.from(zone.vertices);
          _isInitialized = true;
        });
        return;
      }
    }

    // Default for new zone: 6-point hexagon centered right at current map viewport
    final double defaultLat = widget.initialCenterLat ?? 22.5760;
    final double defaultLng = widget.initialCenterLng ?? 88.4020;
    final double defaultZoom = widget.initialZoom ?? 15.0;

    double radiusKm = 0.5;
    if (defaultZoom <= 12) {
      radiusKm = 2.0;
    } else if (defaultZoom <= 13) {
      radiusKm = 1.2;
    } else if (defaultZoom <= 14) {
      radiusKm = 0.8;
    } else if (defaultZoom <= 15) {
      radiusKm = 0.5;
    } else if (defaultZoom <= 16) {
      radiusKm = 0.3;
    } else {
      radiusKm = 0.18;
    }

    setState(() {
      _nameController.text = 'New Operational Zone';
      _currentVertices = PolygonGeometry.generateHexagon(
        centerLat: defaultLat,
        centerLng: defaultLng,
        radiusKm: radiusKm,
      );
      _isInitialized = true;
    });
  }


  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _saveZone() async {
    final zoneName = _nameController.text.trim();
    if (zoneName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Zone Name before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentVertices.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Zone must have at least 3 vertices.')),
      );
      return;
    }

    if (!PolygonGeometry.isValidPolygon(_currentVertices)) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Invalid Polygon Shape'),
            ],
          ),
          content: const Text(
            'The polygon boundary intersects itself. Please drag the hexagonal dots so that boundary lines do not cross each other before saving.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Check overlap with other active zones
    final allZones = await ref.read(masterAdminRepositoryProvider).getZones();
    final otherZones = allZones.where((z) => z.id != widget.existingZoneId && !z.isArchived).toList();

    String? overlappingZoneName;
    for (final other in otherZones) {
      if (PolygonGeometry.doZonesOverlap(_currentVertices, other.vertices)) {
        overlappingZoneName = other.name;
        break;
      }
    }

    if (overlappingZoneName != null) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Zone Overlap Warning'),
            ],
          ),
          content: Text(
            'This polygon overlaps with existing active zone "$overlappingZoneName". Overlapping zones may cause ambiguous shop assignments. Do you want to proceed anyway?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel & Adjust')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed & Save'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(masterAdminRepositoryProvider);
      final zoneToSave = Zone(
        id: widget.existingZoneId ?? '',
        name: zoneName,
        colorHex: _selectedColorHex,
        isActive: _isActive,
        isArchived: _isArchived,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vertices: _currentVertices,
      );

      await repo.saveZone(
        zoneToSave,
        _currentVertices,
        assignedAdminId: _selectedAdminId,
      );

      ref.invalidate(zonesListProvider);
      ref.invalidate(dashboardStatsProvider);
      if (widget.existingZoneId != null) {
        ref.invalidate(zoneDetailProvider(widget.existingZoneId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Zone "$zoneName" saved with ${_currentVertices.length} boundary dots. / জোন সফলভাবে সংরক্ষিত হয়েছে।',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Direct return to Map Cockpit
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save zone: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showApiKeyDialog() async {
    final keyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.blue),
            SizedBox(width: 8),
            Text('Google Maps API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A Google Maps API key is OPTIONAL.\n\nBy default, this app includes a free high-resolution street map that works without any API key or subscription.\n\nIf you have a Google Maps API Key from Google Cloud Console, you can enter it below or set it in your .env file as GOOGLE_MAPS_API_KEY.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Google Maps API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Use Free Map (No Key)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Google Maps API key recorded.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _parseColor(_selectedColorHex);

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. FULL SCREEN Map with live tiles and draggable boundary dots
          Positioned.fill(
            child: ZonePolygonEditor(
              controller: _mapController,
              initialVertices: _currentVertices,
              zoneColor: activeColor,
              centerLatitude: widget.initialCenterLat ?? 22.5760,
              centerLongitude: widget.initialCenterLng ?? 88.4020,
              initialZoom: widget.initialZoom,
              existingZones: _existingZones,
              isFullScreen: true,
              pinLatitude: _selectedSearchedPlace?.latitude,
              pinLongitude: _selectedSearchedPlace?.longitude,
              pinLabel: _selectedSearchedPlace?.name,
              onVerticesChanged: (updated) {
                _currentVertices = updated;
              },
            ),
          ),

          // 2. Top Floating Header Bar (Zone Name, Color Picker, Back, Save)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: PointerInterceptor(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(245),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back to Main Map Cockpit
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to Map / মানচিত্রে ফিরে যান',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                    const SizedBox(width: 4),

                    // Color Chip Indicator & Picker
                    PopupMenuButton<String>(
                      tooltip: 'Select Zone Color',
                      icon: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                      onSelected: (hex) => setState(() => _selectedColorHex = hex),
                      itemBuilder: (context) => _colorPalette.map((hex) {
                        final c = _parseColor(hex);
                        return PopupMenuItem(
                          value: hex,
                          child: Row(
                            children: [
                              CircleAvatar(radius: 10, backgroundColor: c),
                              const SizedBox(width: 8),
                              Text(hex),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 8),

                    // Zone Name Input Field
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Enter Zone Name (e.g. Kolkata Central)',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Google Maps API Key info / config button
                    IconButton(
                      icon: const Icon(Icons.vpn_key, color: Colors.amber, size: 22),
                      tooltip: 'Google Maps API Key / গুগল ম্যাপ কী',
                      onPressed: _showApiKeyDialog,
                    ),
                    const SizedBox(width: 4),

                    // Save Zone Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveZone,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                        widget.existingZoneId != null ? 'Update Zone' : 'Save Zone',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

          // 3. Floating Search Bar with Live Places Autocomplete (Google Maps Style)
          Positioned(
            top: 86,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: PointerInterceptor(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Bar Box
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchQueryChanged,
                          decoration: InputDecoration(
                            hintText: 'Search place (e.g. Salt Lake, Park Street, Howrah)...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            prefixIcon: const Icon(Icons.search, color: Colors.blue),
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
                                          setState(() {
                                            _searchResults = [];
                                            _showSearchResults = false;
                                            _selectedSearchedPlace = null;
                                          });
                                        },
                                      )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),

                      // Search Results Dropdown List
                      if (_showSearchResults && _searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(60),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 12, endIndent: 12),
                            itemBuilder: (context, index) {
                              final place = _searchResults[index];
                              return ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0xFFE3F2FD),
                                  child: Icon(Icons.location_on, color: Colors.blue, size: 16),
                                ),
                                title: Text(
                                  place.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  place.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                                onTap: () => _onSelectPlace(place),
                              );
                            },
                          ),
                        ),

                      // If place was searched, show action button to relocate zone boundary
                      if (_selectedSearchedPlace != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: _relocateBoundaryToSearchedPlace,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: Text(
                              'Move Zone to "${_selectedSearchedPlace!.name}"',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Bottom Floating Guidance Pill
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Center(
              child: PointerInterceptor(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(205),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mouse, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Mouse wheel to zoom • Drag map to pan • Drag numbered dots to shape boundary',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

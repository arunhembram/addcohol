import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../polygon/polygon_geometry.dart';

/// Controller to programmatically navigate the interactive polygon map
class ZonePolygonEditorController {
  _ZonePolygonEditorState? _state;

  void _attach(_ZonePolygonEditorState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// Fly map center to specified coordinates, optionally adjusting zoom
  void moveToLocation(double lat, double lng, {double? zoom, bool movePolygon = false}) {
    _state?.moveToLocation(lat, lng, zoom: zoom, movePolygon: movePolygon);
  }

  /// Relocate the polygon vertices so their centroid is at [lat, lng]
  void relocatePolygonTo(double lat, double lng) {
    _state?.relocatePolygonTo(lat, lng);
  }

  /// Zoom in by a step
  void zoomIn() {
    _state?.zoomIn();
  }

  /// Zoom out by a step
  void zoomOut() {
    _state?.zoomOut();
  }
}

class ZonePolygonEditor extends StatefulWidget {
  final List<ZoneVertex> initialVertices;
  final Color zoneColor;
  final ValueChanged<List<ZoneVertex>> onVerticesChanged;
  final double centerLatitude;
  final double centerLongitude;
  final double? initialZoom;
  final List<Zone> existingZones;
  final bool isFullScreen;
  final bool initialGoogleMapsMode;
  final ZonePolygonEditorController? controller;
  final double? pinLatitude;
  final double? pinLongitude;
  final String? pinLabel;

  const ZonePolygonEditor({
    super.key,
    required this.initialVertices,
    required this.zoneColor,
    required this.onVerticesChanged,
    this.centerLatitude = 22.5726, // Kolkata default
    this.centerLongitude = 88.3639,
    this.initialZoom,
    this.existingZones = const [],
    this.isFullScreen = false,
    this.initialGoogleMapsMode = true,
    this.controller,
    this.pinLatitude,
    this.pinLongitude,
    this.pinLabel,
  });

  @override
  State<ZonePolygonEditor> createState() => _ZonePolygonEditorState();
}

class _ZonePolygonEditorState extends State<ZonePolygonEditor> {
  late List<ZoneVertex> _vertices;
  int _selectedVertexIndex = 0;

  // Map viewport state
  late double _mapCenterLat;
  late double _mapCenterLng;
  double _zoomLevel = 15.0;

  // Google Maps Controller
  GoogleMapController? _googleMapController;

  static double _calculateRadiusForZoom(double zoom) {
    if (zoom <= 12) return 2.0;
    if (zoom <= 13) return 1.2;
    if (zoom <= 14) return 0.8;
    if (zoom <= 15) return 0.5;
    if (zoom <= 16) return 0.3;
    return 0.18;
  }

  Color _parseZoneColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF1E88E5);
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  Zone? get _overlappingZone {
    if (_vertices.length < 3) return null;
    for (final ez in widget.existingZones) {
      if (ez.vertices.length >= 3 && PolygonGeometry.doZonesOverlap(_vertices, ez.vertices)) {
        return ez;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (widget.initialZoom != null) {
      _zoomLevel = widget.initialZoom!;
    }
    if (widget.initialVertices.isNotEmpty) {
      _vertices = List<ZoneVertex>.from(widget.initialVertices);
      _recenterCalculated();
    } else {
      _mapCenterLat = widget.centerLatitude;
      _mapCenterLng = widget.centerLongitude;
      _vertices = PolygonGeometry.generateHexagon(
        centerLat: _mapCenterLat,
        centerLng: _mapCenterLng,
        radiusKm: _calculateRadiusForZoom(_zoomLevel),
      );
    }
  }

  @override
  void didUpdateWidget(ZonePolygonEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _googleMapController?.dispose();
    super.dispose();
  }

  void moveToLocation(double lat, double lng, {double? zoom, bool movePolygon = false}) {
    final targetLat = lat.clamp(-85.0, 85.0);
    final targetLng = ((lng + 180.0) % 360.0 + 360.0) % 360.0 - 180.0;
    final targetZoom = zoom ?? _zoomLevel;

    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(targetLat, targetLng), targetZoom),
    );

    setState(() {
      _mapCenterLat = targetLat;
      _mapCenterLng = targetLng;
      if (zoom != null) {
        _zoomLevel = zoom.clamp(2.0, 20.0);
      }
      if (movePolygon) {
        relocatePolygonTo(targetLat, targetLng);
      }
    });
  }

  void relocatePolygonTo(double targetLat, double targetLng) {
    if (_vertices.isEmpty) {
      setState(() {
        _vertices = PolygonGeometry.generateHexagon(
          centerLat: targetLat,
          centerLng: targetLng,
          radiusKm: 0.6,
        );
      });
      _notifyChange();
      return;
    }

    double sumLat = 0;
    double sumLng = 0;
    for (final v in _vertices) {
      sumLat += v.latitude;
      sumLng += v.longitude;
    }
    final curCenterLat = sumLat / _vertices.length;
    final curCenterLng = sumLng / _vertices.length;

    final dLat = targetLat - curCenterLat;
    final dLng = targetLng - curCenterLng;

    setState(() {
      _vertices = _vertices.map((v) {
        return v.copyWith(
          latitude: double.parse((v.latitude + dLat).toStringAsFixed(6)),
          longitude: double.parse((v.longitude + dLng).toStringAsFixed(6)),
        );
      }).toList();
    });
    _notifyChange();
  }

  void zoomIn() {
    _googleMapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() {
    _googleMapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _recenterCalculated() {
    if (_vertices.isEmpty) return;
    double sumLat = 0;
    double sumLng = 0;
    for (final v in _vertices) {
      sumLat += v.latitude;
      sumLng += v.longitude;
    }
    _mapCenterLat = (sumLat / _vertices.length).clamp(-85.0, 85.0);
    _mapCenterLng = ((sumLng / _vertices.length) + 180.0) % 360.0 - 180.0;
  }

  void _notifyChange() {
    widget.onVerticesChanged(List.unmodifiable(_vertices));
  }

  void _addVertexAtSelectedEdge() {
    if (_vertices.isEmpty) return;
    final nextIndex = (_selectedVertexIndex + 1) % _vertices.length;
    final v1 = _vertices[_selectedVertexIndex];
    final v2 = _vertices[nextIndex];

    final newVertex = PolygonGeometry.calculateMidpoint(v1, v2, nextIndex);
    setState(() {
      _vertices.insert(nextIndex, newVertex);
      for (int i = 0; i < _vertices.length; i++) {
        _vertices[i] = _vertices[i].copyWith(sequenceOrder: i);
      }
      _selectedVertexIndex = nextIndex;
    });
    _notifyChange();
  }

  void _removeSelectedVertex() {
    if (_vertices.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A zone polygon must have at least 3 vertices.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _vertices.removeAt(_selectedVertexIndex);
      if (_selectedVertexIndex >= _vertices.length) {
        _selectedVertexIndex = _vertices.length - 1;
      }
      for (int i = 0; i < _vertices.length; i++) {
        _vertices[i] = _vertices[i].copyWith(sequenceOrder: i);
      }
    });
    _notifyChange();
  }

  void _recenterOnZone() {
    if (_vertices.isEmpty) return;
    _recenterCalculated();
    if (_googleMapController != null) {
      final bounds = _calculateBounds(_vertices);
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  LatLngBounds _calculateBounds(List<ZoneVertex> vertices) {
    if (vertices.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(_mapCenterLat - 0.01, _mapCenterLng - 0.01),
        northeast: LatLng(_mapCenterLat + 0.01, _mapCenterLng + 0.01),
      );
    }
    double minLat = vertices.first.latitude;
    double maxLat = vertices.first.latitude;
    double minLng = vertices.first.longitude;
    double maxLng = vertices.first.longitude;

    for (final v in vertices) {
      if (v.latitude < minLat) minLat = v.latitude;
      if (v.latitude > maxLat) maxLat = v.latitude;
      if (v.longitude < minLng) minLng = v.longitude;
      if (v.longitude > maxLng) maxLng = v.longitude;
    }

    if (minLat == maxLat) {
      minLat -= 0.005;
      maxLat += 0.005;
    }
    if (minLng == maxLng) {
      minLng -= 0.005;
      maxLng += 0.005;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        final canvasHeight = widget.isFullScreen
            ? constraints.maxHeight
            : constraints.maxHeight.clamp(200.0, 460.0);

        return ClipRRect(
          borderRadius: widget.isFullScreen ? BorderRadius.zero : AppRadii.radiusMd,
          child: Container(
            width: canvasWidth,
            height: canvasHeight,
            color: const Color(0xFFE8ECEF),
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                // 1. Google Maps Vector SDK
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_mapCenterLat, _mapCenterLng),
                      zoom: _zoomLevel,
                    ),
                    onMapCreated: (controller) {
                      _googleMapController = controller;
                    },
                    mapType: MapType.normal,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    polygons: {
                      // 1. Existing reference zones (so they never vanish and prevent overlap)
                      ...widget.existingZones
                          .where((z) => z.vertices.length >= 3)
                          .map((zone) {
                        final zColor = _parseZoneColor(zone.colorHex);
                        return Polygon(
                          polygonId: PolygonId('existing_zone_${zone.id}'),
                          points: zone.vertices
                              .map((v) => LatLng(v.latitude, v.longitude))
                              .toList(),
                          strokeColor: zColor.withValues(alpha: 0.85),
                          fillColor: zColor.withValues(alpha: 0.18),
                          strokeWidth: 2,
                          geodesic: true,
                        );
                      }),

                      // 2. Active editing/creating zone polygon
                      Polygon(
                        polygonId: const PolygonId('active_zone_polygon'),
                        points: _vertices
                            .map((v) => LatLng(v.latitude, v.longitude))
                            .toList(),
                        strokeColor: widget.zoneColor,
                        fillColor: widget.zoneColor.withAlpha(55),
                        strokeWidth: 3,
                        geodesic: true,
                      ),
                    },
                    markers: {
                      if (widget.pinLatitude != null && widget.pinLongitude != null)
                        Marker(
                          markerId: const MarkerId('searched_place_pin'),
                          position:
                              LatLng(widget.pinLatitude!, widget.pinLongitude!),
                          infoWindow: InfoWindow(
                            title: widget.pinLabel ?? 'Searched Location',
                          ),
                        ),

                      // Existing zone centroid label markers
                      ...widget.existingZones
                          .where((z) => z.vertices.isNotEmpty)
                          .map((zone) {
                        final avgLat = zone.vertices.map((v) => v.latitude).reduce((a, b) => a + b) /
                            zone.vertices.length;
                        final avgLng = zone.vertices.map((v) => v.longitude).reduce((a, b) => a + b) /
                            zone.vertices.length;
                        return Marker(
                          markerId: MarkerId('existing_badge_${zone.id}'),
                          position: LatLng(avgLat, avgLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                          infoWindow: InfoWindow(
                            title: 'Zone: ${zone.name}',
                            snippet: 'Admin: ${zone.assignedAdminName ?? "Unassigned"}',
                          ),
                        );
                      }),
                      // Active Zone Middle Drag Handle (Drag whole zone from center)
                      if (_vertices.isNotEmpty)
                        Marker(
                          markerId: const MarkerId('active_zone_center_drag_handle'),
                          position: LatLng(
                            _vertices.map((v) => v.latitude).reduce((a, b) => a + b) / _vertices.length,
                            _vertices.map((v) => v.longitude).reduce((a, b) => a + b) / _vertices.length,
                          ),
                          draggable: true,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
                          zIndexInt: 30,
                          infoWindow: const InfoWindow(
                            title: '✥ Move Whole Zone',
                            snippet: 'Drag from the middle to relocate the whole boundary',
                          ),
                          onDrag: (newPos) {
                            relocatePolygonTo(newPos.latitude, newPos.longitude);
                          },
                          onDragEnd: (finalPos) {
                            relocatePolygonTo(finalPos.latitude, finalPos.longitude);
                          },
                        ),
                      ...List.generate(_vertices.length, (index) {
                        final v = _vertices[index];
                        final isSelected = index == _selectedVertexIndex;
                        return Marker(
                          markerId: MarkerId('vertex_$index'),
                          position: LatLng(v.latitude, v.longitude),
                          draggable: true,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure,
                          ),
                          infoWindow: InfoWindow(
                            title:
                                'Point #${index + 1}${isSelected ? " ★ (Selected)" : ""}',
                            snippet: 'Drag to adjust boundary • Tap to select',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedVertexIndex = index;
                            });
                          },
                          onDrag: (newPos) {
                            setState(() {
                              _vertices[index] = _vertices[index].copyWith(
                                latitude: newPos.latitude,
                                longitude: newPos.longitude,
                              );
                            });
                            _notifyChange();
                          },
                          onDragEnd: (finalPos) {
                            setState(() {
                              _vertices[index] = _vertices[index].copyWith(
                                latitude: finalPos.latitude,
                                longitude: finalPos.longitude,
                              );
                              _selectedVertexIndex = index;
                            });
                            _notifyChange();
                          },
                        );
                      }),
                    },
                    onCameraMove: (pos) {
                      _mapCenterLat = pos.target.latitude;
                      _mapCenterLng = pos.target.longitude;
                      _zoomLevel = pos.zoom;
                    },
                  ),
                ),

                // 2. Map Zoom & Re-center Controls (Top Left)
                Positioned(
                  left: 14,
                  top: widget.isFullScreen ? 150 : 14,
                  child: PointerInterceptor(
                    child: Column(
                      children: [
                        _MapIconButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          onPressed: zoomIn,
                        ),
                        const SizedBox(height: 6),
                        _MapIconButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onPressed: zoomOut,
                        ),
                        const SizedBox(height: 6),
                        _MapIconButton(
                          icon: Icons.my_location,
                          tooltip: 'Fit zone into view',
                          onPressed: _recenterOnZone,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Hexagonal Vertex Edit Controls (+ and −) (Top Right)
                Positioned(
                  right: 14,
                  top: widget.isFullScreen ? 86 : 14,
                  child: PointerInterceptor(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_vertices.length} Boundary Dots',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neutral800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green, size: 28),
                            tooltip: 'Add vertex at edge midpoint / শীর্ষবিন্দু যোগ করুন',
                            onPressed: _addVertexAtSelectedEdge,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle,
                              color: _vertices.length > 3
                                  ? Colors.red
                                  : Colors.grey,
                              size: 28,
                            ),
                            tooltip: 'Remove selected vertex / শীর্ষবিন্দু মুছুন',
                            onPressed: _vertices.length > 3
                                ? _removeSelectedVertex
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Live Status Bar & Selected Point Coordinates (Bottom)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: PointerInterceptor(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(240),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 20,
                            color: widget.zoneColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Dragging Point #${_selectedVertexIndex + 1} of ${_vertices.length}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.blue.shade300,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Text(
                                        'Google Maps Vector',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (_selectedVertexIndex < _vertices.length)
                                  Text(
                                    'Lat: ${_vertices[_selectedVertexIndex].latitude.toStringAsFixed(6)}, Lng: ${_vertices[_selectedVertexIndex].longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: AppColors.neutral700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Real-time Overlap Warning Floating Banner
                if (_overlappingZone != null)
                  Positioned(
                    top: widget.isFullScreen ? 82 : 12,
                    left: 14,
                    right: 14,
                    child: PointerInterceptor(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(60),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Overlaps with existing zone "${_overlappingZone!.name}"! Adjust points so zones do not clash.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
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
        );
      },
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.neutral900),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}

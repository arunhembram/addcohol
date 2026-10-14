import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppMapView extends ConsumerStatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final Set<Marker>? markers;
  final void Function(LatLng)? onTap;

  const AppMapView({
    super.key,
    this.initialLatitude = 23.8103, // Dhaka center default
    this.initialLongitude = 90.4125,
    this.initialZoom = 13.0,
    this.markers,
    this.onTap,
  });

  @override
  ConsumerState<AppMapView> createState() => _AppMapViewState();
}

class _AppMapViewState extends ConsumerState<AppMapView> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.radiusMd,
      child: SizedBox(
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.initialLatitude, widget.initialLongitude),
            zoom: widget.initialZoom,
          ),
          markers: widget.markers ?? {},
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          onMapCreated: (controller) => _controller = controller,
          onTap: widget.onTap,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

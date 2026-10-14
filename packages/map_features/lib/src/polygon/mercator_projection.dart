import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Full Web Mercator projection engine implementing EPSG:3857.
///
/// Ensures 100% mathematical lockstep between raster tiles and vector
/// overlays across all integer and fractional zoom levels.
class MercatorProjection {
  MercatorProjection._();

  /// Maximum absolute latitude supported by Web Mercator (EPSG:3857).
  /// At this latitude, y coordinate reaches the top/bottom boundary of the square world.
  static const double maxLatitude = 85.05112878;

  /// Default raster tile dimension in logical pixels.
  static const double defaultTileSize = 256.0;

  /// Clamps latitude strictly to valid Web Mercator limits [-85.05112878, 85.05112878].
  static double clampLatitude(double lat) {
    return lat.clamp(-maxLatitude, maxLatitude);
  }

  /// Normalizes longitude to [-180.0, 180.0) degrees, wrapping across the International Date Line.
  static double normalizeLongitude(double lng) {
    return ((lng + 180.0) % 360.0 + 360.0) % 360.0 - 180.0;
  }

  /// Total world dimension in logical pixels at continuous [zoom].
  ///
  /// [tileSize] represents the source tile dimension (validated per source, e.g. 256 or 512).
  static double worldDimension(double zoom, {double tileSize = defaultTileSize}) {
    assert(tileSize > 0, 'Tile size must be positive');
    return tileSize * math.pow(2.0, zoom);
  }

  /// Projects geographic coordinates (lat, lng) to world pixel coordinates at continuous [zoom].
  ///
  /// Mathematical formula:
  ///   pixelX = T * 2^zoom * ((longitude + 180) / 360)
  ///   pixelY = T * 2^zoom * (0.5 - asinh(tan(latitudeRadians)) / (2pi))
  static Offset project({
    required double latitude,
    required double longitude,
    required double zoom,
    double tileSize = defaultTileSize,
  }) {
    final ws = worldDimension(zoom, tileSize: tileSize);
    final normLng = normalizeLongitude(longitude);
    final pixelX = ws * ((normLng + 180.0) / 360.0);

    final clampedLat = clampLatitude(latitude);
    final latRad = clampedLat * math.pi / 180.0;
    // asinh(tan(latRad)) == ln(tan(pi/4 + latRad/2))
    // We use the log-tan formulation which is numerically stable and avoids tan^2 overflow.
    final asinhTan = math.log(math.tan(math.pi / 4.0 + (latRad / 2.0)));
    final pixelY = ws * (0.5 - (asinhTan / (2.0 * math.pi)));

    return Offset(pixelX, pixelY);
  }

  /// Unprojects world pixel coordinates back to geographic coordinates (lat, lng) at continuous [zoom].
  static ({double latitude, double longitude}) unproject({
    required Offset worldPixel,
    required double zoom,
    double tileSize = defaultTileSize,
  }) {
    final ws = worldDimension(zoom, tileSize: tileSize);

    final xNorm = worldPixel.dx / ws;
    final longitude = normalizeLongitude((xNorm * 360.0) - 180.0);

    final yNorm = (worldPixel.dy / ws).clamp(0.00000001, 0.99999999);
    final n = math.pi * (1.0 - 2.0 * yNorm);
    // sinh(n) = (exp(n) - exp(-n)) / 2
    final clampedN = n.clamp(-15.0, 15.0);
    final sinhN = (math.exp(clampedN) - math.exp(-clampedN)) / 2.0;
    final latRad = math.atan(sinhN);
    final latitude = clampLatitude(latRad * 180.0 / math.pi);

    return (latitude: latitude, longitude: longitude);
  }

  /// Shared screen-coordinate projection formula for tiles, polygons, and draggable dots.
  ///
  /// Mathematical formula:
  ///   screenPoint = project(latLng, currentZoom) - project(currentCenter, currentZoom) + viewportCenter
  static Offset latLngToScreenPoint({
    required double latitude,
    required double longitude,
    required double centerLatitude,
    required double centerLongitude,
    required double zoom,
    required Size viewport,
    double tileSize = defaultTileSize,
  }) {
    final ptWorld = project(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
      tileSize: tileSize,
    );
    final centerWorld = project(
      latitude: centerLatitude,
      longitude: centerLongitude,
      zoom: zoom,
      tileSize: tileSize,
    );
    final viewportCenter = Offset(viewport.width / 2.0, viewport.height / 2.0);
    return ptWorld - centerWorld + viewportCenter;
  }

  /// Shared screen-coordinate unprojection formula converting screen pixels back to lat/lng.
  ///
  /// Mathematical formula:
  ///   worldPoint = screenPoint - viewportCenter + project(currentCenter, currentZoom)
  ///   latLng = unproject(worldPoint, currentZoom)
  static ({double latitude, double longitude}) screenPointToLatLng({
    required Offset screenPoint,
    required double centerLatitude,
    required double centerLongitude,
    required double zoom,
    required Size viewport,
    double tileSize = defaultTileSize,
  }) {
    final centerWorld = project(
      latitude: centerLatitude,
      longitude: centerLongitude,
      zoom: zoom,
      tileSize: tileSize,
    );
    final viewportCenter = Offset(viewport.width / 2.0, viewport.height / 2.0);
    final ptWorld = screenPoint - viewportCenter + centerWorld;
    return unproject(worldPixel: ptWorld, zoom: zoom, tileSize: tileSize);
  }

  /// Calculates a new map center such that the geographic coordinate under [cursorScreenPos]
  /// remains stationary on screen after zoom changes from [oldZoom] to [newZoom].
  ///
  /// Mathematical derivation:
  ///   cursorOffset = cursorScreenPos - viewportCenter
  ///   anchorLatLng = unproject(oldCenterPixel + cursorOffset, oldZoom)
  ///   newCenterPixel = project(anchorLatLng, newZoom) - cursorOffset
  ///   newCenterLatLng = unproject(newCenterPixel, newZoom)
  static ({double centerLatitude, double centerLongitude}) calculateCursorAnchoredCenter({
    required Offset cursorScreenPos,
    required Size viewport,
    required double oldCenterLatitude,
    required double oldCenterLongitude,
    required double oldZoom,
    required double newZoom,
    double tileSize = defaultTileSize,
  }) {
    final viewportCenter = Offset(viewport.width / 2.0, viewport.height / 2.0);
    final cursorOffset = cursorScreenPos - viewportCenter;

    final oldCenterPixel = project(
      latitude: oldCenterLatitude,
      longitude: oldCenterLongitude,
      zoom: oldZoom,
      tileSize: tileSize,
    );
    final anchorWorldPixel = oldCenterPixel + cursorOffset;
    final anchorLatLng = unproject(
      worldPixel: anchorWorldPixel,
      zoom: oldZoom,
      tileSize: tileSize,
    );

    final newAnchorPixel = project(
      latitude: anchorLatLng.latitude,
      longitude: anchorLatLng.longitude,
      zoom: newZoom,
      tileSize: tileSize,
    );
    final newCenterPixel = newAnchorPixel - cursorOffset;
    final newCenter = unproject(
      worldPixel: newCenterPixel,
      zoom: newZoom,
      tileSize: tileSize,
    );

    return (
      centerLatitude: newCenter.latitude,
      centerLongitude: newCenter.longitude,
    );
  }

  /// Computes visible tile grid metadata for continuous fractional zoom.
  ///
  /// At continuous [zoom], base tile layer integer zoom is:
  ///   zBase = zoom.floor().clamp(minZoom, maxZoom)
  /// Scale factor between integer tile and continuous viewport is:
  ///   scale = 2^(zoom - zBase)
  /// Effective on-screen tile dimension is:
  ///   effectiveTileSize = tileSize * scale
  static TileGridBounds calculateTileGrid({
    required double centerLatitude,
    required double centerLongitude,
    required double zoom,
    required Size viewport,
    double tileSize = defaultTileSize,
    int minZoom = 1,
    int maxZoom = 20,
  }) {
    final int zBase = zoom.floor().clamp(minZoom, maxZoom);
    final double scale = math.pow(2.0, zoom - zBase).toDouble();
    final double effectiveTileSize = tileSize * scale;

    final centerWorld = project(
      latitude: centerLatitude,
      longitude: centerLongitude,
      zoom: zoom,
      tileSize: tileSize,
    );

    final startX = centerWorld.dx - (viewport.width / 2.0);
    final startY = centerWorld.dy - (viewport.height / 2.0);

    final int numTiles = math.pow(2.0, zBase).toInt();

    final startTileX = (startX / effectiveTileSize).floor();
    final endTileX = ((startX + viewport.width) / effectiveTileSize).ceil();
    final startTileY = (startY / effectiveTileSize).floor();
    final endTileY = ((startY + viewport.height) / effectiveTileSize).ceil();

    return TileGridBounds(
      zBase: zBase,
      scale: scale,
      effectiveTileSize: effectiveTileSize,
      startX: startX,
      startY: startY,
      startTileX: startTileX,
      endTileX: endTileX,
      startTileY: startTileY,
      endTileY: endTileY,
      numTilesAtZoom: numTiles,
    );
  }
}

/// Metadata describing the visible tile grid for rendering.
class TileGridBounds {
  final int zBase;
  final double scale;
  final double effectiveTileSize;
  final double startX;
  final double startY;
  final int startTileX;
  final int endTileX;
  final int startTileY;
  final int endTileY;
  final int numTilesAtZoom;

  const TileGridBounds({
    required this.zBase,
    required this.scale,
    required this.effectiveTileSize,
    required this.startX,
    required this.startY,
    required this.startTileX,
    required this.endTileX,
    required this.startTileY,
    required this.endTileY,
    required this.numTilesAtZoom,
  });

  /// Normalizes tile X coordinate across the International Date Line.
  int wrapTileX(int tx) {
    return ((tx % numTilesAtZoom) + numTilesAtZoom) % numTilesAtZoom;
  }

  /// Returns true if tile Y is within valid North-South Web Mercator bounds.
  bool isTileYValid(int ty) {
    return ty >= 0 && ty < numTilesAtZoom;
  }

  /// Calculates the screen offset (left, top) for tile (tx, ty).
  Offset tileScreenOffset(int tx, int ty) {
    return Offset(
      (tx * effectiveTileSize) - startX,
      (ty * effectiveTileSize) - startY,
    );
  }
}

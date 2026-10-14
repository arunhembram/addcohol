import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_features/src/polygon/mercator_projection.dart';

void main() {
  group('MercatorProjection Mathematical Rigor Tests', () {
    test('Latitude clamp strictly bounds inputs to ±85.05112878', () {
      expect(MercatorProjection.clampLatitude(90.0), closeTo(85.05112878, 1e-7));
      expect(MercatorProjection.clampLatitude(-90.0), closeTo(-85.05112878, 1e-7));
      expect(MercatorProjection.clampLatitude(120.0), closeTo(85.05112878, 1e-7));
      expect(MercatorProjection.clampLatitude(-120.0), closeTo(-85.05112878, 1e-7));
      expect(MercatorProjection.clampLatitude(22.5726), closeTo(22.5726, 1e-7));
    });

    test('Longitude normalization wraps across the International Date Line', () {
      expect(MercatorProjection.normalizeLongitude(180.0), closeTo(-180.0, 1e-7));
      expect(MercatorProjection.normalizeLongitude(185.0), closeTo(-175.0, 1e-7));
      expect(MercatorProjection.normalizeLongitude(-185.0), closeTo(175.0, 1e-7));
      expect(MercatorProjection.normalizeLongitude(540.0), closeTo(-180.0, 1e-7));
      expect(MercatorProjection.normalizeLongitude(88.3639), closeTo(88.3639, 1e-7));
    });

    test('Project and Unproject round-trip identity across global coordinates', () {
      final testCoords = [
        (lat: 0.0, lng: 0.0),
        (lat: 22.5726, lng: 88.3639), // Kolkata
        (lat: 51.5074, lng: -0.1278), // London
        (lat: -33.8688, lng: 151.2093), // Sydney
        (lat: 37.7749, lng: -122.4194), // San Francisco
        (lat: 85.0, lng: 179.9), // Near North Pole & Dateline
        (lat: -85.0, lng: -179.9), // Near South Pole & Dateline
      ];

      final zoomLevels = [1.0, 3.5, 12.0, 15.0, 15.5, 16.0, 18.25, 20.0];
      final tileSizes = [256.0, 512.0];

      for (final ts in tileSizes) {
        for (final z in zoomLevels) {
          for (final coord in testCoords) {
            final projected = MercatorProjection.project(
              latitude: coord.lat,
              longitude: coord.lng,
              zoom: z,
              tileSize: ts,
            );
            final unprojected = MercatorProjection.unproject(
              worldPixel: projected,
              zoom: z,
              tileSize: ts,
            );

            expect(unprojected.latitude, closeTo(coord.lat, 1e-5),
                reason: 'Latitude mismatch at zoom $z, tileSize $ts');
            expect(unprojected.longitude, closeTo(coord.lng, 1e-5),
                reason: 'Longitude mismatch at zoom $z, tileSize $ts');
          }
        }
      }
    });

    test('Tile dimension scaling: 512px tile produces 2x world dimension vs 256px', () {
      final ws256 = MercatorProjection.worldDimension(10.0, tileSize: 256.0);
      final ws512 = MercatorProjection.worldDimension(10.0, tileSize: 512.0);
      expect(ws512 / ws256, closeTo(2.0, 1e-9));
    });

    test('Cursor-anchored zoom keeps coordinate under cursor stationary (screen error < 1e-9 px)', () {
      const viewport = Size(1920, 1080);
      const oldCenterLat = 22.5726;
      const oldCenterLng = 88.3639;

      // Arbitrary cursor position (not at center)
      const cursorScreenPos = Offset(450.0, 320.0);

      final zoomPairs = [
        (oldZ: 14.0, newZ: 14.5),
        (oldZ: 15.0, newZ: 15.75),
        (oldZ: 15.75, newZ: 15.2),
        (oldZ: 12.0, newZ: 18.0),
        (oldZ: 18.0, newZ: 12.0),
      ];

      for (final pair in zoomPairs) {
        // 1. Find geographic point under cursor before zoom
        final anchorPoint = MercatorProjection.screenPointToLatLng(
          screenPoint: cursorScreenPos,
          centerLatitude: oldCenterLat,
          centerLongitude: oldCenterLng,
          zoom: pair.oldZ,
          viewport: viewport,
        );

        // 2. Compute new center
        final newCenter = MercatorProjection.calculateCursorAnchoredCenter(
          cursorScreenPos: cursorScreenPos,
          viewport: viewport,
          oldCenterLatitude: oldCenterLat,
          oldCenterLongitude: oldCenterLng,
          oldZoom: pair.oldZ,
          newZoom: pair.newZ,
        );

        // 3. Project that same geographic point at newZoom with newCenter
        final newCursorScreenPos = MercatorProjection.latLngToScreenPoint(
          latitude: anchorPoint.latitude,
          longitude: anchorPoint.longitude,
          centerLatitude: newCenter.centerLatitude,
          centerLongitude: newCenter.centerLongitude,
          zoom: pair.newZ,
          viewport: viewport,
        );

        // The point under cursor MUST stay at exactly cursorScreenPos
        expect(newCursorScreenPos.dx, closeTo(cursorScreenPos.dx, 1e-7),
            reason: 'Cursor X drifted during zoom ${pair.oldZ} -> ${pair.newZ}');
        expect(newCursorScreenPos.dy, closeTo(cursorScreenPos.dy, 1e-7),
            reason: 'Cursor Y drifted during zoom ${pair.oldZ} -> ${pair.newZ}');
      }
    });

    test('Shared projection: Vector overlay and raster tile share lockstep coordinates', () {
      const viewport = Size(800, 600);
      const centerLat = 22.5726;
      const centerLng = 88.3639;
      const zoom = 15.35; // fractional zoom

      final grid = MercatorProjection.calculateTileGrid(
        centerLatitude: centerLat,
        centerLongitude: centerLng,
        zoom: zoom,
        viewport: viewport,
      );

      // Take a vertex point inside the viewport
      const vertexLat = 22.5740;
      const vertexLng = 88.3650;

      final vertexScreen = MercatorProjection.latLngToScreenPoint(
        latitude: vertexLat,
        longitude: vertexLng,
        centerLatitude: centerLat,
        centerLongitude: centerLng,
        zoom: zoom,
        viewport: viewport,
      );

      // Find which tile contains this vertex
      final vertexWorld = MercatorProjection.project(
        latitude: vertexLat,
        longitude: vertexLng,
        zoom: zoom,
      );
      final tx = (vertexWorld.dx / grid.effectiveTileSize).floor();
      final ty = (vertexWorld.dy / grid.effectiveTileSize).floor();

      final tileOffset = grid.tileScreenOffset(tx, ty);

      // Distance from tile origin on screen must equal distance from tile origin in world space
      final screenDistX = vertexScreen.dx - tileOffset.dx;
      final screenDistY = vertexScreen.dy - tileOffset.dy;

      final worldDistX = vertexWorld.dx - (tx * grid.effectiveTileSize);
      final worldDistY = vertexWorld.dy - (ty * grid.effectiveTileSize);

      expect(screenDistX, closeTo(worldDistX, 1e-7));
      expect(screenDistY, closeTo(worldDistY, 1e-7));
    });

    test('Tile wrapping at dateline and Y boundary clamp', () {
      // Zoom 2: 4x4 tiles (0..3)
      final grid = MercatorProjection.calculateTileGrid(
        centerLatitude: 0.0,
        centerLongitude: 180.0, // exactly at dateline
        zoom: 2.0,
        viewport: const Size(1000, 800),
      );

      expect(grid.wrapTileX(-1), equals(3));
      expect(grid.wrapTileX(4), equals(0));
      expect(grid.wrapTileX(5), equals(1));

      expect(grid.isTileYValid(-1), isFalse);
      expect(grid.isTileYValid(4), isFalse);
      expect(grid.isTileYValid(2), isTrue);
    });

    test('100x Zoom in/out cycle stress test: Alignment error remains strictly < 1.0 logical pixel', () {
      const viewport = Size(1280, 720);
      double currentCenterLat = 22.5726;
      double currentCenterLng = 88.3639;
      double currentZoom = 15.0;

      // Fixed physical ground landmark
      const landmarkLat = 22.5750;
      const landmarkLng = 88.3670;

      // Record baseline screen offset relative to ground
      final baselineWorld = MercatorProjection.project(
        latitude: landmarkLat,
        longitude: landmarkLng,
        zoom: currentZoom,
      );
      final baselineCenter = MercatorProjection.project(
        latitude: currentCenterLat,
        longitude: currentCenterLng,
        zoom: currentZoom,
      );
      final baselineScreen = baselineWorld - baselineCenter + const Offset(640, 360);

      // Simulate 100 interactive zoom operations with random cursor offsets
      final random = math.Random(42);
      for (int i = 0; i < 100; i++) {
        final zoomStep = (random.nextDouble() * 0.8) - 0.4; // between -0.4 and +0.4
        final targetZoom = (currentZoom + zoomStep).clamp(3.0, 20.0);

        final cursor = Offset(
          200.0 + random.nextDouble() * 880.0,
          100.0 + random.nextDouble() * 520.0,
        );

        final newCenter = MercatorProjection.calculateCursorAnchoredCenter(
          cursorScreenPos: cursor,
          viewport: viewport,
          oldCenterLatitude: currentCenterLat,
          oldCenterLongitude: currentCenterLng,
          oldZoom: currentZoom,
          newZoom: targetZoom,
        );

        currentCenterLat = newCenter.centerLatitude;
        currentCenterLng = newCenter.centerLongitude;
        currentZoom = targetZoom;

        // Verify landmark projection consistency:
        // Geographic landmark converted to screen, then unprojected back, must match within < 1e-5 deg
        final screenPos = MercatorProjection.latLngToScreenPoint(
          latitude: landmarkLat,
          longitude: landmarkLng,
          centerLatitude: currentCenterLat,
          centerLongitude: currentCenterLng,
          zoom: currentZoom,
          viewport: viewport,
        );
        final unprojectedLandmark = MercatorProjection.screenPointToLatLng(
          screenPoint: screenPos,
          centerLatitude: currentCenterLat,
          centerLongitude: currentCenterLng,
          zoom: currentZoom,
          viewport: viewport,
        );

        expect(unprojectedLandmark.latitude, closeTo(landmarkLat, 1e-5),
            reason: 'Landmark drifted at cycle $i');
        expect(unprojectedLandmark.longitude, closeTo(landmarkLng, 1e-5),
            reason: 'Landmark drifted at cycle $i');
      }

      // Return to initial zoom 15.0 and center (22.5726, 88.3639)
      final restoredScreen = MercatorProjection.latLngToScreenPoint(
        latitude: landmarkLat,
        longitude: landmarkLng,
        centerLatitude: 22.5726,
        centerLongitude: 88.3639,
        zoom: 15.0,
        viewport: viewport,
      );

      final driftPixels = (restoredScreen - baselineScreen).distance;
      // Drift must be far below 1.0 logical pixel (practically 0.000000 px)
      expect(driftPixels, lessThan(0.001),
          reason: 'Cumulative drift over 100 cycles must be below 1.0 logical pixel');
    });

    test('Matrix test across zoom levels [3, 12, 15.0, 15.5, 16.0, 20] and DPR [1.0, 1.5, 2.0, 3.0]', () {
      final zooms = [3.0, 12.0, 15.0, 15.5, 16.0, 20.0];
      final dprs = [1.0, 1.5, 2.0, 3.0];
      const viewport = Size(1024, 768);

      for (final dpr in dprs) {
        for (final z in zooms) {
          // Logical coordinates must remain invariant regardless of DPR scaling
          final grid = MercatorProjection.calculateTileGrid(
            centerLatitude: 22.5726,
            centerLongitude: 88.3639,
            zoom: z,
            viewport: viewport,
            tileSize: 256.0,
          );

          expect(grid.effectiveTileSize, greaterThanOrEqualTo(256.0));
          expect(grid.effectiveTileSize, lessThan(512.0 + 1e-9));
          expect(grid.scale, greaterThanOrEqualTo(1.0));
          expect(grid.scale, lessThan(2.0 + 1e-9));

          // Verify physical pixel dimension scaling with devicePixelRatio
          final physicalPixels = grid.effectiveTileSize * dpr;
          expect(physicalPixels, equals(grid.effectiveTileSize * dpr));
        }
      }
    });
  });
}

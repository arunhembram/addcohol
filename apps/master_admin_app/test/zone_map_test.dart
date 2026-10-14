import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_features/map_features.dart';

void main() {
  group('Zone Map Polygon Geometry & Editor Tests', () {
    test('generateHexagon generates exactly 6 vertices around center', () {
      final hex = PolygonGeometry.generateHexagon(
        centerLat: 22.5726,
        centerLng: 88.3639,
        radiusKm: 1.0,
      );

      expect(hex.length, equals(6));
      for (int i = 0; i < 6; i++) {
        expect(hex[i].sequenceOrder, equals(i));
        expect(hex[i].latitude, isNot(0.0));
        expect(hex[i].longitude, isNot(0.0));
      }
    });

    test('calculateMidpoint creates precise intermediate vertex', () {
      const v1 = ZoneVertex(sequenceOrder: 0, latitude: 10.0, longitude: 20.0);
      const v2 = ZoneVertex(sequenceOrder: 1, latitude: 12.0, longitude: 24.0);

      final mid = PolygonGeometry.calculateMidpoint(v1, v2, 1);
      expect(mid.latitude, equals(11.0));
      expect(mid.longitude, equals(22.0));
      expect(mid.sequenceOrder, equals(1));
    });

    test('isValidPolygon verifies valid polygon and detects self-intersection', () {
      // 1. Regular square: valid
      const square = [
        ZoneVertex(sequenceOrder: 0, latitude: 0.0, longitude: 0.0),
        ZoneVertex(sequenceOrder: 1, latitude: 0.0, longitude: 1.0),
        ZoneVertex(sequenceOrder: 2, latitude: 1.0, longitude: 1.0),
        ZoneVertex(sequenceOrder: 3, latitude: 1.0, longitude: 0.0),
      ];
      expect(PolygonGeometry.isValidPolygon(square), isTrue);

      // 2. Hourglass / bow-tie (self-intersecting): invalid
      const bowTie = [
        ZoneVertex(sequenceOrder: 0, latitude: 0.0, longitude: 0.0),
        ZoneVertex(sequenceOrder: 1, latitude: 1.0, longitude: 1.0),
        ZoneVertex(sequenceOrder: 2, latitude: 0.0, longitude: 1.0),
        ZoneVertex(sequenceOrder: 3, latitude: 1.0, longitude: 0.0),
      ];
      expect(PolygonGeometry.isValidPolygon(bowTie), isFalse);

      // 3. Less than 3 vertices: invalid
      const incomplete = [
        ZoneVertex(sequenceOrder: 0, latitude: 0.0, longitude: 0.0),
        ZoneVertex(sequenceOrder: 1, latitude: 1.0, longitude: 1.0),
      ];
      expect(PolygonGeometry.isValidPolygon(incomplete), isFalse);
    });

    test('doZonesOverlap detects overlapping and non-overlapping zones', () {
      final polyA = PolygonGeometry.generateHexagon(
        centerLat: 22.5726,
        centerLng: 88.3639,
        radiusKm: 1.0,
      );

      // polyB is almost identical center: should overlap
      final polyB = PolygonGeometry.generateHexagon(
        centerLat: 22.5730,
        centerLng: 88.3640,
        radiusKm: 1.0,
      );
      expect(PolygonGeometry.doZonesOverlap(polyA, polyB), isTrue);

      // polyFar is far away (e.g. 50km away): should not overlap
      final polyFar = PolygonGeometry.generateHexagon(
        centerLat: 23.5726,
        centerLng: 89.3639,
        radiusKm: 0.5,
      );
      expect(PolygonGeometry.doZonesOverlap(polyA, polyFar), isFalse);
    });

    testWidgets('ZonePolygonEditor renders draggable handles and responds to + and − buttons', (
      WidgetTester tester,
    ) async {
      List<ZoneVertex> currentVertices = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZonePolygonEditor(
              initialVertices: const [], // Will auto-generate default 6-point hexagon
              zoneColor: Colors.blue,
              onVerticesChanged: (updated) {
                currentVertices = updated;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Starts as default 6-point hexagon
      expect(find.text('6 Boundary Dots'), findsOneWidget);

      // Find the + button and tap it to add vertex at midpoint
      final addButton = find.byTooltip('Add vertex at edge midpoint / শীর্ষবিন্দু যোগ করুন');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Vertices should now be 7
      expect(find.text('7 Boundary Dots'), findsOneWidget);
      expect(currentVertices.length, equals(7));

      // Find the − button and tap it to delete the vertex
      final removeButton = find.byTooltip('Remove selected vertex / শীর্ষবিন্দু মুছুন');
      expect(removeButton, findsOneWidget);
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Vertices should return to 6
      expect(currentVertices.length, equals(6));

      // Tap remove 3 more times down to minimum 3
      await tester.tap(removeButton);
      await tester.pumpAndSettle();
      await tester.tap(removeButton);
      await tester.pumpAndSettle();
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      expect(currentVertices.length, equals(3));

      // Attempt to tap remove again at 3 vertices: should not reduce below 3
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      expect(currentVertices.length, equals(3));
    });
  });
}

import 'dart:math' as math;
import 'package:domain_models/domain_models.dart';

class PolygonGeometry {
  PolygonGeometry._();

  /// Generates a default regular 6-point hexagon around a center coordinate.
  /// [radiusKm] specifies the distance from center to vertices in kilometers.
  static List<ZoneVertex> generateHexagon({
    required double centerLat,
    required double centerLng,
    double radiusKm = 0.5,
  }) {
    // 1 deg latitude is approximately 111.32 km
    final latDelta = radiusKm / 111.32;
    // 1 deg longitude varies with latitude
    final lngDelta =
        radiusKm / (111.32 * math.cos(centerLat * math.pi / 180).abs().clamp(0.01, 1.0));

    final List<ZoneVertex> vertices = [];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60.0) * (math.pi / 180.0);
      final lat = centerLat + (latDelta * math.sin(angle));
      final lng = centerLng + (lngDelta * math.cos(angle));

      vertices.add(
        ZoneVertex(
          sequenceOrder: i,
          latitude: double.parse(lat.toStringAsFixed(6)),
          longitude: double.parse(lng.toStringAsFixed(6)),
        ),
      );
    }
    return vertices;
  }

  /// Calculates the geographic midpoint between two vertices.
  static ZoneVertex calculateMidpoint(ZoneVertex v1, ZoneVertex v2, int newIndex) {
    return ZoneVertex(
      sequenceOrder: newIndex,
      latitude: double.parse(((v1.latitude + v2.latitude) / 2.0).toStringAsFixed(6)),
      longitude: double.parse(((v1.longitude + v2.longitude) / 2.0).toStringAsFixed(6)),
    );
  }

  /// Checks if polygon has at least 3 vertices and no self-intersecting non-adjacent edges.
  static bool isValidPolygon(List<ZoneVertex> vertices) {
    if (vertices.length < 3) return false;

    final n = vertices.length;
    for (int i = 0; i < n; i++) {
      final a1 = vertices[i];
      final a2 = vertices[(i + 1) % n];

      for (int j = i + 1; j < n; j++) {
        // Skip adjacent edges
        if ((i == 0 && j == n - 1) || (j == i + 1) || (i == j)) continue;

        final b1 = vertices[j];
        final b2 = vertices[(j + 1) % n];

        if (_doLinesIntersect(a1, a2, b1, b2)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Checks if two zones overlap (via point-in-polygon or edge intersection).
  static bool doZonesOverlap(List<ZoneVertex> polyA, List<ZoneVertex> polyB) {
    if (polyA.length < 3 || polyB.length < 3) return false;

    // 1. Check if any edges intersect
    for (int i = 0; i < polyA.length; i++) {
      final a1 = polyA[i];
      final a2 = polyA[(i + 1) % polyA.length];
      for (int j = 0; j < polyB.length; j++) {
        final b1 = polyB[j];
        final b2 = polyB[(j + 1) % polyB.length];
        if (_doLinesIntersect(a1, a2, b1, b2)) return true;
      }
    }

    // 2. Check if a point of A is inside B
    if (isPointInsidePolygon(polyA.first, polyB)) return true;

    // 3. Check if a point of B is inside A
    if (isPointInsidePolygon(polyB.first, polyA)) return true;

    return false;
  }

  /// Ray-casting point-in-polygon algorithm.
  static bool isPointInsidePolygon(ZoneVertex point, List<ZoneVertex> polygon) {
    int intersectCount = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % n];

      final cond = (v1.longitude > point.longitude) != (v2.longitude > point.longitude);
      if (cond) {
        final slope = (v2.latitude - v1.latitude) / (v2.longitude - v1.longitude);
        final x = v1.latitude + slope * (point.longitude - v1.longitude);
        if (point.latitude < x) {
          intersectCount++;
        }
      }
    }
    return (intersectCount % 2) == 1;
  }

  static bool _doLinesIntersect(ZoneVertex p1, ZoneVertex q1, ZoneVertex p2, ZoneVertex q2) {
    int o1 = _orientation(p1, q1, p2);
    int o2 = _orientation(p1, q1, q2);
    int o3 = _orientation(p2, q2, p1);
    int o4 = _orientation(p2, q2, q1);

    if (o1 != o2 && o3 != o4) return true;

    if (o1 == 0 && _onSegment(p1, p2, q1)) return true;
    if (o2 == 0 && _onSegment(p1, q2, q1)) return true;
    if (o3 == 0 && _onSegment(p2, p1, q2)) return true;
    if (o4 == 0 && _onSegment(p2, q1, q2)) return true;

    return false;
  }

  static int _orientation(ZoneVertex p, ZoneVertex q, ZoneVertex r) {
    final val =
        (q.longitude - p.longitude) * (r.latitude - q.latitude) -
        (q.latitude - p.latitude) * (r.longitude - q.longitude);
    if (val.abs() < 1e-9) return 0;
    return (val > 0) ? 1 : 2;
  }

  static bool _onSegment(ZoneVertex p, ZoneVertex q, ZoneVertex r) {
    return q.latitude <= math.max(p.latitude, r.latitude) &&
        q.latitude >= math.min(p.latitude, r.latitude) &&
        q.longitude <= math.max(p.longitude, r.longitude) &&
        q.longitude >= math.min(p.longitude, r.longitude);
  }
}

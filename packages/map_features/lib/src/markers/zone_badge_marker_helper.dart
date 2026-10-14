import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cross-platform helper to render high-DPI floating pill badges for Zones
/// on the map (e.g. "[ 🏷️ Salt Lake Zone • 🎯 Book ]")
class ZoneBadgeMarkerHelper {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Get or create a custom BitmapDescriptor badge displaying the zone name and "Book" CTA.
  static Future<BitmapDescriptor> getZoneBadgeBitmap({
    required String zoneId,
    required String zoneName,
    Color color = const Color(0xFF1E88E5),
    bool isDraggable = false,
    bool hasAdmin = true,
    bool hasEmployee = true,
  }) async {
    final key = '${zoneId}_${zoneName}_${color.toARGB32()}_${isDraggable ? "drag" : "static"}_${hasAdmin ? "admin" : "no_admin"}_${hasEmployee ? "emp" : "no_emp"}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Measure text width
      final cleanName = zoneName.length > 24
          ? '${zoneName.substring(0, 22)}...'
          : zoneName;
      final labelText = isDraggable
          ? '✥ $cleanName'
          : (!hasAdmin
              ? '⚪ $cleanName • No Admin'
              : (!hasEmployee
                  ? '⚪ $cleanName • No Employee'
                  : cleanName));

      final isUnassigned = !hasAdmin || !hasEmployee;

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: !isUnassigned ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      const paddingH = 12.0;
      const paddingV = 5.0;
      final badgeWidth = textPainter.width + (paddingH * 2);
      final badgeHeight = textPainter.height + (paddingV * 2);
      final totalHeight = (badgeHeight + 4.0).ceilToDouble();

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, badgeWidth, badgeHeight),
        const Radius.circular(14),
      );

      // 1. Drop Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(rect.shift(const Offset(0, 2)), shadowPaint);

      // 2. Background Pill (Dark Slate / Solid with accent tint)
      final bgPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, bgPaint);

      // 3. Colored Accent Border (Striped dashed border if unassigned, solid if assigned)
      if (isUnassigned) {
        final path = Path()..addRRect(rect);
        final baseBorder = Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawRRect(rect, baseBorder);

        final stripePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (final metric in path.computeMetrics()) {
          double distance = 0.0;
          bool draw = true;
          while (distance < metric.length) {
            const segLen = 7.0;
            if (draw) {
              final extract = metric.extractPath(distance, (distance + segLen).clamp(0.0, metric.length));
              canvas.drawPath(extract, stripePaint);
            }
            distance += segLen;
            draw = !draw;
          }
        }
      } else {
        final borderPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(rect, borderPaint);
      }

      // 4. Subtle inner indicator dot or 4-way move cross
      if (isDraggable) {
        final crossPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        final cx = paddingH - 3;
        final cy = badgeHeight / 2;
        canvas.drawLine(Offset(cx - 4, cy), Offset(cx + 4, cy), crossPaint);
        canvas.drawLine(Offset(cx, cy - 4), Offset(cx, cy + 4), crossPaint);
      } else {
        final dotPaint = Paint()
          ..color = !isUnassigned ? color : const Color(0xFFCBD5E1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(paddingH - 4, badgeHeight / 2), 3, dotPaint);
      }

      // 5. Paint text
      textPainter.paint(
        canvas,
        Offset(paddingH + 3, paddingV),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(badgeWidth.toInt(), totalHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _cache[key] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('Failed to render zone badge for $zoneName: $e');
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }
}

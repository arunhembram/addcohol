import 'dart:async';
import 'dart:ui' as ui;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'category_marker_helper.dart';

/// Helper to render high-DPI custom photo markers on the map for shops with verified photos.
/// Features:
/// 1. Square shape photo container (icon size: ~52x52 px) with rounded corners & white border.
/// 2. Line 1 under photo: Shop Category (e.g. "Chicken Shop", "Fast Food", "Grocery").
/// 3. Line 2 under photo: Last updated date (e.g. "10 Oct 2026").
/// 4. Ground pointer needle directing to the exact street location.
class PhotoMarkerHelper {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Get or generate a custom square photo marker BitmapDescriptor
  static Future<BitmapDescriptor> getPhotoMarkerBitmap({
    required String shopId,
    required String categoryName,
    required String formattedDate,
    Color? categoryColor,
    ui.Image? image,
  }) async {
    final cleanCategory = categoryName.trim();
    final cleanDate = formattedDate.trim();
    final cacheKey = '${shopId}_${cleanCategory}_$cleanDate';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const double width = 114.0;
      const double height = 118.0;
      const double squareSize = 52.0;
      const double squareLeft = (width - squareSize) / 2.0; // 31.0
      const double squareTop = 4.0;

      final catColor = categoryColor ??
          CategoryMarkerHelper.getCategoryColor(
            ShopCategory.fromString(cleanCategory),
          );

      // 1. Drop shadow for the square photo container
      final photoRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(squareLeft, squareTop, squareSize, squareSize),
        const Radius.circular(8.0),
      );
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawRRect(photoRRect.shift(const Offset(0, 3)), shadowPaint);

      // 2. Square background & photo rendering
      if (image != null) {
        // Clip to rounded square and draw provided image
        canvas.save();
        canvas.clipRRect(photoRRect);
        final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        final dstRect = Rect.fromLTWH(squareLeft, squareTop, squareSize, squareSize);
        canvas.drawImageRect(image, srcRect, dstRect, Paint());
        canvas.restore();
      } else {
        // High-contrast stylized photo frame tile
        final bgPaint = Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(photoRRect, bgPaint);

        // Photo preview inner gradient
        final photoInnerRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(squareLeft + 2, squareTop + 2, squareSize - 4, squareSize - 4),
          const Radius.circular(6.0),
        );
        final photoPaint = Paint()
          ..shader = ui.Gradient.linear(
            const Offset(squareLeft, squareTop),
            const Offset(squareLeft + squareSize, squareTop + squareSize),
            [
              catColor.withValues(alpha: 0.85),
              const Color(0xFF1E293B),
            ],
          );
        canvas.drawRRect(photoInnerRect, photoPaint);

        // Camera icon in center of square
        final cameraPainter = TextPainter(textDirection: TextDirection.ltr);
        cameraPainter.text = TextSpan(
          text: String.fromCharCode(0xe412), // camera_alt_rounded
          style: const TextStyle(
            fontSize: 22,
            fontFamily: 'MaterialIcons',
            color: Colors.white,
          ),
        );
        cameraPainter.layout();
        cameraPainter.paint(
          canvas,
          Offset(
            squareLeft + ((squareSize - cameraPainter.width) / 2.0),
            squareTop + ((squareSize - cameraPainter.height) / 2.0) - 2,
          ),
        );
      }

      // 3. Crisp white outer border around square photo
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(photoRRect, borderPaint);

      // Green "Live Proof Verified" indicator dot in top-right of photo
      final liveDotPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(squareLeft + squareSize - 4, squareTop + 4), 4.5, liveDotPaint);
      final liveDotBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(const Offset(squareLeft + squareSize - 4, squareTop + 4), 4.5, liveDotBorder);

      // 4. Line 1 under photo: Shop Category Pill (e.g. "Chicken Shop", "Fast Food Stall", "Grocery")
      final categoryText = cleanCategory.length > 15
          ? '${cleanCategory.substring(0, 13)}..'
          : cleanCategory;

      final catPainter = TextPainter(
        text: TextSpan(
          text: categoryText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      catPainter.layout();

      const double catPaddingH = 7.0;
      const double catPaddingV = 2.5;
      final catPillWidth = (catPainter.width + (catPaddingH * 2)).clamp(40.0, width);
      final catPillHeight = catPainter.height + (catPaddingV * 2);
      final catPillLeft = (width - catPillWidth) / 2.0;
      const double catPillTop = squareTop + squareSize + 4.0;

      final catPillRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(catPillLeft, catPillTop, catPillWidth, catPillHeight),
        const Radius.circular(5.0),
      );

      // Shadow for category pill
      canvas.drawRRect(
        catPillRRect.shift(const Offset(0, 1.5)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );

      // Category Pill Background
      canvas.drawRRect(
        catPillRRect,
        Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.fill,
      );
      // Category Accent Border
      canvas.drawRRect(
        catPillRRect,
        Paint()
          ..color = catColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      catPainter.paint(
        canvas,
        Offset(
          catPillLeft + ((catPillWidth - catPainter.width) / 2.0),
          catPillTop + catPaddingV,
        ),
      );

      // 5. Line 2 under category: Last updated date (e.g. "10 Oct 2026")
      final datePainter = TextPainter(
        text: TextSpan(
          text: cleanDate,
          style: const TextStyle(
            color: Color(0xFF0F2A43),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      datePainter.layout();

      const double datePaddingH = 5.0;
      const double datePaddingV = 1.5;
      final datePillWidth = (datePainter.width + (datePaddingH * 2)).clamp(36.0, width);
      final datePillHeight = datePainter.height + (datePaddingV * 2);
      final datePillLeft = (width - datePillWidth) / 2.0;
      final double datePillTop = catPillTop + catPillHeight + 2.5;

      final datePillRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(datePillLeft, datePillTop, datePillWidth, datePillHeight),
        const Radius.circular(4.0),
      );

      // Date Pill Background
      canvas.drawRRect(
        datePillRRect,
        Paint()
          ..color = const Color(0xFFF1F5F9)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        datePillRRect,
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      datePainter.paint(
        canvas,
        Offset(
          datePillLeft + ((datePillWidth - datePainter.width) / 2.0),
          datePillTop + datePaddingV,
        ),
      );

      // 6. Ground pointer needle at bottom
      final pointerTop = datePillTop + datePillHeight;
      final pointerPath = Path()
        ..moveTo((width / 2.0) - 5, pointerTop)
        ..lineTo((width / 2.0) + 5, pointerTop)
        ..lineTo(width / 2.0, pointerTop + 7)
        ..close();

      canvas.drawPath(
        pointerPath,
        Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.fill,
      );

      // Ground anchor point dot
      canvas.drawCircle(
        Offset(width / 2.0, pointerTop + 7),
        2.5,
        Paint()
          ..color = catColor
          ..style = PaintingStyle.fill,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _cache[cacheKey] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('Failed to render custom photo marker for $shopId: $e');
    }

    return BitmapDescriptor.defaultMarker;
  }
}

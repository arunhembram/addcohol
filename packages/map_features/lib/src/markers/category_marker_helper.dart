import 'dart:async';
import 'dart:ui' as ui;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cross-platform helper to render high-DPI category-based map markers
/// with custom category icons (e.g. Grocery, Saloon, Pharmacy, Fast Food, etc.)
/// across all apps: Master Admin, Admin, Employee, and Company.
class CategoryMarkerHelper {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Get standard distinct theme color for each shop category
  static Color getCategoryColor(ShopCategory category) {
    switch (category) {
      case ShopCategory.chicken:
        return const Color(0xFFE65100);
      case ShopCategory.fastFood:
        return const Color(0xFFD84315);
      case ShopCategory.grocery:
        return const Color(0xFF2E7D32);
      case ShopCategory.saloon:
        return const Color(0xFF7B1FA2);
      case ShopCategory.pharmacy:
        return const Color(0xFF00897B);
      case ShopCategory.teaStall:
        return const Color(0xFF6D4C41);
      case ShopCategory.bakery:
        return const Color(0xFFC2185B);
      case ShopCategory.clothing:
        return const Color(0xFF283593);
      case ShopCategory.other:
        return const Color(0xFF455A64);
    }
  }

  /// Pre-render and cache all 9 category markers into memory so they can be
  /// used synchronously during marker build passes.
  static Future<Map<String, BitmapDescriptor>> preloadCategoryMarkerBitmaps({
    Color? color,
  }) async {
    final Map<String, BitmapDescriptor> results = {};
    for (final cat in ShopCategory.values) {
      final marker = await getCategoryMarkerBitmap(
        category: cat,
        color: color ?? getCategoryColor(cat),
      );
      results[cat.displayName] = marker;
      results[cat.displayName.toLowerCase()] = marker;
      results[cat.name] = marker;
      results[cat.name.toLowerCase()] = marker;
    }
    return results;
  }

  /// Get or create a custom BitmapDescriptor marker displaying the category icon.
  static Future<BitmapDescriptor> getCategoryMarkerBitmap({
    required ShopCategory category,
    Color? color,
  }) async {
    final effectiveColor = color ?? getCategoryColor(category);
    final key = '${category.name}_${effectiveColor.toARGB32()}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 100.0;
      const radius = 34.0;
      const center = Offset(size / 2, radius + 6);

      // 1. Drop shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(center.dx, center.dy + 4), radius, shadowPaint);

      // 2. Needle triangle pointing down to ground contact
      final path = Path()
        ..moveTo(center.dx - 14, center.dy + 18)
        ..lineTo(center.dx + 14, center.dy + 18)
        ..lineTo(center.dx, size - 8)
        ..close();

      final pinPaint = Paint()
        ..color = effectiveColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, pinPaint);

      // 3. Pin Circle Outer
      canvas.drawCircle(center, radius, pinPaint);

      // 4. White Inner Circle
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - 5, innerPaint);

      // 5. Category Icon in center
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(category.icon.codePoint),
        style: TextStyle(
          fontSize: 32,
          fontFamily: category.icon.fontFamily,
          package: category.icon.fontPackage,
          color: effectiveColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - (textPainter.width / 2),
          center.dy - (textPainter.height / 2),
        ),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _cache[key] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('Failed to render custom category marker for ${category.displayName}: $e');
    }

    return BitmapDescriptor.defaultMarker;
  }

  static const Color followUpBlueColor = Color(0xFF1E88E5);
  static const Color followUpOrangeColor = Color(0xFFFB8C00);
  static const Color redCrossColor = Color(0xFFD32F2F);

  static const Color closedShopOrangeColor = Color(0xFFE65100);

  /// Pre-render and cache all marker variants:
  /// - Standard category theme colors (or optional agreedColor)
  /// - Blue follow-up markers
  /// - Orange follow-up markers
  /// - Bold red cross marker
  /// - Closed shop padlock marker
  static Future<void> preloadAllMarkers({Color? agreedColor}) async {
    await preloadCategoryMarkerBitmaps(color: agreedColor);
    await preloadCategoryMarkerBitmaps(color: followUpBlueColor);
    await preloadCategoryMarkerBitmaps(color: followUpOrangeColor);
    await getRedCrossMarkerBitmap();
    await getClosedShopMarkerBitmap();
  }

  /// Get or create a custom BitmapDescriptor marker displaying a Bold Red Cross (❌)
  static Future<BitmapDescriptor> getRedCrossMarkerBitmap() async {
    const key = 'red_cross_marker';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 100.0;
      const radius = 34.0;
      const center = Offset(size / 2, radius + 6);

      // 1. Drop shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(center.dx, center.dy + 4), radius, shadowPaint);

      // 2. Needle triangle pointing down
      final path = Path()
        ..moveTo(center.dx - 14, center.dy + 18)
        ..lineTo(center.dx + 14, center.dy + 18)
        ..lineTo(center.dx, size - 8)
        ..close();

      final pinPaint = Paint()
        ..color = redCrossColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, pinPaint);

      // 3. Pin Circle Outer
      canvas.drawCircle(center, radius, pinPaint);

      // 4. White Inner Circle
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - 5, innerPaint);

      // 5. Bold Red Cross (X) in center
      final crossPaint = Paint()
        ..color = redCrossColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round;

      const crossRadius = 14.0;
      canvas.drawLine(
        Offset(center.dx - crossRadius, center.dy - crossRadius),
        Offset(center.dx + crossRadius, center.dy + crossRadius),
        crossPaint,
      );
      canvas.drawLine(
        Offset(center.dx + crossRadius, center.dy - crossRadius),
        Offset(center.dx - crossRadius, center.dy + crossRadius),
        crossPaint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _cache[key] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('Failed to render red cross marker: $e');
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  /// Synchronously retrieve red cross marker descriptor
  static BitmapDescriptor getRedCrossMarkerSync() {
    return _cache['red_cross_marker'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  /// Get or create a custom BitmapDescriptor marker displaying a Padlock / Closed Shutter Icon (🔒)
  /// Indicates that employee has visited the shop today, but found it closed.
  static Future<BitmapDescriptor> getClosedShopMarkerBitmap() async {
    const key = 'closed_shop_marker';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 100.0;
      const radius = 34.0;
      const center = Offset(size / 2, radius + 6);

      // 1. Drop shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(center.dx, center.dy + 4), radius, shadowPaint);

      // 2. Needle triangle pointing down
      final path = Path()
        ..moveTo(center.dx - 14, center.dy + 18)
        ..lineTo(center.dx + 14, center.dy + 18)
        ..lineTo(center.dx, size - 8)
        ..close();

      final pinPaint = Paint()
        ..color = closedShopOrangeColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, pinPaint);

      // 3. Pin Circle Outer
      canvas.drawCircle(center, radius, pinPaint);

      // 4. White Inner Circle
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - 5, innerPaint);

      // 5. Crisp vector padlock in center
      // Padlock Body (Rounded Rect)
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 5), width: 28, height: 21),
        const Radius.circular(5),
      );
      final bodyPaint = Paint()
        ..color = closedShopOrangeColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bodyRect, bodyPaint);

      // Padlock Shackle (Arch)
      final shacklePaint = Paint()
        ..color = closedShopOrangeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round;
      final shacklePath = Path()
        ..moveTo(center.dx - 7.5, center.dy - 4)
        ..lineTo(center.dx - 7.5, center.dy - 10)
        ..arcToPoint(
          Offset(center.dx + 7.5, center.dy - 10),
          radius: const Radius.circular(7.5),
        )
        ..lineTo(center.dx + 7.5, center.dy - 4);
      canvas.drawPath(shacklePath, shacklePaint);

      // Keyhole in padlock body
      final keyholePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(center.dx, center.dy + 2.5), 2.8, keyholePaint);
      final keyholeSlot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx, center.dy + 2.5),
        Offset(center.dx, center.dy + 9.5),
        keyholeSlot,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
        _cache[key] = descriptor;
        return descriptor;
      }
    } catch (e) {
      debugPrint('Failed to render closed shop marker: $e');
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  /// Synchronously retrieve closed shop marker descriptor
  static BitmapDescriptor getClosedShopMarkerSync() {
    return _cache['closed_shop_marker'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  /// Synchronously retrieve cached marker descriptor for a category.
  /// Falls back to defaultMarker if not yet rendered.
  static BitmapDescriptor getMarkerSync(
    ShopCategory category, {
    Color? color,
  }) {
    final effectiveColor = color ?? getCategoryColor(category);
    final key = '${category.name}_${effectiveColor.toARGB32()}';
    return _cache[key] ?? BitmapDescriptor.defaultMarker;
  }

  /// Synchronously retrieve follow-up marker descriptor:
  /// - [isOrange] = true -> Orange icon
  /// - [isOrange] = false -> Blue icon
  static BitmapDescriptor getFollowUpMarkerSync(
    ShopCategory category, {
    required bool isOrange,
  }) {
    final color = isOrange ? followUpOrangeColor : followUpBlueColor;
    final key = '${category.name}_${color.toARGB32()}';
    return _cache[key] ??
        BitmapDescriptor.defaultMarkerWithHue(
          isOrange ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure,
        );
  }

  /// Get the appropriate category marker icon for a Shop based on its status:
  /// - Agreed & Active: theme category color (or optional [agreedColor])
  /// - Follow-up missed (overdue): blinks continuously (alternates blue/orange via [blinkToggle])
  /// - Follow-up today: orange
  /// - Follow-up scheduled/future: blue
  static BitmapDescriptor getShopMarkerSync({
    required Shop shop,
    required bool blinkToggle,
    Color? agreedColor,
  }) {
    final category = ShopCategory.fromString(shop.category);

    if (shop.isFollowup) {
      if (shop.isFollowupMissed) {
        // Overdue / missed day: blink blue and orange continuously
        return getFollowUpMarkerSync(category, isOrange: blinkToggle);
      } else if (shop.isFollowupToday) {
        // Today to follow up: turn orange
        return getFollowUpMarkerSync(category, isOrange: true);
      } else {
        // General / future follow-up: blue
        return getFollowUpMarkerSync(category, isOrange: false);
      }
    }

    // Agreed & active shop
    return getMarkerSync(category, color: agreedColor);
  }

  /// Synchronously retrieve cached marker descriptor by category string name.
  static BitmapDescriptor getMarkerFromCategoryStringSync(
    String? categoryStr, {
    Color? color,
  }) {
    final category = ShopCategory.fromString(categoryStr);
    return getMarkerSync(category, color: color);
  }
}

import 'package:flutter/material.dart';

/// Representation of a 7-day booking slot strictly starting on Monday and ending on Sunday.
class WeekSlotData {
  final String id;
  final DateTime startDate; // Always Monday
  final DateTime endDate; // Always Sunday
  final bool isBooked; // Already reserved/booked by another advertiser
  final String? monthName; // e.g. "OCTOBER", "NOVEMBER"
  final int? year;

  const WeekSlotData({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.isBooked = false,
    this.monthName,
    this.year,
  });

  String get startDayString => '${startDate.day}';
  String get endDayString => '${endDate.day}';

  bool get crossesMonth => endDate.month != startDate.month;
  String get endMonthAbbr => _monthAbbr(endDate.month);

  static String _monthAbbr(int month) {
    const abbrs = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return abbrs[month - 1];
  }
}

/// Slot button styled to match the Advertisement Space page theme:
/// - Light SaaS background (#F8FAFC)
/// - Deep Navy (#0F2A43) for numbers and main labels
/// - Brand Teal (#0F9D8A) for the selected active pocket
/// - Soft slate borders (#CBD5E1) for available slots
/// - Slate-100 (#F1F5F9) for booked slots with dashed borders
class WeekSlotButton extends StatelessWidget {
  final WeekSlotData slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const WeekSlotButton({
    super.key,
    required this.slot,
    required this.isSelected,
    this.onTap,
  });

  static const Color colorNavy = Color(0xFF0F2A43);
  static const Color colorTeal = Color(0xFF0F9D8A);
  static const Color colorMuted = Color(0xFF64748B);
  static const Color colorDisabled = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final isBooked = slot.isBooked;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.5),
      height: 58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBooked ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: CustomPaint(
            painter: LightStadiumSlotPainter(
              isBooked: isBooked,
              isSelected: isSelected,
            ),
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  // 1. LEFT SECTION: Start Date (Always Monday e.g. "5", "12", "19", "26")
                  Expanded(
                    flex: 30,
                    child: Center(
                      child: Text(
                        slot.startDayString,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isBooked ? colorDisabled : colorNavy,
                        ),
                      ),
                    ),
                  ),

                  // 2. CENTER SECTION: "Book" / "7 DAYS" OR "Selected ×" / "7 DAYS" OR "BOOKED"
                  Expanded(
                    flex: 40,
                    child: Center(
                      child: isBooked
                          ? const Text(
                              'BOOKED',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: colorDisabled,
                              ),
                            )
                          : isSelected
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'Selected ×',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      '7 DAYS',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'Book',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: colorNavy,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      '7 DAYS',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                        color: colorMuted,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),

                  // 3. RIGHT SECTION: End Date (Always Sunday e.g. "11", "1 NOV", "6 DEC")
                  Expanded(
                    flex: 30,
                    child: Center(
                      child: slot.crossesMonth
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  slot.endDayString,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isBooked ? colorDisabled : colorNavy,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  slot.endMonthAbbr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isBooked ? colorDisabled : colorMuted,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              slot.endDayString,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isBooked ? colorDisabled : colorNavy,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for light SaaS theme matching the Advertisement Space page:
/// - Outer capsule:
///   - Available: white fill, solid border #CBD5E1 (1.3px), soft shadow
///   - Selected: white fill with solid Teal #0F9D8A center pocket, solid #0F9D8A border (2px)
///   - Booked: slate-100 fill (#F1F5F9), dashed border #CBD5E1
/// - Curved dividers:
///   - Left arc: inward curve "("
///   - Right arc: inward curve ")"
class LightStadiumSlotPainter extends CustomPainter {
  final bool isBooked;
  final bool isSelected;

  LightStadiumSlotPainter({
    required this.isBooked,
    required this.isSelected,
  });

  static const Color colorTeal = Color(0xFF0F9D8A);
  static const Color colorBorder = Color(0xFFCBD5E1);

  @override
  void paint(Canvas canvas, Size size) {
    final borderWidth = isSelected ? 2.0 : 1.3;
    final r = size.height / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(borderWidth / 2, borderWidth / 2,
          size.width - borderWidth, size.height - borderWidth),
      Radius.circular(r),
    );

    // 1. Draw base capsule background
    final bgPaint = Paint()
      ..color = isBooked ? const Color(0xFFF1F5F9) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // 2. Define divider curve geometry
    final leftX = size.width * 0.31;
    final rightX = size.width * 0.69;

    final leftArcPath = Path()
      ..moveTo(leftX + 4, borderWidth / 2)
      ..quadraticBezierTo(
        leftX - 13,
        size.height / 2,
        leftX + 4,
        size.height - borderWidth / 2,
      );

    final rightArcPath = Path()
      ..moveTo(rightX - 4, borderWidth / 2)
      ..quadraticBezierTo(
        rightX + 13,
        size.height / 2,
        rightX - 4,
        size.height - borderWidth / 2,
      );

    // 3. If SELECTED: Fill the center pocket with solid brand Teal #0F9D8A
    if (isSelected) {
      final centerPocketPath = Path()
        ..moveTo(leftX + 4, borderWidth / 2)
        ..quadraticBezierTo(
          leftX - 13,
          size.height / 2,
          leftX + 4,
          size.height - borderWidth / 2,
        )
        ..lineTo(rightX - 4, size.height - borderWidth / 2)
        ..quadraticBezierTo(
          rightX + 13,
          size.height / 2,
          rightX - 4,
          borderWidth / 2,
        )
        ..close();

      final tealCenterPaint = Paint()
        ..color = colorTeal
        ..style = PaintingStyle.fill;
      canvas.drawPath(centerPocketPath, tealCenterPaint);
    }

    // 4. Draw outer border
    final Color borderColor = isSelected
        ? colorTeal
        : colorBorder;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    if (isBooked) {
      _drawDashedRRect(canvas, rrect, borderPaint);
    } else {
      canvas.drawRRect(rrect, borderPaint);
    }

    // 5. Draw curved dividers
    final Color dividerColor = isSelected
        ? colorTeal
        : colorBorder;

    final curvePaint = Paint()
      ..color = dividerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    if (isBooked) {
      _drawDashedPath(canvas, leftArcPath, curvePaint);
      _drawDashedPath(canvas, rightArcPath, curvePaint);
    } else {
      canvas.drawPath(leftArcPath, curvePaint);
      canvas.drawPath(rightArcPath, curvePaint);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 6.0;
      const dashGap = 4.5;
      while (distance < metric.length) {
        final length = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant LightStadiumSlotPainter oldDelegate) {
    return oldDelegate.isBooked != isBooked ||
        oldDelegate.isSelected != isSelected;
  }
}

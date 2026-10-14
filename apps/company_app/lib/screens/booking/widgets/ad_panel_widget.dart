import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Renders a single advertisement panel for either the Left or Right wing of the stand.
/// Designed to attach completely adjacent to the body of the scanner, touching the scanner without any gaps.
class AdPanelWidget extends StatelessWidget {
  final String adSize; // 'A5' or 'A6'
  final String sideName; // 'Left' or 'Right'
  final String brandName;

  const AdPanelWidget({
    super.key,
    required this.adSize,
    required this.sideName,
    this.brandName = 'YOUR BRAND',
  });

  /// Dimensions for A5 and A6:
  /// A5 height (184) matches the height of the scanner stand's rectangular body.
  /// A6 height (130) is visibly smaller and shorter than A5.
  static double getPanelWidth(String size) => size.toUpperCase() == 'A5' ? 128.0 : 92.0;
  static double getPanelHeight(String size) => size.toUpperCase() == 'A5' ? 184.0 : 130.0;

  bool get isLeft => sideName.toLowerCase() == 'left';

  @override
  Widget build(BuildContext context) {
    final isA5 = adSize.toUpperCase() == 'A5';
    final width = getPanelWidth(adSize);
    final height = getPanelHeight(adSize);

    // Rounded on outer corners, flat on the edge touching the scanner stand
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isLeft ? 8.0 : 0.0),
      bottomLeft: Radius.circular(isLeft ? 8.0 : 0.0),
      topRight: Radius.circular(!isLeft ? 8.0 : 0.0),
      bottomRight: Radius.circular(!isLeft ? 8.0 : 0.0),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: const Color(0xFF0F2A43),
          dashWidth: 4.5,
          dashSpace: 3.5,
          strokeWidth: 1.5,
          borderRadius: borderRadius,
        ),
        child: Container(
          // Zero margin on the seam side touching the scanner stand
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isLeft ? 2 : 0,
            right: isLeft ? 0 : 2,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isA5 ? 6 : 4,
            vertical: isA5 ? 6 : 4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F2A43).withAlpha(12),
                blurRadius: 6,
                offset: Offset(isLeft ? -2 : 2, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Header: Size Pill Badge & Side indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2A43),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      adSize.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isA5 ? 8.5 : 7.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      isA5 ? '$sideName Side' : sideName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: AppColors.neutral600,
                        fontSize: isA5 ? 7.5 : 6.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Brand Title & "Brand Artwork Preview"
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Column(
                  children: [
                    Text(
                      'YOUR AD HERE',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isA5 ? 10.5 : 8.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F2A43),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Brand Artwork Preview',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isA5 ? 6.5 : 5.8,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F9D8A),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Placeholder Image / Graphic Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: isA5 ? 20 : 14,
                        color: const Color(0xFF0F2A43),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Artwork Area',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isA5 ? 7.5 : 6.2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Dimension / Specs text
              Text(
                isA5 ? '148 × 210 mm' : '105 × 148 mm',
                style: TextStyle(
                  fontSize: isA5 ? 7.0 : 6.0,
                  color: AppColors.neutral500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for dashed borders around preview panels
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final BorderRadius borderRadius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 4.5,
    this.dashSpace = 3.5,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, size.height),
      topLeft: borderRadius.topLeft,
      bottomLeft: borderRadius.bottomLeft,
      topRight: borderRadius.topRight,
      bottomRight: borderRadius.bottomRight,
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double nextDistance = distance + dashWidth;
        final extractPath = metric.extractPath(
          distance,
          nextDistance > metric.length ? metric.length : nextDistance,
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}

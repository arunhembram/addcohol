import 'package:flutter/material.dart';

/// Authentic Indian merchant tabletop QR payment scanner stand (PhonePe / UPI style).
/// Visually features:
/// - Distinctive arched / semi-circular dome crest at the top with brand insignia
/// - White acrylic vertical display body with straight vertical side edges for seamless wing attachment
/// - "Payment Scanner" & BHIM UPI brand header
/// - Large, high-contrast QR code with central purple insignia
/// - "1 QR for all Payment Apps" purple ribbon and payment method icons
/// - L-shaped acrylic base foot resting on the countertop
class PaymentScannerStandWidget extends StatelessWidget {
  /// Width of the stand's main body
  static const double standWidth = 114.0;
  /// Height of the rectangular display area (where ad panels flush-attach)
  static const double bodyHeight = 184.0;
  /// Total visual height including the top arched dome crown and L-base
  static const double standHeight = 230.0;

  const PaymentScannerStandWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: standWidth,
      height: standHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. TOP ARCHED DOME CROWN (Iconic PhonePe/Merchant crest)
          Container(
            width: 68,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF5F259F), // PhonePe signature royal purple
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'पे',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. MAIN WHITE ACRYLIC RECTANGULAR BODY (Straight vertical edges for 0-gap ad wings)
          Container(
            width: standWidth,
            height: bodyHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // (a) Brand Title: "Payment Scanner" & Bengali subtitle
                Padding(
                  padding: const EdgeInsets.only(top: 5.0, left: 4.0, right: 4.0),
                  child: Column(
                    children: [
                      const Text(
                        'Payment Scanner',
                        style: TextStyle(
                          color: Color(0xFF5F259F),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      // BHIM | UPI Logo Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'BHIM ',
                            style: TextStyle(
                              fontSize: 7.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Container(
                            width: 0,
                            height: 0,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            child: const Icon(Icons.play_arrow, size: 7, color: Colors.orange),
                          ),
                          const Text(
                            ' | UPI ',
                            style: TextStyle(
                              fontSize: 7.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Container(
                            width: 0,
                            height: 0,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            child: const Icon(Icons.play_arrow, size: 7, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // (b) LARGE REALISTIC QR CODE WITH CENTRAL PURPLE 'पे' BADGE
                Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        painter: _AuthenticQrMatrixPainter(),
                        child: const SizedBox.expand(),
                      ),
                      // Central Purple Mini Badge
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5F259F),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'पे',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // (c) Bottom Purple Banner: "1 QR for all Payment Apps"
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      color: const Color(0xFF5F259F),
                      child: const Text(
                        '1 QR for all Payment Apps',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 6.8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // (d) Payment apps mini icons (GPay, Paytm, BHIM, Bank)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMiniBadge('G', const Color(0xFF1A73E8)),
                          _buildMiniBadge('P', const Color(0xFF00B9F1)),
                          _buildMiniBadge('₹', const Color(0xFF2E7D32)),
                          _buildMiniBadge('A', const Color(0xFFED1C24)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. L-SHAPED ACRYLIC BASE FOOT (Perspective base resting flat on countertop)
          Container(
            width: standWidth + 10,
            height: 10,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE5E7EB),
                  Color(0xFFD1D5DB),
                  Color(0xFF9CA3AF),
                ],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String symbol, Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          symbol,
          style: const TextStyle(
            fontSize: 6.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering a realistic dense QR matrix with finder patterns
class _AuthenticQrMatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final cell = size.width / 19.0;

    void drawFinder(double x, double y) {
      // 7x7 outer square
      canvas.drawRect(Rect.fromLTWH(x, y, cell * 7, cell * 7), paint);
      // 5x5 white inner
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(x + cell, y + cell, cell * 5, cell * 5),
        whitePaint,
      );
      // 3x3 solid center
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 2, y + cell * 2, cell * 3, cell * 3),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(size.width - cell * 7, 0);
    drawFinder(0, size.height - cell * 7);

    // Realistic QR data dots across the matrix
    final dataCells = [
      [8, 1], [9, 1], [8, 3], [10, 3], [8, 5], [11, 5],
      [1, 8], [3, 8], [5, 8], [7, 8], [11, 8], [13, 8], [15, 8], [17, 8],
      [8, 9], [10, 9], [12, 9], [14, 9], [16, 9],
      [1, 10], [3, 10], [5, 10], [13, 10], [15, 10], [17, 10],
      [8, 11], [10, 11], [14, 11], [16, 11],
      [8, 13], [10, 13], [12, 13], [14, 13], [16, 13], [18, 13],
      [8, 15], [10, 15], [12, 15], [14, 15], [16, 15], [18, 15],
      [8, 17], [10, 17], [12, 17], [14, 17], [16, 17],
    ];

    for (final pt in dataCells) {
      canvas.drawRect(
        Rect.fromLTWH(pt[0] * cell, pt[1] * cell, cell, cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

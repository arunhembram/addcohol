import 'package:flutter/material.dart';
import '../../../utils/currency_formatter.dart';

/// "Design & Print" price line widget positioned directly under the scanner stand preview,
/// centered, above the control bar.
///
/// Refined, compact aesthetic:
/// - Compact pill that hugs its content naturally (no bloated empty width)
/// - Tight, elegant spacing (2.5px) between Line 1 and Line 2
/// - Clean, sophisticated SaaS color scheme (warm ivory/white for A6, mint white for A5)
/// - The entire pill is tappable to switch to A5 in A6 mode
class DesignAndPrintBanner extends StatefulWidget {
  final String adSize; // 'A5' or 'A6'
  final String sideOption; // 'Both Sides' or 'One Side'
  final double? oneSideAmount;
  final double? bothSidesAmount;
  final VoidCallback? onSwitchToA5;

  const DesignAndPrintBanner({
    super.key,
    required this.adSize,
    this.sideOption = 'One Side',
    this.oneSideAmount,
    this.bothSidesAmount,
    this.onSwitchToA5,
  });

  @override
  State<DesignAndPrintBanner> createState() => _DesignAndPrintBannerState();
}

class _DesignAndPrintBannerState extends State<DesignAndPrintBanner>
    with TickerProviderStateMixin {
  late final AnimationController _strikeController;
  late final Animation<double> _strikeAnimation;

  late final AnimationController _badgeController;
  late final Animation<double> _badgeScaleAnimation;

  late final AnimationController _amountController;
  late Animation<int> _amountAnimation;

  bool get isA5 => widget.adSize.toUpperCase() == 'A5';
  bool get isBothSides => widget.sideOption.toLowerCase().contains('both');
  int get targetAmount => isBothSides
      ? (widget.bothSidesAmount?.round() ?? 10000)
      : (widget.oneSideAmount?.round() ?? 5000);

  @override
  void initState() {
    super.initState();

    final initialAmount = targetAmount;

    // Smooth count animation when placement changes
    _amountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _amountAnimation = IntTween(begin: initialAmount, end: initialAmount).animate(
      CurvedAnimation(parent: _amountController, curve: Curves.easeInOut),
    );

    // 400ms left-to-right strikethrough animation
    _strikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _strikeAnimation = CurvedAnimation(
      parent: _strikeController,
      curve: Curves.easeInOut,
    );

    // 250ms scale-up bounce animation for FREE badge
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _badgeScaleAnimation = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.easeOutBack,
    );

    _strikeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && isA5) {
          _badgeController.forward(from: 0.0);
        }
      }
    });

    if (isA5) {
      _strikeController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant DesignAndPrintBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasA5 = oldWidget.adSize.toUpperCase() == 'A5';
    final nowA5 = widget.adSize.toUpperCase() == 'A5';

    final wasBothSides = oldWidget.sideOption.toLowerCase().contains('both');
    final nowBothSides = widget.sideOption.toLowerCase().contains('both');
    final oldTarget = wasBothSides
        ? (oldWidget.bothSidesAmount?.round() ?? 10000)
        : (oldWidget.oneSideAmount?.round() ?? 5000);
    final newTarget = targetAmount;

    // Placement or dynamic amounts changed: animate count to newTarget
    if (oldTarget != newTarget ||
        wasBothSides != nowBothSides ||
        oldWidget.oneSideAmount != widget.oneSideAmount ||
        oldWidget.bothSidesAmount != widget.bothSidesAmount) {
      final startAmount = _amountAnimation.value;
      if (startAmount != newTarget) {
        _amountAnimation = IntTween(begin: startAmount, end: newTarget).animate(
          CurvedAnimation(parent: _amountController, curve: Curves.easeInOut),
        );
        _amountController.forward(from: 0.0);
      }
    }

    // Size changed: trigger or reset strikethrough & badge
    if (wasA5 != nowA5) {
      if (nowA5) {
        _badgeController.reset();
        _strikeController.forward(from: 0.0);
      } else {
        _strikeController.reset();
        _badgeController.reset();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _strikeController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _amountController,
        _strikeController,
        _badgeController,
      ]),
      builder: (context, _) {
        final displayAmount = _amountAnimation.value;
        final formattedAmount = formatIndianCurrency(displayAmount);

        final liveLabel = isA5
            ? 'Add Design & Print: $formattedAmount free. You saved $formattedAmount with A5.'
            : 'Add Design & Print: $formattedAmount. Switch to A5 and save $formattedAmount.';

        return Semantics(
          liveRegion: true,
          label: liveLabel,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isA5 ? null : widget.onSwitchToA5,
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    // Clean, subtle SaaS styling: Soft ivory-white for A6, mint-white for A5
                    color: isA5
                        ? const Color(0xFFF6FBF7)
                        : const Color(0xFFFFFDF8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isA5
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFDE68A),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isA5
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD97706))
                            .withAlpha(10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Line 1: Add Design & Print: ₹X [FREE]
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Add Design & Print: ',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              letterSpacing: -0.1,
                            ),
                          ),
                          if (!isA5)
                            Text(
                              formattedAmount,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F2A43),
                              ),
                            )
                          else ...[
                            // Strikethrough ₹X in grey
                            CustomPaint(
                              foregroundPainter: _AnimatedStrikethroughPainter(
                                progress: _strikeAnimation.value,
                                color: const Color(0xFF64748B),
                              ),
                              child: Text(
                                formattedAmount,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color.lerp(
                                    const Color(0xFF0F2A43),
                                    const Color(0xFF94A3B8),
                                    _strikeAnimation.value,
                                  ),
                                ),
                              ),
                            ),

                            // Green "FREE" badge with bouncy scale-up animation
                            if (_badgeScaleAnimation.value > 0.0)
                              Transform.scale(
                                scale: _badgeScaleAnimation.value,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withAlpha(40),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'FREE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 2.5), // Tight, elegant gap

                      // Line 2: Switch to A5 link OR You saved ₹X with A5
                      if (!isA5)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Switch to A5 and save $formattedAmount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 11.5,
                              color: Color(0xFFD97706),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 12.5,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'You saved $formattedAmount with A5',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter to draw animated strikethrough from left to right.
class _AnimatedStrikethroughPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AnimatedStrikethroughPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final y = size.height * 0.52;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * progress.clamp(0.0, 1.0), y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedStrikethroughPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

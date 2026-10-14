import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'ad_panel_widget.dart';
import 'design_and_print_banner.dart';
import 'payment_scanner_stand_widget.dart';

/// A large, polished live preview card with a light neutral display background.
/// Renders:
/// [Left Advertisement Board] [Static Payment Scanner Stand] [Right Advertisement Board]
///
/// Features:
/// - Floating top-right tag: e.g. "A5 • Both Sides"
/// - Soft countertop/display background
/// - Static centered scanner stand
/// - Completely adjacent zero-gap ad boards
/// - Informative caption below preview
class AdPreviewCard extends StatelessWidget {
  final String adSize; // 'A5' or 'A6'
  final String sideOption; // 'Both Sides' or 'One Side'
  final String brandName;
  final double a5Price;
  final double a6Price;
  final double? pricePerLocation;
  final int eligibleCount;
  final String countLabel;
  final double? designPrintOneSide;
  final double? designPrintBothSides;
  final ValueChanged<String>? onAdSizeChanged;
  final ValueChanged<String>? onPlacementChanged;

  const AdPreviewCard({
    super.key,
    required this.adSize,
    required this.sideOption,
    this.brandName = 'YOUR BRAND',
    this.a5Price = 80.0,
    this.a6Price = 100.0,
    this.pricePerLocation,
    this.eligibleCount = 0,
    this.countLabel = 'Shops',
    this.designPrintOneSide,
    this.designPrintBothSides,
    this.onAdSizeChanged,
    this.onPlacementChanged,
  });

  bool get isBothSides =>
      sideOption.toLowerCase() == 'both' ||
      sideOption.toLowerCase() == 'both sides';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        final isWideScreen = constraints.maxWidth >= 960;
        // PC View: scale stand preview 2x so it is 2 times bigger as requested
        final double previewScale = isWideScreen ? 2.0 : (isDesktop ? 1.5 : 1.0);
        final double stageHeight = 245.0 * previewScale;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(8),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Bar of Preview Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2A43).withAlpha(10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: Color(0xFF0F2A43),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'See how your advertisement will appear',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    // Floating top-right label: "A5 • Both Sides"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                      ),
                      child: Text(
                        '${adSize.toUpperCase()} • ${isBothSides ? "Both Sides" : "One Side"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F2A43),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 2. Display Countertop Stage (Significantly enlarged on PC to cover screen)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 28 : 16,
                  horizontal: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF8FAFC),
                      Color(0xFFF1F5F9),
                      Color(0xFFE8EDF3),
                    ],
                    stops: [0.0, 0.75, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // Stand and Ad Boards (Scaled 2x on PC via Transform.scale to be 2 times bigger)
                    SizedBox(
                      height: stageHeight,
                      width: double.infinity,
                      child: Center(
                        child: Transform.scale(
                          scale: previewScale,
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Left Advertisement Board (Directly touches scanner body with 0 gap)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: AdPanelWidget(
                                    adSize: adSize,
                                    sideName: 'Left',
                                    brandName: brandName,
                                  ),
                                ),

                                // Center Static Acrylic Payment Stand (Strictly fixed width & height)
                                const PaymentScannerStandWidget(),

                                // Right Wing (Directly touches scanner body with 0 gap)
                                ClipRect(
                                  child: AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOutCubic,
                                    child: isBothSides
                                        ? Padding(
                                            padding: const EdgeInsets.only(bottom: 10.0),
                                            child: AnimatedOpacity(
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                              opacity: 1.0,
                                              child: AdPanelWidget(
                                                adSize: adSize,
                                                sideName: 'Right',
                                                brandName: brandName,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Countertop perspective surface line
                    Container(
                      height: 2.5,
                      width: isDesktop ? (isWideScreen ? 860 : 640) : 280,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF94A3B8).withAlpha(100),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Centered Design & Print price line directly UNDER the scanner stand preview
                    DesignAndPrintBanner(
                      adSize: adSize,
                      sideOption: sideOption,
                      oneSideAmount: designPrintOneSide,
                      bothSidesAmount: designPrintBothSides,
                      onSwitchToA5: () => onAdSizeChanged?.call('A5'),
                    ),

                    const SizedBox(height: 12),

                    // 1. Single static rate strip directly BELOW "Add Design & Print" FREE badge box
                    // and ABOVE "Choose Ad Size / Choose Placement" selector pill
                    _buildRateStrip(context, isDesktop),

                    const SizedBox(height: 12),

                    // 3. Capsule Type Toggle Small Buttons Right Under the Scanner Stand
                    _buildCapsuleControls(context, isDesktop),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 4. Caption below preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Your advertisement will appear beside the payment scanner at each selected location.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Single static rate strip directly below the "Add Design & Print" box
  /// and above the "Choose Ad Size / Choose Placement" selector pill.
  Widget _buildRateStrip(BuildContext context, bool isDesktop) {
    final double rate = pricePerLocation ??
        (adSize.toUpperCase() == 'A5' ? a5Price : a6Price);
    final String formattedRate = '₹${rate.toStringAsFixed(0)}';
    final int dailyTotal = (rate * eligibleCount).round();
    final String formulaText =
        ' × $eligibleCount $countLabel = Total ₹$dailyTotal/Day';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'One Shop Per Day Rate',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F2A43),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Row(
                  key: ValueKey<String>(
                    '${formattedRate}_${eligibleCount}_$countLabel',
                  ),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedRate,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2A43),
                      ),
                    ),
                    Text(
                      formulaText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact, elegant capsule toggle small buttons right under the scanner stand
  /// On mobile: Two buttons in left and right beside each other (not up and down)
  /// On desktop: Wide horizontal row
  Widget _buildCapsuleControls(BuildContext context, bool isDesktop) {
    if (!isDesktop) {
      // Mobile view: Two buttons placed beside each other (left and right)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Button: Choose Ad Size
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Choose Ad Size',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCapsuleSegment(
                            title: 'A5',
                            isSelected: adSize.toUpperCase() == 'A5',
                            onTap: () => onAdSizeChanged?.call('A5'),
                            compact: true,
                          ),
                        ),
                        Expanded(
                          child: _buildCapsuleSegment(
                            title: 'A6',
                            isSelected: adSize.toUpperCase() == 'A6',
                            onTap: () => onAdSizeChanged?.call('A6'),
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right Button: Choose Placement
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Choose Placement',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCapsuleSegment(
                            title: 'One Side',
                            isSelected: !isBothSides,
                            onTap: () => onPlacementChanged?.call('One Side'),
                            compact: true,
                          ),
                        ),
                        Expanded(
                          child: _buildCapsuleSegment(
                            title: 'Both Sides',
                            isSelected: isBothSides,
                            onTap: () => onPlacementChanged?.call('Both Sides'),
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Desktop view: Clean wide capsule row
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Choose Ad Size Capsule
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Ad Size',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCapsuleSegment(
                      title: 'A5',
                      isSelected: adSize.toUpperCase() == 'A5',
                      onTap: () => onAdSizeChanged?.call('A5'),
                    ),
                    _buildCapsuleSegment(
                      title: 'A6',
                      isSelected: adSize.toUpperCase() == 'A6',
                      onTap: () => onAdSizeChanged?.call('A6'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 32),

          // 2. Choose Placement Capsule
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Placement',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCapsuleSegment(
                      title: 'One Side',
                      isSelected: !isBothSides,
                      onTap: () => onPlacementChanged?.call('One Side'),
                    ),
                    _buildCapsuleSegment(
                      title: 'Both Sides',
                      isSelected: isBothSides,
                      onTap: () => onPlacementChanged?.call('Both Sides'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleSegment({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 14,
          vertical: compact ? 5 : 6.5,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F2A43) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.full),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F2A43).withAlpha(35),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: compact ? 11 : 13,
                  color: const Color(0xFF0F9D8A),
                ),
                SizedBox(width: compact ? 3 : 4),
              ],
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

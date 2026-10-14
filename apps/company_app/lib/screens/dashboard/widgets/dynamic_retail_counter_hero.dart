import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Section 1: HERO for addcohol with Live Interactive Brand Preview
/// - Full-width yellow #FFD43B background, 96px bottom padding
/// - Top bar: logo "addcohol" with small navy dot on left, links "Zones" and "Live photos" on right
/// - Interactive question: "Brand Name" with input box
/// - Tabletop stand with BOTH sides dynamically displaying:
///     [Brand Name]
///     Advertisement
///     Here
///   in a high-end minimalist design
/// - Two columns, vertically centered: text left, scanner image right (image >= 45% width)
/// - Heading: 3 separate lines, 60px desktop / 38px phone, navy, weight 800:
///     Only 2 Positions
///     No More Competition
///     Get More Attention (on navy block #0E1624 with yellow text, rounded 10px)
/// - Sub line (24px, weight 600):
///     Now be seen in every shop, on every billing desk, with [every scan].
///     ("every scan" on navy block with yellow text)
/// - Body (17px, #2A2F3A)
/// - Buttons: "Explore Available Zones" (navy) and "Go to Company Portal" (white with 2px navy border)
/// - Scanner image: 2px navy border, radius 22px, hard navy shadow offset 10px right and 10px down
class DynamicRetailCounterHero extends StatefulWidget {
  final VoidCallback? onExploreZones;
  final VoidCallback? onZonesClick;
  final VoidCallback? onLivePhotos;

  const DynamicRetailCounterHero({
    super.key,
    this.onExploreZones,
    this.onZonesClick,
    this.onLivePhotos,
  });

  @override
  State<DynamicRetailCounterHero> createState() => _DynamicRetailCounterHeroState();
}

class _DynamicRetailCounterHeroState extends State<DynamicRetailCounterHero> {
  late final TextEditingController _brandController;

  @override
  void initState() {
    super.initState();
    // Default to 'Maloye' as requested in example
    _brandController = TextEditingController(text: 'Maloye');
  }

  @override
  void dispose() {
    _brandController.dispose();
    super.dispose();
  }

  static Future<void> launchAddcoholUrl() async {
    final uri = Uri.parse('https://addcohol.com');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    final headlineSize = isDesktop ? 60.0 : (isTablet ? 46.0 : 38.0);
    final sublineSize = isDesktop ? 24.0 : 18.0;
    final horizontalPadding = isDesktop ? 64.0 : 16.0;

    return Container(
      width: double.infinity,
      color: const Color(0xFFFFD43B), // Full-width yellow background
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: 28.0,
        bottom: 96.0, // 96px bottom padding
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1312),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP BAR
              _buildTopBar(context),

              SizedBox(height: isDesktop ? 56.0 : 40.0),

              // 2. HERO CONTENT (TWO COLUMNS ON DESKTOP, VERTICALLY CENTERED)
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column (Text + Brand Name Question & Box)
                        Expanded(
                          flex: 52,
                          child: _buildTextColumn(
                            context,
                            headlineSize: headlineSize,
                            sublineSize: sublineSize,
                            isDesktop: true,
                          ),
                        ),
                        const SizedBox(width: 56),
                        // Right Column (Interactive Scanner Stand Image with Both Sides Branded)
                        Expanded(
                          flex: 48,
                          child: _buildInteractiveScannerStand(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextColumn(
                          context,
                          headlineSize: headlineSize,
                          sublineSize: sublineSize,
                          isDesktop: false,
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: _buildInteractiveScannerStand(),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo: "addcohol" with small navy dot on the left
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF0E1624), // Small navy dot
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'addcohol',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0E1624),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        // Links: "Zones" and "Live photos", navy text
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onZonesClick ?? widget.onExploreZones,
                child: Text(
                  'Zones',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0E1624),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onLivePhotos,
                child: Text(
                  'Live photos',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0E1624),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextColumn(
    BuildContext context, {
    required double headlineSize,
    required double sublineSize,
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heading: 3 separate lines, 60px desktop / 38px phone, navy, weight 800
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only 2 Positions',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: headlineSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0E1624),
                height: 1.12,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No More Competition',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: headlineSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0E1624),
                height: 1.12,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 8),
            // "Get More Attention" on navy block (#0E1624) with yellow text, rounded 10px
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1624),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Get More Attention',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFD43B), // Yellow text
                  height: 1.12,
                  letterSpacing: -1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Sub line: 24px, weight 600 ("every scan" on navy block with yellow text)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Text(
              'Now be seen in every shop, on every billing desk, with',
              style: GoogleFonts.dmSans(
                fontSize: sublineSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0E1624),
                height: 1.35,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1624),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'every scan',
                style: GoogleFonts.dmSans(
                  fontSize: sublineSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFD43B), // Yellow text
                ),
              ),
            ),
            Text(
              '.',
              style: GoogleFonts.dmSans(
                fontSize: sublineSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0E1624),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Body: 17px, #2A2F3A
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Place your brand directly at customer eye level on acrylic UPI payment stands across verified partner retail stores. Guaranteed 100% focused attention at the exact moment of payment.',
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.normal,
              color: const Color(0xFF2A2F3A),
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 26),

        // ===================================================================
        // QUESTION: BRAND NAME & INPUT BOX (WITH LIVE TWO-WAY STAND SYNC)
        // ===================================================================
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0E1624), width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF0E1624),
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.draw_outlined,
                          size: 19,
                          color: Color(0xFF0E1624),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Brand Name',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0E1624),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD43B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LIVE STAND PREVIEW',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0E1624),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _brandController,
                  onChanged: (val) {
                    setState(() {});
                  },
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0E1624),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter brand name (e.g. Maloye)',
                    hintStyle: GoogleFonts.dmSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0E1624), width: 2.0),
                    ),
                    prefixIcon: const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFF0E1624),
                      size: 20,
                    ),
                    suffixIcon: _brandController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _brandController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Buttons: 52px tall, 17px text, radius 12px
        Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            // "Explore Available Zones" (Navy with white text)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0E1624),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: widget.onExploreZones,
              child: Text(
                'Explore Available Zones',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),

            // "Go to Company Portal" (White with 2px navy border)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0E1624),
                side: const BorderSide(color: Color(0xFF0E1624), width: 2.0),
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: launchAddcoholUrl,
              child: Text(
                'Go to Company Portal',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0E1624),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3-Panel Tabletop Stand Illustration with Real-Time Branded Ad Inserts on Both Sides
  Widget _buildInteractiveScannerStand() {
    final rawBrand = _brandController.text.trim();
    final brandName = rawBrand.isEmpty ? 'Maloye' : rawBrand;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF0E1624), width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0E1624), // Hard navy shadow
              offset: Offset(10, 10),    // 10px right and 10px down
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 563 / 313, // Exact aspect ratio of stand illustration
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                // Exact inner bounds of left and right panels from the original illustration:
                // Left Panel: x: 52..202 (w: 150), y: 31..294 (h: 263)
                final leftPanelLeft = w * (52.0 / 563.0);
                final leftPanelTop = h * (31.0 / 313.0);
                final leftPanelWidth = w * (150.0 / 563.0);
                final leftPanelHeight = h * (263.0 / 313.0);

                // Right Panel: x: 360..510 (w: 150), y: 31..294 (h: 263)
                final rightPanelLeft = w * (360.0 / 563.0);
                final rightPanelTop = h * (31.0 / 313.0);
                final rightPanelWidth = w * (150.0 / 563.0);
                final rightPanelHeight = h * (263.0 / 313.0);

                return Stack(
                  children: [
                    // Base illustration with QR center scanner & phone
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/interactive_qr_stand.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/tabletop_qr_scanner_stand.png',
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),

                    // LEFT AD PANEL (beside QR scanner)
                    Positioned(
                      left: leftPanelLeft,
                      top: leftPanelTop,
                      width: leftPanelWidth,
                      height: leftPanelHeight,
                      child: _buildAdPanelContent(
                        brandName: brandName,
                        panelWidth: leftPanelWidth,
                        panelHeight: leftPanelHeight,
                      ),
                    ),

                    // RIGHT AD PANEL (beside QR scanner)
                    Positioned(
                      left: rightPanelLeft,
                      top: rightPanelTop,
                      width: rightPanelWidth,
                      height: rightPanelHeight,
                      child: _buildAdPanelContent(
                        brandName: brandName,
                        panelWidth: rightPanelWidth,
                        panelHeight: rightPanelHeight,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// High-End Minimalist Ad Insert Design:
  /// [Brand Name]
  /// Advertisement
  /// Here
  Widget _buildAdPanelContent({
    required String brandName,
    required double panelWidth,
    required double panelHeight,
  }) {
    // Dynamic typographic scaling to fit panel bounds cleanly
    final brandSize = (panelWidth * 0.13).clamp(12.0, 21.0);
    final adSize = (panelWidth * 0.08).clamp(8.5, 13.5);
    final hereSize = (panelWidth * 0.09).clamp(9.5, 14.5);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: panelWidth * 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Brand Name
            Text(
              brandName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: brandSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0E1624),
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: panelHeight * 0.025),
            Container(
              width: panelWidth * 0.35,
              height: 2.0,
              color: const Color(0xFFFFD43B), // Yellow minimalist accent line
            ),
            SizedBox(height: panelHeight * 0.025),
            // Advertisement
            Text(
              'Advertisement',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: adSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A5568),
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: panelHeight * 0.008),
            // Here
            Text(
              'Here',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: hereSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0E1624),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

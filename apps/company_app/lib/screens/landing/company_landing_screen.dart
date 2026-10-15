import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dashboard/widgets/dynamic_retail_counter_hero.dart';
import '../../../services/user_session_service.dart';
import 'widgets/brand_entry_blur_gate.dart';

/// Standalone Public Landing Page for addcohol:
/// - Fonts: Bricolage Grotesque (800) for headings, DM Sans (400/500/600) for body
/// - One container on every section: max-width 1312px, centered, side padding 16px phone / 64px desktop
/// - Colors: yellow #FFD43B, navy #0E1624, white #FFFFFF, cream #FFF7DB, body text #3F4654
/// - No black background anywhere. No stretched or blurry images (constrained width)
/// - Phone: every two-column section stacks to one column (text first, image below)
///
/// Sections:
/// 1. HERO (full-width yellow #FFD43B background, 96px bottom padding)
/// 2. ZONE SECTION (white background, 104px top & bottom padding)
/// 3. LIVE PHOTOS SECTION (cream #FFF7DB background, 104px top & bottom padding)
/// 4. FOOTER (navy #0E1624)
class CompanyLandingScreen extends ConsumerStatefulWidget {
  const CompanyLandingScreen({super.key});

  @override
  ConsumerState<CompanyLandingScreen> createState() => _CompanyLandingScreenState();
}

class _CompanyLandingScreenState extends ConsumerState<CompanyLandingScreen> {
  final GlobalKey _zoneSectionKey = GlobalKey();
  final GlobalKey _livePhotosSectionKey = GlobalKey();

  bool _isCheckingSession = true;
  bool _isUnlocked = false;
  String? _savedBrandName;

  @override
  void initState() {
    super.initState();
    _checkCustomerSession();
  }

  Future<void> _checkCustomerSession() async {
    final loggedIn = await UserSessionService.instance.isLoggedIn();
    final brand = await UserSessionService.instance.getSavedBrandName();
    if (mounted) {
      setState(() {
        _isCheckingSession = false;
        _isUnlocked = loggedIn;
        _savedBrandName = brand;
      });
    }
  }

  void _onVerified(String brandName, String phoneNumber) {
    setState(() {
      _isUnlocked = true;
      _savedBrandName = brandName;
    });
  }

  Future<void> _handleLogout() async {
    await UserSessionService.instance.clearSession();
    if (mounted) {
      setState(() {
        _isUnlocked = false;
        _savedBrandName = null;
      });
    }
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

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // No black background anywhere
      body: Stack(
        children: [
          // 1. Landing Page Content
          SingleChildScrollView(
            physics: _isUnlocked
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HERO SECTION (Full-width yellow #FFD43B background, 96px bottom padding)
                DynamicRetailCounterHero(
                  onExploreZones: () => context.push('/map'),
                  onZonesClick: () => _scrollTo(_zoneSectionKey),
                  onLivePhotos: () => _scrollTo(_livePhotosSectionKey),
                  initialBrandName: _savedBrandName,
                  onLogout: _handleLogout,
                ),

                // 2. ZONE SECTION (White background, 104px top and bottom padding)
                Container(
                  key: _zoneSectionKey,
                  child: _buildZoneSection(context),
                ),

                // 3. LIVE PHOTOS SECTION (Cream #FFF7DB background, 104px top and bottom padding)
                Container(
                  key: _livePhotosSectionKey,
                  child: _buildLivePhotosSection(context),
                ),

                // 4. FOOTER (Navy #0E1624)
                _buildFooter(context),
              ],
            ),
          ),

          // 2. FULLSCREEN BLUR ENTRY GATE
          // Shown to first-time visitors before OTP verification
          if (!_isCheckingSession && !_isUnlocked)
            BrandEntryBlurGate(
              onVerified: _onVerified,
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. ZONE SECTION (White background, 104px top & bottom padding)
  // =========================================================================
  Widget _buildZoneSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final headingSize = isDesktop ? 46.0 : 32.0;
    final horizontalPadding = isDesktop ? 64.0 : 16.0;
    final verticalPadding = isDesktop ? 104.0 : 56.0; // 104px top & bottom padding

    return Container(
      width: double.infinity,
      color: Colors.white, // White background
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1312),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text Column (Left)
                    Expanded(
                      child: _buildZoneTextContent(context, headingSize: headingSize),
                    ),
                    const SizedBox(width: 80), // Gap 80px
                    // Image Column (Right, aligned with hero image right edge)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildZoneMapCard(),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildZoneTextContent(context, headingSize: headingSize),
                    const SizedBox(height: 40),
                    Center(child: _buildZoneMapCard()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildZoneTextContent(
    BuildContext context, {
    required double headingSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small badge "STEP 1" (white, 1px #D5DBE5 border, 12px uppercase, letter-spacing 0.1em, navy dot)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD5DBE5), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF0E1624), // Small navy dot
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'STEP 1',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF0E1624),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Heading (46px, navy, NO highlight, plain text, Bricolage Grotesque 800)
        Text(
          'Select your target area on the map',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: headingSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0E1624),
            height: 1.15,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 18),

        // Text (18px, #3F4654, DM Sans)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Click a zone, see its shops, and book your space in 2 clicks.',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: const Color(0xFF3F4654),
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Button: "Book your space" navy with arrow icon (52px tall, radius 12px)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0E1624),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: launchAddcoholUrl,
          icon: const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white),
          label: Text(
            'Book your space',
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoneMapCard() {
    // Map image inside a white card: 12px padding, 1px #DDE2EA border, radius 20px,
    // soft shadow (0 28px 48px -28px rgba(14,22,36,0.35)), max-width 560px. NO yellow frame.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/map'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDE2EA), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(14, 22, 36, 0.35),
                  offset: Offset(0, 28),
                  blurRadius: 48,
                  spreadRadius: -28,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(
                  'assets/images/zone_map_step_preview.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF5F7FA),
                      alignment: Alignment.center,
                      child: Text(
                        'Zone Map Preview',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF0E1624),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. LIVE PHOTOS SECTION (Cream #FFF7DB background, 104px padding)
  // =========================================================================
  Widget _buildLivePhotosSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final headingSize = isDesktop ? 46.0 : 32.0;
    final horizontalPadding = isDesktop ? 64.0 : 16.0;
    final verticalPadding = isDesktop ? 104.0 : 56.0; // Same 104px padding

    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7DB), // Cream background
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1312),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mirrored: Image Left
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildLiveProofCard(),
                      ),
                    ),
                    const SizedBox(width: 80), // Gap 80px
                    // Text Right
                    Expanded(
                      child: _buildLivePhotosTextContent(context, headingSize: headingSize),
                    ),
                  ],
                )
              : Column(
                  // Phone: Stacks to one column (text first, image below)
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLivePhotosTextContent(context, headingSize: headingSize),
                    const SizedBox(height: 40),
                    Center(child: _buildLiveProofCard()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLivePhotosTextContent(
    BuildContext context, {
    required double headingSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge "LIVE PROOF" with a small red dot, same badge style
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD5DBE5), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444), // Small Red dot
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE PROOF',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF0E1624),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Heading (46px, navy, plain, NO highlight, Bricolage Grotesque 800)
        Text(
          'Get daily live-updated photos on the map',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: headingSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0E1624),
            height: 1.15,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 18),

        // Text (18px, #3F4654, DM Sans)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'See your ad at every shop, right where it is.',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: const Color(0xFF3F4654),
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Button: "Book your space" navy with arrow icon (52px tall, radius 12px)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0E1624),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: launchAddcoholUrl,
          icon: const Icon(Icons.arrow_forward_rounded, size: 19, color: Colors.white),
          label: Text(
            'Book your space',
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveProofCard() {
    // Image in the same white card style as section 2 (12px padding, 1px #DDE2EA border, radius 20px, soft shadow)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE2EA), width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(14, 22, 36, 0.35),
              offset: Offset(0, 28),
              blurRadius: 48,
              spreadRadius: -28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.asset(
              'assets/images/live_proof_map_updated.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/live_proof_map_preview.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 4. FOOTER (Navy #0E1624)
  // =========================================================================
  Widget _buildFooter(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 64.0 : 16.0;

    return Container(
      width: double.infinity,
      color: const Color(0xFF0E1624), // Navy background
      padding: EdgeInsets.symmetric(
        vertical: 36.0,
        horizontal: horizontalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1312),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: "addcohol" in white with a small yellow dot on the left
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD43B), // Small yellow dot
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'addcohol',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),

              // Right: "addcohol.com" in #C9D1DD
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: launchAddcoholUrl,
                  child: Text(
                    'addcohol.com',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC9D1DD),
                    ),
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

import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/company_state_providers.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/ad_preview_card.dart';
import 'company_slot_booking_screen.dart';

/// Premium B2B Booking Checkout Screen for Advertisement Stand Spaces.
/// Follows modern SaaS styling with light background (#F8FAFC), Deep Navy (#0F2A43)
/// brand accents, and Teal (#0F9D8A) primary action triggers.
class CompanyAdBookingScreen extends ConsumerStatefulWidget {
  final Zone? initialZone;
  final String? initialZoneId;

  const CompanyAdBookingScreen({
    super.key,
    this.initialZone,
    this.initialZoneId,
  });

  @override
  ConsumerState<CompanyAdBookingScreen> createState() =>
      _CompanyAdBookingScreenState();
}

class _CompanyAdBookingScreenState
    extends ConsumerState<CompanyAdBookingScreen> {
  // Selection State
  Zone? _selectedZone;
  String _businessType = 'Shops'; // 'Shops' or 'Saloons'
  String _adSize = 'A5'; // 'A5' or 'A6'
  String _sideOption = 'Both Sides'; // 'Both Sides' or 'One Side'

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialZone != null) {
      _selectedZone = widget.initialZone;
    }

    // Listen to real-time zone pricing revision updates
    CanonicalZones.zonePricingRevision.addListener(_onPricingRevisionChanged);

    // Initial remote sync
    CanonicalZones.syncWithRemote();

    // Periodic remote sync timer (polls every 1 second for instant cross-app synchronization)
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      CanonicalZones.syncWithRemote();
    });
  }

  void _onPricingRevisionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    CanonicalZones.zonePricingRevision.removeListener(_onPricingRevisionChanged);
    _syncTimer?.cancel();
    super.dispose();
  }

  void _onZoneChanged(Zone? newZone) {
    if (newZone != null && newZone.id != _selectedZone?.id) {
      setState(() {
        _selectedZone = newZone;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(companyAuthProvider);
    final company = authState.company;

    // 1. Authentication & Security Guard
    if (company == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Book Advertisement Space'),
        ),
        body: Center(
          child: AppErrorView(
            title: 'Authentication Required',
            message:
                'Please log in with your company credentials to view and book spaces.',
            retryLabel: 'Go to Login',
            onRetry: () => context.go('/login'),
          ),
        ),
      );
    }

    if (!company.hasAssignedZones) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Book Advertisement Space'),
        ),
        body: Center(
          child: AppErrorView(
            title: 'No Assigned Zones',
            message:
                'Your company account currently has no assigned zones assigned by the Master Admin.',
            retryLabel: 'Return to Dashboard',
            onRetry: () => context.go('/'),
          ),
        ),
      );
    }

    // 2. Load Available Zones
    final assignedZonesAsync = ref.watch(companyAllZonesProvider);

    return assignedZonesAsync.when(
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(context),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F2A43)),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(context),
        body: Center(
          child: AppErrorView(
            title: 'Unable to load zones',
            message: err.toString(),
            retryLabel: 'Retry',
            onRetry: () => ref.invalidate(companyAllZonesProvider),
          ),
        ),
      ),
      data: (assignedZones) {
        if (assignedZones.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: _buildAppBar(context),
            body: Center(
              child: AppErrorView(
                title: 'No Zones Assigned',
                message:
                    'You can book only inside Zones assigned to your Company.',
                retryLabel: 'Return to Dashboard',
                onRetry: () => context.go('/'),
              ),
            ),
          );
        }

        // Initialize or resolve selected zone
        if (_selectedZone == null) {
          if (widget.initialZoneId != null) {
            _selectedZone = assignedZones.cast<Zone?>().firstWhere(
                  (z) => z?.id == widget.initialZoneId,
                  orElse: () => assignedZones.first,
                );
          } else {
            _selectedZone = assignedZones.first;
          }
        }

        // Strictly verify that selected zone is inside company assigned zones
        final isZoneAssigned =
            assignedZones.any((z) => z.id == _selectedZone?.id);

        if (!isZoneAssigned) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: _buildAppBar(context),
            body: Center(
              child: AppErrorView(
                title: 'Unauthorized Zone',
                message:
                    'Access restricted: You can book only inside Zones assigned to your Company (${company.tradeName}).',
                retryLabel: 'Select Assigned Zone',
                onRetry: () {
                  setState(() => _selectedZone = assignedZones.first);
                },
              ),
            ),
          );
        }

        final activeZone = _selectedZone!;
        final brandName = company.tradeName;

        return _buildBookingScaffold(
          context: context,
          theme: theme,
          company: company,
          assignedZones: assignedZones,
          activeZone: activeZone,
          brandName: brandName,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Book Advertisement Space',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildBookingScaffold({
    required BuildContext context,
    required ThemeData theme,
    required Company company,
    required List<Zone> assignedZones,
    required Zone activeZone,
    required String brandName,
  }) {
    final zoneShopsAsync = ref.watch(companyZoneShopsProvider(activeZone.id));
    final pricingListAsync = ref.watch(companyPricingListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: pricingListAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F2A43)),
        ),
        error: (e, _) => Center(
          child: AppErrorView(
            title: 'Pricing Error',
            message: 'Unable to load advertisement pricing: $e',
            retryLabel: 'Retry',
            onRetry: () => ref.invalidate(companyPricingListProvider),
          ),
        ),
        data: (pricingList) {
          return zoneShopsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F2A43)),
            ),
            error: (e, _) => Center(
              child: AppErrorView(
                title: 'Shop Inventory Error',
                message: 'Unable to load shops for ${activeZone.name}: $e',
                retryLabel: 'Retry',
                onRetry: () =>
                    ref.invalidate(companyZoneShopsProvider(activeZone.id)),
              ),
            ),
            data: (allZoneShops) {
              // Calculate counts strictly from backend response
              final regularShopsCount = allZoneShops
                  .where((s) => s.shopCategory != ShopCategory.saloon)
                  .length;
              final saloonsCount = allZoneShops
                  .where((s) => s.shopCategory == ShopCategory.saloon)
                  .length;

              final isShops = _businessType == 'Shops';
              final eligibleCount = isShops ? regularShopsCount : saloonsCount;
              final countLabel = isShops ? 'Shops' : 'Saloons';

              // Resolve price from zone-specific configuration or platform matrix
              final sideParam = _sideOption == 'Both Sides' ? 'both' : 'one';
              final zonePricing = _selectedZone != null
                  ? CanonicalZones.getZonePricing(_selectedZone!.id)
                  : null;

              final pricePerLocation = zonePricing != null
                  ? zonePricing.resolvePrice(
                      businessType: isShops ? 'shops' : 'saloons',
                      adSize: _adSize,
                      sideOption: sideParam,
                    )
                  : AdvertisementPricing.resolvePrice(
                      pricingList: pricingList,
                      businessType: isShops ? 'shops' : 'saloons',
                      adSize: _adSize,
                      sideOption: sideParam,
                    );

              final isA6 = _adSize.toUpperCase() == 'A6';
              final isBothSides = _sideOption.toLowerCase().contains('both');
              final designAndPrintFee = zonePricing != null
                  ? zonePricing.resolveDesignPrintFee(
                      adSize: _adSize,
                      sideOption: _sideOption,
                    )
                  : (isA6 ? (isBothSides ? 10000.0 : 5000.0) : 0.0);
              final baseWeeklyTotal = pricePerLocation * eligibleCount;
              final totalAmount =
                  eligibleCount > 0 ? (baseWeeklyTotal + designAndPrintFee) : 0.0;

              final a5Price = zonePricing != null
                  ? zonePricing.resolvePrice(
                      businessType: isShops ? 'shops' : 'saloons',
                      adSize: 'A5',
                      sideOption: sideParam,
                    )
                  : AdvertisementPricing.resolvePrice(
                      pricingList: pricingList,
                      businessType: isShops ? 'shops' : 'saloons',
                      adSize: 'A5',
                      sideOption: sideParam,
                    );
              final a6Price = zonePricing != null
                  ? zonePricing.resolvePrice(
                      businessType: isShops ? 'shops' : 'saloons',
                      adSize: 'A6',
                      sideOption: sideParam,
                    )
                  : AdvertisementPricing.resolvePrice(
                      pricingList: pricingList,
                      businessType: isShops ? 'shops' : 'saloons',
                      adSize: 'A6',
                      sideOption: sideParam,
                    );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 768;

                  return isDesktop
                      ? _buildDesktopLayout(
                          context: context,
                          theme: theme,
                          company: company,
                          assignedZones: assignedZones,
                          activeZone: activeZone,
                          brandName: brandName,
                          regularShopsCount: regularShopsCount,
                          saloonsCount: saloonsCount,
                          eligibleCount: eligibleCount,
                          countLabel: countLabel,
                          pricePerLocation: pricePerLocation,
                          a5Price: a5Price,
                          a6Price: a6Price,
                          totalAmount: totalAmount,
                          designAndPrintFee: designAndPrintFee,
                          designPrintOneSide: zonePricing?.designPrintA6OneSide,
                          designPrintBothSides: zonePricing?.designPrintA6BothSides,
                        )
                      : _buildMobileLayout(
                          context: context,
                          theme: theme,
                          company: company,
                          assignedZones: assignedZones,
                          activeZone: activeZone,
                          brandName: brandName,
                          regularShopsCount: regularShopsCount,
                          saloonsCount: saloonsCount,
                          eligibleCount: eligibleCount,
                          countLabel: countLabel,
                          pricePerLocation: pricePerLocation,
                          a5Price: a5Price,
                          a6Price: a6Price,
                          totalAmount: totalAmount,
                          designAndPrintFee: designAndPrintFee,
                          designPrintOneSide: zonePricing?.designPrintA6OneSide,
                          designPrintBothSides: zonePricing?.designPrintA6BothSides,
                        );
                },
              );
            },
          );
        },
      ),
    );
  }

  // =========================================================================
  // DESKTOP LAYOUT (>= 768px, Visual-First Centered in Max-Width 1100px)
  // =========================================================================
  Widget _buildDesktopLayout({
    required BuildContext context,
    required ThemeData theme,
    required Company company,
    required List<Zone> assignedZones,
    required Zone activeZone,
    required String brandName,
    required int regularShopsCount,
    required int saloonsCount,
    required int eligibleCount,
    required String countLabel,
    required double pricePerLocation,
    required double a5Price,
    required double a6Price,
    required double totalAmount,
    required double designAndPrintFee,
    double? designPrintOneSide,
    double? designPrintBothSides,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP SECTION: Compact Header
              _buildCompactHeader(
                context: context,
                assignedZones: assignedZones,
                activeZone: activeZone,
                eligibleCount: eligibleCount,
                countLabel: countLabel,
              ),

              const SizedBox(height: 18),

              // 2. MAIN BUSINESS TYPE TOGGLE: Large [ Shops ] [ Saloons ]
              _buildMainBusinessTypeToggle(
                regularShopsCount: regularShopsCount,
                saloonsCount: saloonsCount,
              ),

              const SizedBox(height: 18),

              // 3. LIVE INTERACTIVE STAND PREVIEW: Enlarged Stand with Capsule Toggles Under Stand
              AdPreviewCard(
                adSize: _adSize,
                sideOption: _sideOption,
                brandName: brandName,
                a5Price: a5Price,
                a6Price: a6Price,
                pricePerLocation: pricePerLocation,
                eligibleCount: eligibleCount,
                countLabel: countLabel,
                designPrintOneSide: designPrintOneSide,
                designPrintBothSides: designPrintBothSides,
                onAdSizeChanged: (newSize) => setState(() => _adSize = newSize),
                onPlacementChanged: (newPlacement) =>
                    setState(() => _sideOption = newPlacement),
              ),

              const SizedBox(height: 18),

              // 4. PICK YOUR WEEK BUTTON
              _buildPickYourWeekSection(
                context: context,
                company: company,
                activeZone: activeZone,
                pricePerLocation: pricePerLocation,
                eligibleCount: eligibleCount,
                totalAmount: totalAmount,
                designAndPrintFee: designAndPrintFee,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MOBILE LAYOUT (< 768px, Visual-First Single Column + Sticky Bottom Bar)
  // =========================================================================
  Widget _buildMobileLayout({
    required BuildContext context,
    required ThemeData theme,
    required Company company,
    required List<Zone> assignedZones,
    required Zone activeZone,
    required String brandName,
    required int regularShopsCount,
    required int saloonsCount,
    required int eligibleCount,
    required String countLabel,
    required double pricePerLocation,
    required double a5Price,
    required double a6Price,
    required double totalAmount,
    required double designAndPrintFee,
    double? designPrintOneSide,
    double? designPrintBothSides,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP SECTION: Compact Header
            _buildCompactHeader(
              context: context,
              assignedZones: assignedZones,
              activeZone: activeZone,
              eligibleCount: eligibleCount,
              countLabel: countLabel,
            ),

            const SizedBox(height: 16),

            // 2. MAIN BUSINESS TYPE TOGGLE: Large [ Shops ] [ Saloons ]
            _buildMainBusinessTypeToggle(
              regularShopsCount: regularShopsCount,
              saloonsCount: saloonsCount,
            ),

            const SizedBox(height: 16),

            // 3. LIVE INTERACTIVE STAND PREVIEW: With Capsule Toggles Under Stand
            AdPreviewCard(
              adSize: _adSize,
              sideOption: _sideOption,
              brandName: brandName,
              a5Price: a5Price,
              a6Price: a6Price,
              pricePerLocation: pricePerLocation,
              eligibleCount: eligibleCount,
              countLabel: countLabel,
              designPrintOneSide: designPrintOneSide,
              designPrintBothSides: designPrintBothSides,
              onAdSizeChanged: (newSize) => setState(() => _adSize = newSize),
              onPlacementChanged: (newPlacement) =>
                  setState(() => _sideOption = newPlacement),
            ),

            const SizedBox(height: 16),

            // 4. PICK YOUR WEEK BUTTON
            _buildPickYourWeekSection(
              context: context,
              company: company,
              activeZone: activeZone,
              pricePerLocation: pricePerLocation,
              eligibleCount: eligibleCount,
              totalAmount: totalAmount,
              designAndPrintFee: designAndPrintFee,
            ),
          ],
        ),
      ),
      // Sticky Bottom Action Bar on Mobile
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL ($eligibleCount locations)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      formatIndianCurrency(totalAmount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F2A43),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  elevation: 0,
                ),
                onPressed: eligibleCount > 0
                    ? () => _handleContinueToBook(
                          context: context,
                          company: company,
                          activeZone: activeZone,
                          pricePerLocation: pricePerLocation,
                          eligibleCount: eligibleCount,
                          totalAmount: totalAmount,
                          designAndPrintFee: designAndPrintFee,
                        )
                    : null,
                child: const Text(
                  'Pick Your Week',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. TOP SECTION: COMPACT HEADER
  // =========================================================================
  Widget _buildCompactHeader({
    required BuildContext context,
    required List<Zone> assignedZones,
    required Zone activeZone,
    required int eligibleCount,
    required String countLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Book Advertisement Space',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Choose your placement and preview it before booking.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Zone & Availability Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: Color(0xFF0F2A43),
                ),
                const SizedBox(width: 4),
                if (assignedZones.length > 1)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: activeZone.id,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: Color(0xFF0F2A43)),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F2A43),
                      ),
                      onChanged: (newId) {
                        if (newId != null) {
                          final match = assignedZones
                              .firstWhere((z) => z.id == newId);
                          _onZoneChanged(match);
                        }
                      },
                      items: assignedZones.map((z) {
                        return DropdownMenuItem<String>(
                          value: z.id,
                          child: Text(z.name),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Text(
                    activeZone.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F2A43),
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F9D8A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$eligibleCount available locations in zone',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. MAIN BUSINESS TYPE TOGGLE: Large [ Shops ] [ Saloons ]
  // =========================================================================
  Widget _buildMainBusinessTypeToggle({
    required int regularShopsCount,
    required int saloonsCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildLargeCategoryCard(
            title: 'Shops',
            subtitle: '$regularShopsCount locations',
            icon: Icons.storefront_rounded,
            isSelected: _businessType == 'Shops',
            onTap: () => setState(() => _businessType = 'Shops'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildLargeCategoryCard(
            title: 'Saloons',
            subtitle: '$saloonsCount locations',
            icon: Icons.content_cut_rounded,
            isSelected: _businessType == 'Saloons',
            onTap: () => setState(() => _businessType = 'Saloons'),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F2A43) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F2A43) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF0F2A43).withAlpha(35)
                  : const Color(0xFF0F172A).withAlpha(4),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Large Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withAlpha(25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? Colors.white : const Color(0xFF0F2A43),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withAlpha(210)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F9D8A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. PICK YOUR WEEK BUTTON
  // =========================================================================
  Widget _buildPickYourWeekSection({
    required BuildContext context,
    required Company company,
    required Zone activeZone,
    required double pricePerLocation,
    required int eligibleCount,
    required double totalAmount,
    required double designAndPrintFee,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9D8A),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: const Color(0xFF0F9D8A).withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: eligibleCount > 0
                      ? () => _handleContinueToBook(
                            context: context,
                            company: company,
                            activeZone: activeZone,
                            pricePerLocation: pricePerLocation,
                            eligibleCount: eligibleCount,
                            totalAmount: totalAmount,
                            designAndPrintFee: designAndPrintFee,
                          )
                      : null,
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  label: const Text(
                    'Pick Your Week',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text(
                      'Secured & encrypted booking • Verified by Master Admin',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
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

  // =========================================================================
  // CONTINUATION TO BOOKING CONFIRMATION & WORKFLOW
  // =========================================================================
  void _handleContinueToBook({
    required BuildContext context,
    required Company company,
    required Zone activeZone,
    required double pricePerLocation,
    required int eligibleCount,
    required double totalAmount,
    required double designAndPrintFee,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanySlotBookingScreen(
          company: company,
          zone: activeZone,
          businessType: _businessType,
          adSize: _adSize,
          sideOption: _sideOption,
          pricePerLocation: pricePerLocation,
          eligibleCount: eligibleCount,
          baseWeeklyTotal: (pricePerLocation * eligibleCount) * 7,
          designAndPrintFee: designAndPrintFee,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:payment_features/payment_features.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/currency_formatter.dart';
import 'widgets/booking_verification_dialog.dart';
import 'widgets/week_slot_button.dart';

/// Availability of a 7-day slot in a zone based on stand sides (Left and Right).
enum SlotAvailability {
  bothSidesAvailable, // Both Left and Right faces are free
  oneSideAvailable, // Only 1 side is free (the other is booked)
  fullyBooked, // Neither side is free (both booked)
}

/// Month Group representing the floating month and its weekly Monday-Sunday slots.
class MonthSlotGroup {
  final String id;
  final String monthName; // e.g. "OCTOBER", "NOVEMBER"
  final int year;
  final List<WeekSlotData> slots;

  const MonthSlotGroup({
    required this.id,
    required this.monthName,
    required this.year,
    required this.slots,
  });

  String get label => '$monthName $year';
}

/// Calendar Week Slot Booking Screen matching the exact light SaaS theme of
/// the Advertisement Space booking page:
/// - Light background (#F8FAFC)
/// - Clean white AppBar with Deep Navy title (#0F172A) & thin divider (#E2E8F0)
/// - Floating white month pill with Deep Navy text (#0F2A43)
/// - Month section divider lines: "------ OCTOBER 2026 ------"
/// - White slot capsules with:
///   - Available: soft slate border (#CBD5E1), Deep Navy dates (#0F2A43), "Book" / "7 DAYS"
///   - Selected: 2px Teal border (#0F9D8A), Teal center pocket with "Selected ×" & "7 DAYS"
///   - Booked: slate-100 fill (#F1F5F9), dashed border (#CBD5E1), muted text (#94A3B8), "BOOKED"
///   - Cross-month dates display month abbreviation on right (e.g. "1 NOV", "6 DEC")
/// - Bottom bar:
///   - "X weeks selected" + "₹X per location · Y locations"
///   - "TOTAL" + "₹X"
///   - "Confirm booking" button: disabled (#E2E8F0) or active (Brand Teal #0F9D8A)
class CompanySlotBookingScreen extends ConsumerStatefulWidget {
  final Company company;
  final Zone zone;
  final String businessType; // 'Shops' or 'Saloons'
  final String adSize; // 'A5' or 'A6'
  final String sideOption; // 'Both Sides' or 'One Side'
  final double pricePerLocation; // weekly price per location
  final int eligibleCount;
  final double baseWeeklyTotal; // pricePerLocation * eligibleCount
  final double designAndPrintFee; // One-time fee (₹5,000 for A6, ₹0 for A5)

  const CompanySlotBookingScreen({
    super.key,
    required this.company,
    required this.zone,
    required this.businessType,
    required this.adSize,
    required this.sideOption,
    required this.pricePerLocation,
    required this.eligibleCount,
    required this.baseWeeklyTotal,
    this.designAndPrintFee = 0.0,
  });

  @override
  ConsumerState<CompanySlotBookingScreen> createState() =>
      _CompanySlotBookingScreenState();
}

class _CompanySlotBookingScreenState
    extends ConsumerState<CompanySlotBookingScreen> {
  static const Color colorBg = Color(0xFFF8FAFC);
  static const Color colorNavy = Color(0xFF0F2A43);
  static const Color colorTeal = Color(0xFF0F9D8A);

  /// Selection map: slot.id -> selected WeekSlotData.
  /// Allows selecting multiple weeks in any month if available!
  final Map<String, WeekSlotData> _selectedSlots = {};

  final List<MonthSlotGroup> _monthGroups = [];
  final ScrollController _scrollController = ScrollController();

  int _activeMonthIndex = 0;
  bool _isSubmitting = false;
  Timer? _syncTimer;

  // Month generation pointer
  late DateTime _nextGenerationMonday;

  static const List<String> _monthNames = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  @override
  void initState() {
    super.initState();

    // Initial base Monday: October 5, 2026 (a Monday)
    _nextGenerationMonday = DateTime(2026, 10, 5);

    // Pre-generate 12 months of slots
    _generateNextMonths(12);

    _scrollController.addListener(_onScroll);
    CanonicalZones.zonePricingRevision.addListener(_onPricingRevisionChanged);

    // Periodic remote sync timer (polls every 1 second)
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final updated = await CanonicalZones.syncWithRemote();
      if (updated && mounted) {
        setState(() {});
      }
    });
  }

  void _onPricingRevisionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CanonicalZones.zonePricingRevision.removeListener(_onPricingRevisionChanged);
    _syncTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Checks slot availability for this zone, date, and business type.
  /// Categorizes slots into:
  /// - fullyBooked (both sides booked)
  /// - oneSideAvailable (only 1 side available in this zone)
  /// - bothSidesAvailable (both sides available in this zone)
  SlotAvailability _getSlotAvailability(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    final targetBiz =
        widget.businessType.toLowerCase().contains('saloon') ? 'saloon' : 'shop';

    // 1. Check Canonical / dynamic runs in this zone
    final runs = CanonicalZones.getCompanyAdRuns(widget.zone.id);
    bool leftBooked = false;
    bool rightBooked = false;

    for (final run in runs) {
      if (run.businessType.toLowerCase() != targetBiz) continue;
      if (run.status.toLowerCase() == 'cancelled' ||
          run.status.toLowerCase() == 'completed') {
        continue;
      }
      // Only check runs that are calendar slot bookings
      if (!run.id.startsWith('ad-run-ad-book') && !run.id.startsWith('slot-run-')) {
        continue;
      }
      // Overlap with this week [monday..sunday]
      if (run.slotEndDate.isBefore(monday) || run.slotStartDate.isAfter(sunday)) {
        continue;
      }
      final side = run.placementSide.toLowerCase();
      if (side == 'both') {
        leftBooked = true;
        rightBooked = true;
        break;
      } else if (side == 'left') {
        leftBooked = true;
      } else if (side == 'right') {
        rightBooked = true;
      } else if (side == 'one') {
        if (!leftBooked) {
          leftBooked = true;
        } else {
          rightBooked = true;
        }
      }
    }

    if (leftBooked && rightBooked) {
      return SlotAvailability.fullyBooked;
    }

    // 2. Pre-booked demo dates for testing & showcase
    // Oct 12 2026: fully booked in Kolkata Central & default zones
    if (monday.year == 2026 && monday.month == 10 && monday.day == 12) {
      return SlotAvailability.fullyBooked;
    }
    // Nov 16 2026: fully booked
    if (monday.year == 2026 && monday.month == 11 && monday.day == 16) {
      return SlotAvailability.fullyBooked;
    }
    // Jan 11 2027: fully booked
    if (monday.year == 2027 && monday.month == 1 && monday.day == 11) {
      return SlotAvailability.fullyBooked;
    }

    // Oct 19 2026: One side booked (Left), One side free (Right)
    // Nov 9 2026: One side booked, One side free
    if ((monday.year == 2026 && monday.month == 10 && monday.day == 19) ||
        (monday.year == 2026 && monday.month == 11 && monday.day == 9)) {
      leftBooked = true;
    }

    if (leftBooked && rightBooked) {
      return SlotAvailability.fullyBooked;
    } else if (leftBooked || rightBooked) {
      return SlotAvailability.oneSideAvailable;
    }

    return SlotAvailability.bothSidesAvailable;
  }

  /// Endless scrolling generator: dynamically appends [count] upcoming months.
  /// Side-aware filtering rule:
  /// If the client has selected 'Both Sides', only both side available weeks
  /// (and fully booked slots) are visible in that zone, not slots of one side!
  void _generateNextMonths(int count) {
    int generated = 0;
    final isBothSides = widget.sideOption.toLowerCase().contains('both');

    while (generated < count) {
      final currentMonth = _nextGenerationMonday.month;
      final currentYear = _nextGenerationMonday.year;
      final monthName = _monthNames[currentMonth - 1];

      final slotsForThisMonth = <WeekSlotData>[];

      // Collect all weeks that start with Monday in this month
      while (_nextGenerationMonday.month == currentMonth &&
          _nextGenerationMonday.year == currentYear) {
        final start = _nextGenerationMonday;
        final end = start.add(const Duration(days: 6));

        final availability = _getSlotAvailability(start);

        // If client selected 'Both Sides', exclude weeks where only one side is available
        if (isBothSides && availability == SlotAvailability.oneSideAvailable) {
          _nextGenerationMonday =
              _nextGenerationMonday.add(const Duration(days: 7));
          continue;
        }

        final isBooked = availability == SlotAvailability.fullyBooked;

        slotsForThisMonth.add(
          WeekSlotData(
            id: 'slot-${start.year}-${_twoDigits(start.month)}-${_twoDigits(start.day)}',
            startDate: start,
            endDate: end,
            isBooked: isBooked,
            monthName: monthName,
            year: currentYear,
          ),
        );

        _nextGenerationMonday =
            _nextGenerationMonday.add(const Duration(days: 7));
      }

      if (slotsForThisMonth.isNotEmpty) {
        _monthGroups.add(
          MonthSlotGroup(
            id: '$currentYear-$monthName',
            monthName: monthName,
            year: currentYear,
            slots: slotsForThisMonth,
          ),
        );
        generated++;
      }
    }
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Tracks scrolling position to update the floating active month label
  void _onScroll() {
    if (_scrollController.hasClients) {
      // Endless scroll check: if within 600px of bottom, append 6 more months
      if (_scrollController.position.extentAfter < 600) {
        setState(() {
          _generateNextMonths(6);
        });
      }

      // Compute which month is currently at the top of the viewport
      final currentOffset = _scrollController.offset;
      double accumulatedHeight = 0.0;
      int newActiveIndex = 0;

      for (int i = 0; i < _monthGroups.length; i++) {
        final group = _monthGroups[i];
        final groupHeight = 44.0 + (group.slots.length * 69.0) + 16.0;
        if (currentOffset >= accumulatedHeight - 40) {
          newActiveIndex = i;
        }
        accumulatedHeight += groupHeight;
      }

      if (newActiveIndex != _activeMonthIndex &&
          newActiveIndex < _monthGroups.length) {
        setState(() {
          _activeMonthIndex = newActiveIndex;
        });
      }
    }
  }

  double get _currentPricePerLocation {
    final zonePricing = CanonicalZones.getZonePricing(widget.zone.id);
    final resolved = zonePricing.resolvePrice(
      businessType: widget.businessType,
      adSize: widget.adSize,
      sideOption: widget.sideOption,
    );
    return resolved > 0 ? resolved : widget.pricePerLocation;
  }

  double get _currentDesignAndPrintFee {
    final zonePricing = CanonicalZones.getZonePricing(widget.zone.id);
    final resolved = zonePricing.resolveDesignPrintFee(
      adSize: widget.adSize,
      sideOption: widget.sideOption,
    );
    return widget.adSize.toUpperCase() == 'A6'
        ? (resolved > 0 ? resolved : widget.designAndPrintFee)
        : 0.0;
  }

  int get _selectedWeeksCount => _selectedSlots.length;
  double get _dailyTotal => _currentPricePerLocation * widget.eligibleCount;
  int get _totalDays => _selectedWeeksCount * 7;
  double get _daysCost => _dailyTotal * _totalDays;
  double get _totalAmount => _selectedWeeksCount > 0
      ? (_daysCost + _currentDesignAndPrintFee)
      : 0.0;

  /// User selection logic matching specification:
  /// - Multiple weeks per month can be selected concurrently if available
  /// - Tapping an already selected week deselects it
  void _toggleSlot(WeekSlotData slot) {
    if (slot.isBooked) return;

    setState(() {
      if (_selectedSlots.containsKey(slot.id)) {
        // Tapping again deselects it
        _selectedSlots.remove(slot.id);
      } else {
        // Multi-week selection allowed in the same month and across months
        _selectedSlots[slot.id] = slot;
      }
    });
  }

  void _handleConfirmBooking() {
    if (_selectedWeeksCount == 0 || _isSubmitting) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BookingVerificationDialog(
        initialBusinessName: widget.company.tradeName,
        initialPhone: widget.company.contactPhone,
        zoneName: widget.zone.name,
        weeksCount: _selectedWeeksCount,
        totalAmount: _totalAmount,
        onConfirm: ({
          required String businessName,
          required String phoneNumber,
          required String otp,
        }) async {
          // Open Cashfree Payment Gateway Checkout Modal
          final paymentResult = await CashfreeCheckoutModal.show(
            context,
            amount: _totalAmount,
            orderTitle: '${widget.zone.name} • ${_selectedWeeksCount}w Campaign',
            customerName: businessName,
            customerPhone: phoneNumber,
            bookingId: 'BK-${DateTime.now().millisecondsSinceEpoch}',
          );

          if (paymentResult != null && paymentResult.isSuccess) {
            await _performBookingSubmission(
              businessName: businessName,
              phoneNumber: phoneNumber,
              otp: otp,
              paymentResult: paymentResult,
            );
          } else if (paymentResult != null && !paymentResult.isSuccess) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Payment cancelled: ${paymentResult.errorMessage ?? "Transaction not completed"}'),
                  backgroundColor: const Color(0xFFE11D48),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _performBookingSubmission({
    required String businessName,
    required String phoneNumber,
    required String otp,
    required CashfreePaymentResult paymentResult,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final selectedSlots = _selectedSlots.values.toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      final firstSlot = selectedSlots.first;
      final lastSlot = selectedSlots.last;
      final slotLabels = selectedSlots
          .map((s) =>
              '${s.monthName ?? ""} ${s.startDayString}–${s.endDayString}')
          .toList();

      final booking = AdSpaceBooking(
        id: 'ad-book-${DateTime.now().millisecondsSinceEpoch}',
        companyId: widget.company.id,
        companyName: businessName,
        zoneId: widget.zone.id,
        zoneName: widget.zone.name,
        businessType: widget.businessType.toLowerCase(),
        adSize: widget.adSize,
        sideOption: widget.sideOption == 'Both Sides' ? 'both' : 'one',
        pricePerLocation: _currentPricePerLocation,
        eligibleLocationCount: widget.eligibleCount,
        totalAmount: _totalAmount,
        status: 'confirmed',
        createdAt: DateTime.now(),
        slotStartDate: firstSlot.startDate,
        slotEndDate: lastSlot.endDate,
        selectedWeeksCount: _selectedWeeksCount,
        selectedSlotLabels: slotLabels,
        paymentMethod: 'Cashfree ${paymentResult.paymentMethod}',
        paymentId: paymentResult.cfPaymentId,
        orderId: paymentResult.orderId,
        paidAt: paymentResult.paidAt ?? DateTime.now(),
      );

      final repo = ref.read(companyRepositoryProvider);
      await repo.createAdSpaceBooking(booking);

      // Register each slot in CanonicalZones so Master Admin and future queries update immediately
      final targetBiz = widget.businessType.toLowerCase().contains('saloon')
          ? 'saloon'
          : 'shop';
      final existingRuns = CanonicalZones.getCompanyAdRuns(widget.zone.id);

      for (final slot in selectedSlots) {
        String resolvedPlacementSide = 'both';
        if (widget.sideOption != 'Both Sides') {
          final isDemoLeftTaken = (slot.startDate.year == 2026 &&
                  slot.startDate.month == 10 &&
                  slot.startDate.day == 19) ||
              (slot.startDate.year == 2026 &&
                  slot.startDate.month == 11 &&
                  slot.startDate.day == 9);
          final isLeftTaken = isDemoLeftTaken ||
              existingRuns.any((r) =>
                  r.businessType.toLowerCase() == targetBiz &&
                  r.status.toLowerCase() != 'cancelled' &&
                  r.status.toLowerCase() != 'completed' &&
                  !r.slotEndDate.isBefore(slot.startDate) &&
                  !r.slotStartDate.isAfter(slot.endDate) &&
                  (r.placementSide.toLowerCase() == 'left' ||
                      r.placementSide.toLowerCase() == 'both'));
          resolvedPlacementSide = isLeftTaken ? 'right' : 'left';
        }

        CanonicalZones.startCompanyAdRun(
          CompanyAdDistributionRun(
            id: 'ad-run-${booking.id}-${slot.startDate.millisecondsSinceEpoch}',
            zoneId: widget.zone.id,
            companyId: widget.company.id,
            companyName: businessName,
            businessType: targetBiz,
            placementSide: resolvedPlacementSide,
            standSize: widget.adSize,
            slotStartDate: slot.startDate,
            slotEndDate: slot.endDate,
            startedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;

      // Show Clean Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          icon: const Icon(
            Icons.verified_rounded,
            color: colorTeal,
            size: 52,
          ),
          title: const Text(
            'Weekly Slots Booked Successfully!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your advertising space in "${widget.zone.name}" has been confirmed for $businessName.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Business Name: $businessName',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    Text('• Contact Phone: $phoneNumber',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1E293B))),
                    Text('• Zone: ${widget.zone.name}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1E293B))),
                    Text(
                        '• Placement: ${widget.adSize} (${widget.sideOption})',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1E293B))),
                    Text('• Total Locations: ${widget.eligibleCount} units',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1E293B))),
                    Text(
                        '• Campaign Duration: $_selectedWeeksCount Week(s) (7 Days each)',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorTeal)),
                    Text('• Reserved Dates: ${slotLabels.join(", ")}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF475569))),
                    const Divider(height: 16),
                    Text(
                      '• Total Paid: ${formatIndianCurrency(_totalAmount)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colorNavy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Cashfree Receipt Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Text(
                          'Payment Processed via Cashfree',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Payment ID: ${paymentResult.cfPaymentId}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      '• Order ID: ${paymentResult.orderId}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (paymentResult.referenceId != null)
                      Text(
                        '• Bank Ref (UTR): ${paymentResult.referenceId}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                          fontFamily: 'monospace',
                        ),
                      ),
                    Text(
                      '• Mode: ${paymentResult.paymentMethod.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/');
              },
              child: const Text('Back to Home'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorTeal,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/reports');
              },
              child: const Text('View Campaign Reports'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm booking: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = _monthGroups.isNotEmpty &&
            _activeMonthIndex < _monthGroups.length
        ? _monthGroups[_activeMonthIndex]
        : null;

    return Scaffold(
      backgroundColor: colorBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Select Campaign Slots',
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
      ),
      body: Stack(
        children: [
          // 1. VERTICAL SCROLLING LIST OF WEEKLY SLOTS
          Positioned.fill(
            bottom: 126, // space for sticky bottom bar
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    top: 64, // clearance for floating white month pill
                    left: 20,
                    right: 20,
                    bottom: 24,
                  ),
                  itemCount: _monthGroups.length,
                  itemBuilder: (context, groupIndex) {
                    final group = _monthGroups[groupIndex];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Month Divider Header matching: "------ OCTOBER 2026 ------"
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Divider(
                                    color: Color(0xFFE2E8F0),
                                    thickness: 1.2,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text(
                                    '${group.monthName} ${group.year}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                      color: colorNavy,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(
                                    color: Color(0xFFE2E8F0),
                                    thickness: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List of 7-day Monday-to-Sunday slots in this month
                          for (final slot in group.slots) ...[
                            WeekSlotButton(
                              slot: slot,
                              isSelected: _selectedSlots.containsKey(slot.id),
                              onTap: () => _toggleSlot(slot),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 2. FLOATING WHITE MONTH PILL AT TOP
          if (activeGroup != null)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '${activeGroup.monthName} ${activeGroup.year}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: colorNavy,
                    ),
                  ),
                ),
              ),
            ),

          // 3. STICKY BOTTOM BAR (MATCHING LIGHT SAAS THEME)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildLightBottomBar(context),
          ),
        ],
      ),
    );
  }

  /// Light SaaS Bottom Bar matching the Advertisement Space page theme:
  /// Left: "X weeks selected" + "₹80 per location · 5 locations"
  /// Right: "TOTAL" + "₹800"
  /// Bottom: "Confirm booking" button (Teal #0F9D8A when active)
  Widget _buildLightBottomBar(BuildContext context) {
    final hasSelection = _selectedWeeksCount > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Upper Summary Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: "X weeks selected" + No of shops per day Cost × Days
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_selectedWeeksCount ${_selectedWeeksCount == 1 ? 'week' : 'weeks'} selected',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colorNavy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _selectedWeeksCount > 0
                                  ? (_currentDesignAndPrintFee > 0
                                      ? '${widget.eligibleCount} ${widget.businessType} Per Day ${formatIndianCurrency(_dailyTotal)} × $_totalDays Days + ${formatIndianCurrency(_currentDesignAndPrintFee)} Design & Print'
                                      : '${widget.eligibleCount} ${widget.businessType} Per Day ${formatIndianCurrency(_dailyTotal)} × $_totalDays Days')
                                  : (_currentDesignAndPrintFee > 0
                                      ? '${widget.eligibleCount} ${widget.businessType} Per Day ${formatIndianCurrency(_dailyTotal)} + ${formatIndianCurrency(_currentDesignAndPrintFee)} Design & Print'
                                      : '${widget.eligibleCount} ${widget.businessType} Per Day ${formatIndianCurrency(_dailyTotal)}'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Right: TOTAL label + Total Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatIndianCurrency(_totalAmount),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: colorNavy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Full-width Confirm booking Button (Teal #0F9D8A when active, ALL CAPITAL)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasSelection
                            ? colorTeal
                            : const Color(0xFFE2E8F0),
                        foregroundColor: hasSelection
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: hasSelection && !_isSubmitting
                          ? _handleConfirmBooking
                          : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'CONFIRM BOOKING',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: hasSelection
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
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

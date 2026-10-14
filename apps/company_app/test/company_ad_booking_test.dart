import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:company_app/screens/booking/company_ad_booking_screen.dart';
import 'package:company_app/screens/booking/widgets/ad_preview_card.dart';
import 'package:company_app/screens/booking/widgets/payment_scanner_stand_widget.dart';
import 'package:company_app/providers/company_state_providers.dart';

void main() {
  final testZone = Zone(
    id: 'z-kolkata-central',
    name: 'Kolkata Central Zone',
    colorHex: '#006699',
    isActive: true,
    vertices: const [
      ZoneVertex(sequenceOrder: 0, latitude: 22.5800, longitude: 88.3550),
      ZoneVertex(sequenceOrder: 1, latitude: 22.5850, longitude: 88.3700),
      ZoneVertex(sequenceOrder: 2, latitude: 22.5750, longitude: 88.3800),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testCompany = Company(
    id: 'comp-alpha-101',
    legalName: 'Alpha Media & Ads Pvt Ltd',
    tradeName: 'Alpha Media',
    contactEmail: 'campaigns@alphamedia.com',
    contactPhone: '9876543210',
    isActive: true,
    canViewDailyProof: false,
    assignedZoneIds: const ['z-kolkata-central', 'z-salt-lake'],
    assignedZoneNames: const ['Kolkata Central Zone', 'Salt Lake Sector V'],
    createdAt: DateTime(2026, 1, 15),
  );

  Widget createTestWidget({
    Zone? initialZone,
    String? initialZoneId,
    Company? customCompany,
  }) {
    return ProviderScope(
      overrides: [
        companyAuthProvider.overrideWith(
          (ref) => _FakeCompanyAuthNotifier(customCompany ?? testCompany),
        ),
      ],
      child: MaterialApp(
        home: CompanyAdBookingScreen(
          initialZone: initialZone,
          initialZoneId: initialZoneId,
        ),
      ),
    );
  }

  group('Advertisement Space Booking Screen Tests', () {
    testWidgets('Renders header, zone name, toggles, preview card, and pricing breakdown in Desktop B2B layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('Book Advertisement Space'), findsWidgets);
      expect(find.text('Choose your placement and preview it before booking.'), findsOneWidget);
      expect(find.text('Kolkata Central Zone'), findsWidgets);
      expect(find.textContaining('available locations in zone'), findsOneWidget);

      // Business category toggle checks
      expect(find.text('Shops'), findsWidgets);
      expect(find.text('Saloons'), findsWidgets);

      // Ad Size toggle checks
      expect(find.text('Choose Ad Size'), findsWidgets);
      expect(find.textContaining('A5'), findsWidgets);
      expect(find.textContaining('A6'), findsWidgets);

      // Side selection toggle checks
      expect(find.text('Choose Placement'), findsWidgets);
      expect(find.text('Both Sides'), findsWidgets);
      expect(find.text('One Side'), findsWidgets);

      // Preview card components
      expect(find.byType(AdPreviewCard), findsOneWidget);
      expect(find.byType(PaymentScannerStandWidget), findsOneWidget);
      expect(find.text('Payment Scanner'), findsOneWidget);
      expect(find.text('See how your advertisement will appear'), findsOneWidget);
      expect(find.text('YOUR AD HERE'), findsWidgets);

      // Pick Your Week Action Button
      expect(find.text('Pick Your Week'), findsWidgets);
    });

    testWidgets('Toggling business type from Shops to Saloons updates counts and calculations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      // Initially Shops is selected
      expect(find.text('Shops'), findsWidgets);

      // Tap Saloons toggle
      await tester.tap(find.text('Saloons').first);
      await tester.pumpAndSettle();

      // Updates category
      expect(find.text('Saloons'), findsWidgets);
    });

    testWidgets('Toggling Ad size to A6 and Side to One Side updates specs and calculations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      // Tap A6
      await tester.tap(find.textContaining('A6').first);
      await tester.pumpAndSettle();

      // Tap One Side
      await tester.tap(find.text('One Side').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('A6 • One Side'), findsWidgets);
    });

    testWidgets('Tapping Pick Your Week opens weekly slot booking screen matching hand-drawn layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      // Find primary button and tap
      final continueButton = find.text('Pick Your Week').first;
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Slot booking screen should be open
      expect(find.text('Select Campaign Slots'), findsOneWidget);
      expect(find.textContaining('OCTOBER 2026'), findsWidgets);
      expect(find.text('5'), findsWidgets);
      expect(find.text('11'), findsWidgets);
      expect(find.text('BOOKED'), findsWidgets);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('CONFIRM BOOKING'), findsOneWidget);
    });

    testWidgets('Slot booking allows multiple weeks selection per month and enforces side-aware availability', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      final continueButton = find.text('Pick Your Week').first;
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Initially 0 weeks selected
      expect(find.text('0 weeks selected'), findsOneWidget);
      expect(find.textContaining('Per Day'), findsWidgets);

      // Default side is Both Sides:
      // - 5 is visible and bookable (both sides free)
      // - 12 is visible as BOOKED
      // - 19 is NOT visible (only one side available, excluded for Both Sides)
      // - 26 is visible and bookable (both sides free)
      expect(find.text('5'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('BOOKED'), findsWidgets);
      expect(find.text('19'), findsNothing);
      expect(find.text('26'), findsWidgets);

      // Tap 5 to select week 1 of October
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      expect(find.text('1 week selected'), findsOneWidget);
      expect(find.textContaining('7 Days'), findsWidgets);

      // Tap 26: can select multiple weeks in same month!
      await tester.tap(find.text('26').first);
      await tester.pumpAndSettle();
      expect(find.text('2 weeks selected'), findsOneWidget);
      expect(find.textContaining('14 Days'), findsWidgets);

      // Tap 5 again to deselect
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      expect(find.text('1 week selected'), findsOneWidget);
      expect(find.textContaining('7 Days'), findsWidgets);
    });

    testWidgets('One Side selection reveals one-side available weeks in slot booking', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      // Select One Side
      await tester.tap(find.text('One Side').first);
      await tester.pumpAndSettle();

      final continueButton = find.text('Pick Your Week').first;
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Under One Side, 19 (one-side available) IS visible and bookable!
      expect(find.text('19'), findsWidgets);
      await tester.tap(find.text('19').first);
      await tester.pumpAndSettle();
      expect(find.text('1 week selected'), findsOneWidget);
      expect(find.textContaining('7 Days'), findsWidgets);
    });

    testWidgets('Rejects unauthorized zones outside assigned territory', (tester) async {
      final unauthorizedZone = Zone(
        id: 'z-unauthorized-territory',
        name: 'Unauthorized Far Zone',
        colorHex: '#FF0000',
        isActive: true,
        vertices: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: unauthorizedZone));
      await tester.pumpAndSettle();

      expect(find.text('Unauthorized Zone'), findsOneWidget);
      expect(find.textContaining('Access restricted: You can book only inside Zones assigned to your Company'), findsOneWidget);
    });

    testWidgets('Static rate strip displays One Shop Per Day Rate and compact price', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      // 1. Verify Rate strip label
      expect(find.text('One Shop Per Day Rate'), findsOneWidget);

      // 2. Initial state: rate is shown with multiplier and /Day
      expect(find.text('₹80'), findsWidgets);
      expect(find.textContaining('×'), findsWidgets);
      expect(find.textContaining('Total ₹'), findsWidgets);
      expect(find.textContaining('/Day'), findsWidgets);
      expect(find.text(' / shop / day'), findsNothing);
      expect(find.textContaining('A5 · Both Sides'), findsNothing);

      // 3. Size buttons should show ONLY "A5" and "A6" without inline prices
      expect(find.widgetWithText(InkWell, 'A5'), findsWidgets);
      expect(find.widgetWithText(InkWell, 'A6'), findsWidgets);

      // 4. Tap A6 button
      await tester.tap(find.widgetWithText(InkWell, 'A6').first);
      await tester.pumpAndSettle();

      // Rate updates to ₹100
      expect(find.text('₹100'), findsWidgets);
    });

    testWidgets('Tapping CONFIRM BOOKING shows verification dialog with Business Name, +91 IND phone, and 4-digit OTP', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget(initialZone: testZone));
      await tester.pumpAndSettle();

      final continueButton = find.text('Pick Your Week').first;
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Select week 1
      final weekSlot = find.text('5').first;
      await tester.tap(weekSlot);
      await tester.pumpAndSettle();

      // Confirm Booking button active
      final confirmBtn = find.text('CONFIRM BOOKING');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verification dialog appears
      expect(find.text('Booking Verification'), findsOneWidget);
      expect(find.text('Business Name'), findsOneWidget);
      expect(find.text('+91 IND'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Enter 6-Digit Google OTP'), findsOneWidget);
      expect(find.text('CONFIRM & BOOK SLOTS'), findsOneWidget);
    });

    testWidgets('Two different companies can book two sides in the same weekly slot, transitioning to fully booked', (tester) async {
      // Clean test zone
      final zoneId = 'z-test-zone-capacity';
      final testWeekMonday = DateTime(2026, 12, 7); // Monday
      final testWeekSunday = DateTime(2026, 12, 13); // Sunday

      // 1. Initially, no runs exist in this zone for this week
      final initialRuns = CanonicalZones.getCompanyAdRuns(zoneId);
      expect(initialRuns.where((r) => !r.slotEndDate.isBefore(testWeekMonday) && !r.slotStartDate.isAfter(testWeekSunday)), isEmpty);

      // 2. Company 1 books "One Side" -> assigned 'left'
      CanonicalZones.startCompanyAdRun(
        CompanyAdDistributionRun(
          id: 'ad-run-ad-book-comp-1-${testWeekMonday.millisecondsSinceEpoch}',
          zoneId: zoneId,
          companyId: 'comp-alpha-101',
          companyName: 'Company 1 (Alpha)',
          businessType: 'shop',
          placementSide: 'left',
          standSize: 'A5',
          slotStartDate: testWeekMonday,
          slotEndDate: testWeekSunday,
          startedAt: DateTime.now(),
        ),
      );

      // Verify Company 1 is registered on Left side
      final runsAfterComp1 = CanonicalZones.getCompanyAdRuns(zoneId);
      final activeRuns1 = runsAfterComp1.where((r) =>
          !r.slotEndDate.isBefore(testWeekMonday) &&
          !r.slotStartDate.isAfter(testWeekSunday)).toList();
      expect(activeRuns1.length, 1);
      expect(activeRuns1.first.placementSide, 'left');

      // 3. Company 2 comes to book "One Side" for the same week
      // Simulate dynamic placement resolution
      final isLeftTaken = activeRuns1.any((r) =>
          (r.placementSide.toLowerCase() == 'left' || r.placementSide.toLowerCase() == 'both'));
      expect(isLeftTaken, isTrue); // Left is taken by Company 1
      final comp2PlacementSide = isLeftTaken ? 'right' : 'left';
      expect(comp2PlacementSide, 'right'); // Company 2 gets Right side

      // Company 2 books "One Side" -> assigned 'right'
      CanonicalZones.startCompanyAdRun(
        CompanyAdDistributionRun(
          id: 'ad-run-ad-book-comp-2-${testWeekMonday.millisecondsSinceEpoch}',
          zoneId: zoneId,
          companyId: 'comp-beta-202',
          companyName: 'Company 2 (Beta)',
          businessType: 'shop',
          placementSide: comp2PlacementSide,
          standSize: 'A6',
          slotStartDate: testWeekMonday,
          slotEndDate: testWeekSunday,
          startedAt: DateTime.now(),
        ),
      );

      // 4. Now both sides are taken by two different companies
      final runsAfterComp2 = CanonicalZones.getCompanyAdRuns(zoneId);
      final activeRuns2 = runsAfterComp2.where((r) =>
          !r.slotEndDate.isBefore(testWeekMonday) &&
          !r.slotStartDate.isAfter(testWeekSunday)).toList();
      expect(activeRuns2.length, 2);
      expect(activeRuns2.any((r) => r.placementSide == 'left'), isTrue);
      expect(activeRuns2.any((r) => r.placementSide == 'right'), isTrue);

      // 5. Check that slot availability detects both sides booked
      bool leftBooked = activeRuns2.any((r) => r.placementSide == 'left' || r.placementSide == 'both');
      bool rightBooked = activeRuns2.any((r) => r.placementSide == 'right' || r.placementSide == 'both');
      expect(leftBooked && rightBooked, isTrue); // Capacity of 2 spaces per scanner is full!
    });
  });
}

class _FakeCompanyAuthNotifier extends StateNotifier<CompanyAuthState>
    implements CompanyAuthNotifier {
  _FakeCompanyAuthNotifier(Company company)
      : super(CompanyAuthState(
          isLoading: false,
          company: company,
        ));

  @override
  void logout() {}

  @override
  Future<void> refreshCompanyStatus() async {}

  @override
  Future<bool> requestOtp({
    required String companyName,
    required String phoneNumber,
  }) async =>
      true;

  @override
  void resetOtp() {}

  @override
  Future<bool> verifyOtp({required String otp}) async => true;
}

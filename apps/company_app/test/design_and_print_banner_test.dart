import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:company_app/screens/booking/widgets/design_and_print_banner.dart';
import 'package:company_app/screens/booking/company_ad_booking_screen.dart';
import 'package:company_app/screens/booking/company_slot_booking_screen.dart';
import 'package:company_app/providers/company_state_providers.dart';
import 'package:company_app/utils/currency_formatter.dart';

void main() {
  group('Currency Formatter Tests', () {
    test('Correctly formats numbers using Indian numbering system and ₹ symbol', () {
      expect(formatIndianCurrency(0), '₹0');
      expect(formatIndianCurrency(80), '₹80');
      expect(formatIndianCurrency(500), '₹500');
      expect(formatIndianCurrency(5000), '₹5,000');
      expect(formatIndianCurrency(10000), '₹10,000');
      expect(formatIndianCurrency(50000), '₹50,000');
      expect(formatIndianCurrency(100000), '₹1,00,000');
      expect(formatIndianCurrency(1234567), '₹12,34,567');
    });
  });

  group('DesignAndPrintBanner Widget Tests', () {
    testWidgets('Renders State 1 when A6 is selected (One Side = ₹5,000)', (tester) async {
      bool switchedToA5 = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DesignAndPrintBanner(
                adSize: 'A6',
                sideOption: 'One Side',
                onSwitchToA5: () => switchedToA5 = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // State 1 elements
      expect(find.text('Add Design & Print: '), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
      expect(find.text('Switch to A5 and save ₹5,000'), findsOneWidget);
      expect(find.text('FREE'), findsNothing);
      expect(find.text('You saved ₹5,000 with A5'), findsNothing);

      // Verify tap on "Switch to A5 and save ₹5,000" triggers callback
      await tester.tap(find.text('Switch to A5 and save ₹5,000'));
      expect(switchedToA5, isTrue);
    });

    testWidgets('Renders State 1 when A6 is selected (Both Sides = ₹10,000)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: DesignAndPrintBanner(
                adSize: 'A6',
                sideOption: 'Both Sides',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both Sides shows ₹10,000
      expect(find.text('Add Design & Print: '), findsOneWidget);
      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.text('Switch to A5 and save ₹10,000'), findsOneWidget);
      expect(find.text('FREE'), findsNothing);
    });

    testWidgets('Renders State 2 when A5 is selected (Both Sides = ₹10,000 struck through, FREE)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: DesignAndPrintBanner(
                adSize: 'A5',
                sideOption: 'Both Sides',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Pump past 400ms strikethrough and 250ms badge animations
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // State 2 elements
      expect(find.text('Add Design & Print: '), findsOneWidget);
      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('You saved ₹10,000 with A5'), findsOneWidget);
      expect(find.text('Switch to A5 and save ₹10,000'), findsNothing);
    });

    testWidgets('Toggling placement animates number from ₹5,000 to ₹10,000', (tester) async {
      String currentPlacement = 'One Side';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    DesignAndPrintBanner(
                      adSize: 'A6',
                      sideOption: currentPlacement,
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => currentPlacement = 'Both Sides'),
                      child: const Text('Toggle Placement'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹5,000'), findsOneWidget);

      // Trigger placement toggle
      await tester.tap(find.text('Toggle Placement'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.text('Switch to A5 and save ₹10,000'), findsOneWidget);
    });

    testWidgets('Toggling between A6 and A5 transitions states properly', (tester) async {
      String currentSize = 'A6';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: DesignAndPrintBanner(
                  adSize: currentSize,
                  sideOption: 'One Side',
                  onSwitchToA5: () {
                    setState(() => currentSize = 'A5');
                  },
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Starts at A6
      expect(find.text('Switch to A5 and save ₹5,000'), findsOneWidget);
      expect(find.text('FREE'), findsNothing);

      // Tap link to switch to A5
      await tester.tap(find.text('Switch to A5 and save ₹5,000'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Now A5
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('You saved ₹5,000 with A5'), findsOneWidget);
      expect(find.text('Switch to A5 and save ₹5,000'), findsNothing);
    });

    testWidgets('Dynamically updates price when oneSideAmount changes in real time', (tester) async {
      double currentOneSide = 5000.0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    DesignAndPrintBanner(
                      adSize: 'A5',
                      sideOption: 'One Side',
                      oneSideAmount: currentOneSide,
                      bothSidesAmount: 5000.0,
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => currentOneSide = 3000.0),
                      child: const Text('Update Fee'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹5,000'), findsOneWidget);

      await tester.tap(find.text('Update Fee'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('₹3,000'), findsOneWidget);
      expect(find.text('You saved ₹3,000 with A5'), findsOneWidget);
    });
  });

  group('Ad Booking Screen with Design & Print Pricing Tests', () {
    final testZone = Zone(
      id: 'z-kolkata-central',
      name: 'Kolkata Central Zone',
      colorHex: '#006699',
      isActive: true,
      vertices: const [
        ZoneVertex(sequenceOrder: 0, latitude: 22.5800, longitude: 88.3550),
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
      assignedZoneIds: const ['z-kolkata-central'],
      assignedZoneNames: const ['Kolkata Central Zone'],
      createdAt: DateTime(2026, 1, 15),
    );

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          companyAuthProvider.overrideWith(
            (ref) => _FakeCompanyAuthNotifier(testCompany),
          ),
        ],
        child: MaterialApp(
          home: CompanyAdBookingScreen(
            initialZone: testZone,
          ),
        ),
      );
    }

    testWidgets('Tapping Pick Your Week opens slot booking with Design & Print pricing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially A5 is selected
      expect(find.byType(DesignAndPrintBanner), findsOneWidget);
      expect(find.text('Pick Your Week'), findsWidgets);

      // Select A6 (starts on Both Sides)
      await tester.tap(find.textContaining('A6').first);
      await tester.pumpAndSettle();

      // Tap Pick Your Week
      final pickButton = find.text('Pick Your Week').first;
      await tester.ensureVisible(pickButton);
      await tester.tap(pickButton);
      await tester.pumpAndSettle();

      // Opens week selection page
      expect(find.text('Select Campaign Slots'), findsOneWidget);
    });
  });

  group('Slot Booking One-Time Fee Tests', () {
    final testZone = Zone(
      id: 'z-kolkata-central',
      name: 'Kolkata Central Zone',
      colorHex: '#006699',
      isActive: true,
      vertices: const [],
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
      assignedZoneIds: const ['z-kolkata-central'],
      assignedZoneNames: const ['Kolkata Central Zone'],
      createdAt: DateTime(2026, 1, 15),
    );

    testWidgets('CompanySlotBookingScreen adds ₹10,000 one-time fee only once across weeks for A6 + Both Sides', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CompanySlotBookingScreen(
              company: testCompany,
              zone: testZone,
              businessType: 'Shops',
              adSize: 'A6',
              sideOption: 'Both Sides',
              pricePerLocation: 100.0,
              eligibleCount: 5,
              baseWeeklyTotal: 500.0,
              designAndPrintFee: 10000.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 0 weeks selected initially -> total is ₹0
      expect(find.text('0 weeks selected'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);

      // Select week 1 (5th Oct) -> (500 * 7 = 3500) + 10000 = 13500
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      expect(find.text('1 week selected'), findsOneWidget);
      expect(find.text('₹13,500'), findsOneWidget);

      // Select another week in another month (2nd Nov) -> 2 weeks = (500 * 14 = 7000) + 10000 = 17000
      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();
      expect(find.text('2 weeks selected'), findsOneWidget);
      expect(find.text('₹17,000'), findsOneWidget);
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

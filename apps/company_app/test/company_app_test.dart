import 'package:app_core/app_core.dart';
import 'package:company_app/providers/company_state_providers.dart';
import 'package:company_app/screens/login/company_login_screen.dart';
import 'package:company_app/screens/map/company_zones_map_screen.dart';
import 'package:company_app/screens/reports/company_reporting_screen.dart';
import 'package:company_app/screens/shops/company_shop_detail_modal.dart';
import 'package:company_app/screens/shops/company_shops_list_screen.dart';
import 'package:company_app/screens/zones/company_zone_summary_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = AppConfig(
    environment: AppEnvironment.dev,
    appName: 'ShopAd Company Test',
    supabaseUrl: '',
    supabaseAnonKey: '',
    googleMapsApiKey: '',
    apiBaseUrl: 'https://api.test',
  );

  Widget createTestWidget({
    required Widget child,
    List<dynamic>? overrides,
  }) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        currentAppRoleProvider.overrideWithValue(UserRole.company),
        ...?overrides?.cast(),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Company Login & Pending Approval Screen Tests', () {
    testWidgets('Company onboarding renders name, phone, and test account quick-fills', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CompanyLoginScreen(),
        overrides: [
          companyAuthProvider.overrideWith((ref) => _StaticAuthNotifier(const CompanyAuthState())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ShopAd Company Portal'), findsOneWidget);
      expect(find.text('Company / Advertiser Name'), findsOneWidget);
      expect(find.text('Registered Phone Number'), findsOneWidget);
      expect(find.text('Send Verification OTP'), findsOneWidget);
      expect(find.text('Approved (2 Zones)'), findsOneWidget);
      expect(find.text('Pending (0 Zones)'), findsOneWidget);
    });

    testWidgets('Company with 0 assigned zones renders Pending Master Admin Approval screen', (tester) async {
      final fakePendingCompany = Company(
        id: 'comp-beta-pending',
        legalName: 'Beta Outdoor Promotions LLP',
        tradeName: 'Beta Outdoor',
        contactEmail: 'contact@betaoutdoor.com',
        contactPhone: '9876543211',
        isActive: true,
        canViewDailyProof: false,
        assignedZoneIds: const [], // Zero zones
        assignedZoneNames: const [],
        createdAt: DateTime(2026, 9, 20),
      );

      final state = CompanyAuthState(
        company: fakePendingCompany,
      );

      await tester.pumpWidget(createTestWidget(
        child: const CompanyLoginScreen(),
        overrides: [
          companyAuthProvider.overrideWith((ref) => _StaticAuthNotifier(state)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pending Master Admin Approval'), findsOneWidget);
      expect(find.text('0 Assigned Zones'), findsOneWidget);
      expect(find.textContaining('A Company gains access only after Master Admin assigns one or more Zones'), findsOneWidget);
      expect(find.textContaining('A Company cannot select or grant itself Zone access'), findsOneWidget);
      expect(find.text('Check Zone Assignment Status'), findsOneWidget);
    });
  });

  group('Company Read-Only Territory Map Tests', () {
    testWidgets('Renders read-only assigned territory map and legend', (tester) async {
      final mockApprovedCompany = Company(
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

      await tester.pumpWidget(createTestWidget(
        child: const CompanyZonesMapScreen(),
        overrides: [
          companyAuthProvider.overrideWith(
            (ref) => _StaticAuthNotifier(CompanyAuthState(company: mockApprovedCompany)),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Active Zone'), findsOneWidget);
      expect(find.textContaining('10 Oct – 16 Oct'), findsWidgets);
      expect(find.text('Booking History'), findsOneWidget);
      expect(find.textContaining('Agreed Partner Shops'), findsOneWidget);
    });
  });

  group('Company Agreed & Active Shops Screen Tests', () {
    testWidgets('Renders active agreed shops and filters, strictly excluding sensitive internal data', (tester) async {
      final mockApprovedCompany = Company(
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

      await tester.pumpWidget(createTestWidget(
        child: const CompanyShopsListScreen(),
        overrides: [
          companyAuthProvider.overrideWith(
            (ref) => _StaticAuthNotifier(CompanyAuthState(company: mockApprovedCompany)),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Check title and categories
      expect(find.text('Advertising Locations (Shops)'), findsOneWidget);
      expect(find.text('Fast Food'), findsWidgets);
      expect(find.text('Bakery'), findsWidgets);
      expect(find.text('Pharmacy'), findsWidgets);

      // Verify privacy rules: strictly no employee, Aadhaar, payment controls, or lead data
      expect(find.text('Aadhaar'), findsNothing);
      expect(find.text('Employee ID'), findsNothing);
      expect(find.text('Accept Payment'), findsNothing);
      expect(find.text('Payment Done'), findsNothing);
      expect(find.text('Lead'), findsNothing);
      expect(find.text('Follow-up'), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('Company shop detail modal renders category icon and basic info only', (tester) async {
      final testShop = CompanyVisibleShop(
        id: 'shop-c101',
        shopCode: '10000001',
        zoneId: 'z-kolkata-central',
        zoneName: 'Kolkata Central Zone',
        shopName: 'Maa Tara Electronic Hub',
        category: 'Fast Food',
        address: '42 Central Avenue, Kolkata',
        latitude: 22.5720,
        longitude: 88.3620,
        screenCount: 2,
        status: 'active',
        agreedAt: DateTime(2026, 4, 1),
        createdAt: DateTime(2026, 3, 15),
        hasTodayProof: null,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CompanyShopDetailModal(
            shop: testShop,
            canViewDailyProof: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Maa Tara Electronic Hub'), findsOneWidget);
      expect(find.text('Code: 10000001'), findsOneWidget);
      expect(find.text('2 Screens'), findsOneWidget);
      expect(find.text('Kolkata Central Zone'), findsOneWidget);
      expect(find.text('Agreed & Active'), findsOneWidget);
      expect(find.text('Daily Proof Status (Hidden)'), findsOneWidget);
      expect(find.textContaining('Sensitive employee & identity records are excluded by RLS'), findsOneWidget);
    });
  });

  group('Company Zone Summary Screen Tests', () {
    testWidgets('Renders zone summaries, screen counts, and category breakdown', (tester) async {
      final mockApprovedCompany = Company(
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

      await tester.pumpWidget(createTestWidget(
        child: const CompanyZoneSummaryScreen(),
        overrides: [
          companyAuthProvider.overrideWith(
            (ref) => _StaticAuthNotifier(CompanyAuthState(company: mockApprovedCompany)),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Zone Advertising Summary'), findsOneWidget);
      expect(find.text('Assigned Zones'), findsOneWidget);
      expect(find.text('Active Agreed Shops'), findsOneWidget);
      expect(find.text('Total Advertising Screens'), findsOneWidget);
      expect(find.text('Assigned Zone Breakdown & Category Counts'), findsOneWidget);
    });
  });

  group('Company Reporting Screen Tests', () {
    testWidgets('Renders campaign report table, category reach, and RLS privacy compliance', (tester) async {
      final mockApprovedCompany = Company(
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

      await tester.pumpWidget(createTestWidget(
        child: const CompanyReportingScreen(),
        overrides: [
          companyAuthProvider.overrideWith(
            (ref) => _StaticAuthNotifier(CompanyAuthState(company: mockApprovedCompany)),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Advertising Campaign Reports'), findsOneWidget);
      expect(find.text('1. Zone-by-Zone Advertising Distribution'), findsOneWidget);
      expect(find.text('2. Network Category Penetration'), findsOneWidget);
      expect(find.text('RLS Privacy & Data Protection Compliance'), findsOneWidget);
      expect(find.textContaining('This report is generated strictly from the company_visible_shops database view enforced by Supabase Row-Level Security'), findsOneWidget);
    });
  });
}

class _StaticAuthNotifier extends StateNotifier<CompanyAuthState>
    implements CompanyAuthNotifier {
  _StaticAuthNotifier(super.initialState);

  @override
  void logout() {
    state = const CompanyAuthState();
  }

  @override
  Future<void> refreshCompanyStatus() async {}

  @override
  Future<bool> requestOtp({required String companyName, required String phoneNumber}) async => true;

  @override
  void resetOtp() {}

  @override
  Future<bool> verifyOtp({required String otp}) async => true;
}

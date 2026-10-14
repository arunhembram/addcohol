import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SupabaseCompanyRepository repo;

  setUp(() {
    repo = SupabaseCompanyRepository();
  });

  group('Company Onboarding & Verification Tests', () {
    test('requestCompanyOtp validates required fields', () async {
      expect(
        () => repo.requestCompanyOtp(companyName: '', phoneNumber: '9876543210'),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => repo.requestCompanyOtp(companyName: 'Acme Corp', phoneNumber: '1234'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('verifyCompanyOtp validates OTP format and correctness', () async {
      expect(
        () => repo.verifyCompanyOtp(phoneNumber: '9876543210', otp: '12'),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => repo.verifyCompanyOtp(phoneNumber: '9876543210', otp: '000000'),
        throwsA(isA<AuthException>()),
      );

      final verified = await repo.verifyCompanyOtp(phoneNumber: '9876543210', otp: '123456');
      expect(verified.tradeName, anyOf('Alpha Media', 'Britannia'));
      expect(verified.hasAssignedZones, isTrue);
    });
  });

  group('Company Zone Access Control & RLS Tests', () {
    test('Pending approval company with 0 assigned zones returns empty zones and shops', () async {
      final pendingCompany = await repo.verifyCompanyOtp(phoneNumber: '9876543211', otp: '123456');
      expect(pendingCompany.id, 'comp-beta-pending');
      expect(pendingCompany.hasAssignedZones, isFalse);

      final zones = await repo.getAssignedZones(pendingCompany.id);
      expect(zones, isEmpty);

      final shops = await repo.getAssignedShops(companyId: pendingCompany.id);
      expect(shops, isEmpty);
    });

    test('Company can ONLY query assigned zones, cannot query another company zone', () async {
      final zones = await repo.getAssignedZones('comp-alpha-101');
      expect(zones.length, 2);
      expect(zones.map((z) => z.id), containsAll(['z-kolkata-central', 'z-salt-lake']));
      expect(zones.any((z) => z.id == 'z-howrah-industrial'), isFalse);
    });

    test('Company can ONLY query agreed & active shops inside assigned zones', () async {
      final shops = await repo.getAssignedShops(companyId: 'comp-alpha-101');
      expect(shops.isNotEmpty, isTrue);
      // Verify shops belong only to assigned zones
      for (final shop in shops) {
        expect(['z-kolkata-central', 'z-salt-lake'].contains(shop.zoneId), isTrue);
        expect(shop.status, 'active');
      }
      // Verify shop in unassigned zone 'z-howrah-industrial' is never returned
      expect(shops.any((s) => s.id == 'shop-c999'), isFalse);
    });

    test('getZoneSummary for unassigned zone throws Access Denied AuthException', () async {
      expect(
        () => repo.getZoneSummary(companyId: 'comp-alpha-101', zoneId: 'z-howrah-industrial'),
        throwsA(isA<AuthException>()),
      );
    });

    test('can_view_daily_proof feature flag keeps daily proof hidden by default', () async {
      // By default comp-alpha-101 has canViewDailyProof = false
      final shops = await repo.getAssignedShops(companyId: 'comp-alpha-101');
      for (final shop in shops) {
        expect(shop.hasTodayProof, isNull);
      }

      final summary = await repo.getZoneSummary(
        companyId: 'comp-alpha-101',
        zoneId: 'z-kolkata-central',
      );
      expect(summary.proofVerifiedCount, isNull);
    });
  });
}

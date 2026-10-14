import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Employee Repository Unit Tests', () {
    late IEmployeeRepository repo;

    setUp(() {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        appName: 'Employee Test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleMapsApiKey: '',
        apiBaseUrl: '',
      );
      final supabaseManager = SupabaseManager(config: config);
      repo = SupabaseEmployeeRepository(supabaseManager: supabaseManager);
    });

    test('Step 1: verifyEmployeeId checks valid 5-digit employee ID', () async {
      final validEmp = await repo.verifyEmployeeId('20001');
      expect(validEmp, isNotNull);
      expect(validEmp!.displayId, '20001');
      expect(validEmp.fullName, 'Rahul Das');

      expect(
        () => repo.verifyEmployeeId('99999'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sendEmployeeOtp dispatches OTP to registered phone', () async {
      final phone = await repo.sendEmployeeOtp('20001');
      expect(phone, contains('98111 22334'));
    });

    test('Step 2: Rejects login with ID alone (empty verification code)', () async {
      expect(
        () => repo.verifyOtpOrPin(
          displayId: '20001',
          verificationCode: '',
          isPin: false,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('Step 2: Successfully verifies valid OTP or PIN', () async {
      final profileOtp = await repo.verifyOtpOrPin(
        displayId: '20001',
        verificationCode: '123456',
        isPin: false,
      );
      expect(profileOtp.id, 'emp-20001');

      final profilePin = await repo.verifyOtpOrPin(
        displayId: '20001',
        verificationCode: '1234',
        isPin: true,
      );
      expect(profilePin.id, 'emp-20001');
    });

    test('Rejects invalid OTP or PIN', () async {
      expect(
        () => repo.verifyOtpOrPin(
          displayId: '20001',
          verificationCode: '000000',
          isPin: false,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('Assigned Zones: Returns only the zones assigned to employee', () async {
      final zones = await repo.getAssignedZones('emp-20001');
      expect(zones, isNotEmpty);
      expect(zones.length, 2);
      expect(zones.map((z) => z.id), containsAll(['z-kolkata-central', 'z-saltlake-sector5']));

      final ananyaZones = await repo.getAssignedZones('emp-20002');
      expect(ananyaZones.length, 2);
    });

    test('Point-in-polygon containment test', () async {
      // Point inside Kolkata Central polygon
      final insideZone = await repo.findAssignedZoneForPoint(
        employeeId: 'emp-20001',
        latitude: 22.5726,
        longitude: 88.3639,
      );
      expect(insideZone, isNotNull);
      expect(insideZone!.id, 'z-kolkata-central');

      // Point far away (outside assigned zones)
      final outsideZone = await repo.findAssignedZoneForPoint(
        employeeId: 'emp-20001',
        latitude: 19.0760, // Mumbai
        longitude: 72.8777,
      );
      expect(outsideZone, isNull);
    });

    test('Rejects adding shop outside assigned zones', () async {
      expect(
        () => repo.addShop(
          employeeId: 'emp-20001',
          ownerName: 'External Owner',
          phoneNumber: '9123456780',
          shopName: 'Out of Zone Shop',
          category: 'Grocery',
          latitude: 19.0760, // Mumbai
          longitude: 72.8777,
          openingTime: '09:00 AM',
          closingTime: '09:00 PM',
          weeklyClosedDay: 'Sunday',
          isAgreed: true,
        ),
        throwsA(isA<ForbiddenZoneException>()),
      );
    });

    test('Agreed shop creates server-generated immutable 8-digit shop code', () async {
      final newShop = await repo.addShop(
        employeeId: 'emp-20001',
        ownerName: 'Tapan Ghosh',
        phoneNumber: '9830099881',
        shopName: 'Ghosh Sweets',
        category: 'Bakery',
        latitude: 22.5726,
        longitude: 88.3639,
        openingTime: '08:00 AM',
        closingTime: '10:00 PM',
        weeklyClosedDay: 'None',
        isAgreed: true,
      );

      expect(newShop.shopCode, isNotNull);
      expect(newShop.shopCode!.length, 8);
      expect(int.tryParse(newShop.shopCode!), isNotNull);
      expect(newShop.status, 'under_process');
      expect(newShop.isAgreed, isTrue);
    });

    test('Follow-up shop requires reason and scheduled date, without shop code until agreed', () async {
      final followupShop = await repo.addShop(
        employeeId: 'emp-20001',
        ownerName: 'Bimal Sen',
        phoneNumber: '9830099882',
        shopName: 'Sen Electronics',
        category: 'Other',
        latitude: 22.5726,
        longitude: 88.3639,
        openingTime: '10:00 AM',
        closingTime: '08:00 PM',
        weeklyClosedDay: 'Sunday',
        isAgreed: false,
        followupReason: 'Owner busy with inventory, visit tomorrow 4pm',
        nextFollowupDate: DateTime.now().add(const Duration(days: 1)),
      );

      expect(followupShop.shopCode, isNull);
      expect(followupShop.status, 'follow_up');
      expect(followupShop.isFollowup, isTrue);
      expect(followupShop.followupReason, contains('Owner busy'));

      // Convert Follow-up to Agreed -> generates 8-digit shop code!
      final convertedShop = await repo.updateFollowupToAgreed(
        employeeId: 'emp-20001',
        shopId: followupShop.id,
      );
      expect(convertedShop.status, 'active');
      expect(convertedShop.isAgreed, isTrue);
      expect(convertedShop.shopCode, isNotNull);
      expect(convertedShop.shopCode!.length, 8);
    });

    test('Duplicate phone warning check', () async {
      // Existing phone number in mock data is '9876500001'
      final isDup = await repo.isPhoneNumberDuplicate(
        employeeId: 'emp-20001',
        phoneNumber: '9876500001',
      );
      expect(isDup, isTrue);

      final isUnique = await repo.isPhoneNumberDuplicate(
        employeeId: 'emp-20001',
        phoneNumber: '9999900000',
      );
      expect(isUnique, isFalse);
    });

    test('Nearby duplicate shop warning check (<20m)', () async {
      // Near existing shop (lat: 22.5720, lng: 88.3620)
      final duplicates = await repo.getNearbyDuplicateShops(
        employeeId: 'emp-20001',
        latitude: 22.57201, // ~1-2 meters away
        longitude: 88.36201,
        thresholdMeters: 20.0,
      );
      expect(duplicates, isNotEmpty);

      // Far away (e.g. 500m away)
      final noDuplicates = await repo.getNearbyDuplicateShops(
        employeeId: 'emp-20001',
        latitude: 22.5850,
        longitude: 88.3800,
        thresholdMeters: 20.0,
      );
      expect(noDuplicates, isEmpty);
    });

    test('Offline draft storage and retrieval', () async {
      final draft = {
        'id': 'draft-test-1',
        'shop_name': 'Offline Tea Stall',
        'category': 'Tea Stall',
      };
      await repo.saveOfflineDraft(draft);

      final drafts = await repo.getOfflineDrafts();
      expect(drafts.any((d) => d['id'] == 'draft-test-1'), isTrue);

      await repo.deleteOfflineDraft('draft-test-1');
      final updatedDrafts = await repo.getOfflineDrafts();
      expect(updatedDrafts.any((d) => d['id'] == 'draft-test-1'), isFalse);
    });
  });
}

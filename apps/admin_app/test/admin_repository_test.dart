import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SupabaseAdminRepository repository;

  setUp(() {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Admin Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: '',
    );
    final supabaseManager = SupabaseManager(config: config);
    repository = SupabaseAdminRepository(supabaseManager: supabaseManager);
  });

  group('Admin Login Flow Tests', () {
    test('Admin ID verification succeeds for active 5-digit admin', () async {
      final admin = await repository.verifyAdminId('10001');
      expect(admin, isNotNull);
      expect(admin!.fullName, 'Subhasis Sen');
      expect(admin.displayId, '10001');
      expect(admin.role, UserRole.admin);
    });

    test('Admin ID verification rejects invalid format or non-existent ID', () async {
      expect(
        () => repository.verifyAdminId('123'),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => repository.verifyAdminId('99999'),
        throwsA(isA<AuthException>()),
      );
    });

    test('STRICT RULE: Never allow login with ID alone without OTP or PIN', () async {
      // Submitting empty verification code must be rejected with AuthException
      expect(
        () => repository.verifyOtpOrPin(
          displayId: '10001',
          verificationCode: '',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Login with Admin ID alone is prohibited'),
          ),
        ),
      );

      expect(
        () => repository.verifyOtpOrPin(
          displayId: '10001',
          verificationCode: '   ',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('Valid OTP (123456) or PIN (1234) completes login', () async {
      final otpAdmin = await repository.verifyOtpOrPin(
        displayId: '10001',
        verificationCode: '123456',
        isPin: false,
      );
      expect(otpAdmin.displayId, '10001');

      final pinAdmin = await repository.verifyOtpOrPin(
        displayId: '10001',
        verificationCode: '1234',
        isPin: true,
      );
      expect(pinAdmin.displayId, '10001');
    });
  });

  group('Controlled Zone Jurisdiction & Forbidden-Zone Defense Tests', () {
    test('Admin can fetch only zones assigned to their jurisdiction', () async {
      // Admin 10001 controls 'z-kolkata-central' and 'z-saltlake-sector5'
      final zones = await repository.getControlledZones('admin-10001');
      expect(zones.length, 2);
      final zoneIds = zones.map((z) => z.id).toSet();
      expect(zoneIds, contains('z-kolkata-central'));
      expect(zoneIds, contains('z-saltlake-sector5'));
      expect(zoneIds, isNot(contains('z-howrah-industrial')));
    });

    test('Fetching forbidden zone throws ForbiddenZoneException', () async {
      // Admin 10001 attempting to fetch Howrah zone (assigned to 10002)
      expect(
        () => repository.getControlledZoneById(
          adminId: 'admin-10001',
          zoneId: 'z-howrah-industrial',
        ),
        throwsA(
          isA<ForbiddenZoneException>().having(
            (e) => e.zoneId,
            'zoneId',
            'z-howrah-industrial',
          ),
        ),
      );
    });

    test('Admin cannot create employee assigned to a forbidden zone', () async {
      expect(
        () => repository.createEmployee(
          adminId: 'admin-10001',
          fullName: 'Test Employee',
          phoneNumber: '9876543210',
          email: 'test.emp@shopad.local',
          aadhaarDocumentPath: 'secure-identity-docs/path.jpg',
          consentGiven: true,
          isActive: true,
          initialZoneIds: ['z-kolkata-central', 'z-howrah-industrial'], // Forbidden zone!
        ),
        throwsA(
          isA<ForbiddenZoneException>().having(
            (e) => e.message,
            'message',
            contains('Security violation: Cannot assign employee to zone "z-howrah-industrial"'),
          ),
        ),
      );
    });

    test('Creating employee without explicit consent is rejected', () async {
      expect(
        () => repository.createEmployee(
          adminId: 'admin-10001',
          fullName: 'No Consent Employee',
          phoneNumber: '9876543210',
          email: 'noconsent@shopad.local',
          aadhaarDocumentPath: 'secure-identity-docs/path.jpg',
          consentGiven: false,
          isActive: true,
          initialZoneIds: ['z-kolkata-central'],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Admin cannot assign employee to a forbidden zone', () async {
      expect(
        () => repository.assignEmployeeToZones(
          adminId: 'admin-10001',
          employeeId: 'emp-20001',
          zoneIds: ['z-howrah-industrial'], // Forbidden zone!
        ),
        throwsA(isA<ForbiddenZoneException>()),
      );
    });

    test('Admin cannot edit an employee outside their controlled jurisdiction', () async {
      // emp-20099 is in Howrah (controlled by Admin 10002, NOT 10001)
      expect(
        () => repository.updateEmployeeStatus(
          adminId: 'admin-10001',
          employeeId: 'emp-20099',
          isActive: false,
        ),
        throwsA(isA<ForbiddenZoneException>()),
      );
    });

    test('Admin cannot assign zones to an employee outside their jurisdiction', () async {
      expect(
        () => repository.assignEmployeeToZones(
          adminId: 'admin-10001',
          employeeId: 'emp-20099',
          zoneIds: ['z-kolkata-central'],
        ),
        throwsA(isA<ForbiddenZoneException>()),
      );
    });

    test('Shops overview retrieves only shops within controlled zones', () async {
      final shops = await repository.getShopsInControlledZones('admin-10001');
      expect(shops, isNotEmpty);
      for (final shop in shops) {
        expect(
          ['z-kolkata-central', 'z-saltlake-sector5'].contains(shop.zoneId),
          isTrue,
        );
        expect(shop.zoneId, isNot('z-howrah-industrial'));
      }
    });
  });
}

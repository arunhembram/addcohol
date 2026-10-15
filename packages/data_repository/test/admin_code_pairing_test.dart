import 'package:flutter_test/flutter_test.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';

void main() {
  group('Admin Code Creation & Sign Up Pairing Tests', () {
    test('1. Create unclaimed admin code and verify initial empty name state', () {
      final codeAdmin = CanonicalZones.createAdminCode(syncRemote: false);
      expect(codeAdmin.displayId, isNotNull);
      expect(codeAdmin.displayId!.length, equals(5));
      expect(codeAdmin.fullName, isEmpty);
      expect(codeAdmin.role, equals(UserRole.admin));
      expect(codeAdmin.isActive, isTrue);

      final admins = CanonicalZones.getManagedAdmins();
      expect(admins.any((a) => a.displayId == codeAdmin.displayId), isTrue);
    });

    test('2. Pair admin code upon sign up with name and phone number', () {
      final codeAdmin = CanonicalZones.createAdminCode(syncRemote: false);
      final code = codeAdmin.displayId!;

      final paired = CanonicalZones.pairAdminCode(
        code,
        fullName: 'Arun Hembram',
        phoneNumber: '+91 98765 43210',
        syncRemote: false,
      );

      expect(paired.fullName, equals('Arun Hembram'));
      expect(paired.phoneNumber, equals('+91 98765 43210'));
      expect(paired.displayId, equals(code));
      expect(paired.email, equals('arun.hembram@shopad.local'));

      // Verify in Canonical list
      final admins = CanonicalZones.getManagedAdmins();
      final found = admins.firstWhere((a) => a.displayId == code);
      expect(found.fullName, equals('Arun Hembram'));
      expect(found.phoneNumber, equals('+91 98765 43210'));
    });

    test('3. Master Admin Repository delegates createAdminCode and pairAdminCode', () async {
      final repo = SupabaseMasterAdminRepository();

      final newAdmin = await repo.createAdminCode();
      expect(newAdmin.displayId, isNotNull);
      expect(newAdmin.fullName, isEmpty);

      final paired = await repo.pairAdminCode(
        newAdmin.displayId!,
        fullName: 'Snehasis Sen',
        phoneNumber: '+91 98333 44556',
      );
      expect(paired.fullName, equals('Snehasis Sen'));

      final allAdmins = await repo.getAdmins();
      expect(allAdmins.any((a) => a.displayId == newAdmin.displayId && a.fullName == 'Snehasis Sen'), isTrue);
    });

    test('4. Admin Repository verifies paired admin ID', () async {
      final adminRepo = SupabaseAdminRepository();

      // Pair a code
      final codeAdmin = CanonicalZones.createAdminCode(syncRemote: false);
      CanonicalZones.pairAdminCode(
        codeAdmin.displayId!,
        fullName: 'Deepak Roy',
        phoneNumber: '+91 98111 22334',
        syncRemote: false,
      );

      final verified = await adminRepo.verifyAdminId(codeAdmin.displayId!);
      expect(verified, isNotNull);
      expect(verified!.fullName, equals('Deepak Roy'));
      expect(verified.displayId, equals(codeAdmin.displayId));
    });
  });
}

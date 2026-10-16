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

      expect(paired, isNotNull);
      expect(paired!.fullName, equals('Arun Hembram'));
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

    test('5. Reject ungenerated random admin codes', () {
      final invalidPair = CanonicalZones.pairAdminCode(
        '99999', // Never created by Master Admin
        fullName: 'Intruder Admin',
        phoneNumber: '+91 99999 88888',
        syncRemote: false,
      );
      expect(invalidPair, isNull);
    });

    test('6. Newly generated admin has 0 assigned zones initially', () async {
      final codeAdmin = CanonicalZones.createAdminCode(syncRemote: false);
      final adminRepo = SupabaseAdminRepository();

      final controlled = await adminRepo.getControlledZones(codeAdmin.id);
      expect(controlled, isEmpty);
    });

    test('7. Expel admin from zone generates new unclaimed code and auto-updates zone card upon new sign up', () {
      // 1. Initial state: kolkataCentral has Subhasis Sen
      expect(CanonicalZones.kolkataCentral.assignedAdminName, contains('Subhasis Sen'));

      // 2. Expel admin from zone: generates new code and sets zone name to "Admin Code: $code"
      final replacementAdmin = CanonicalZones.expelAdminFromZoneWithNewCode(CanonicalZones.kolkataCentralId, syncRemote: false);
      final newCode = replacementAdmin.displayId!;
      expect(newCode.length, equals(5));
      expect(CanonicalZones.kolkataCentral.assignedAdminName, equals('Admin Code: $newCode'));

      // 3. New admin signs up using newCode
      final pairedNewAdmin = CanonicalZones.pairAdminCode(
        newCode,
        fullName: 'Bikash Mukherjee',
        phoneNumber: '+91 98311 22334',
        syncRemote: false,
      );
      expect(pairedNewAdmin, isNotNull);
      expect(pairedNewAdmin!.fullName, equals('Bikash Mukherjee'));

      // 4. Zone card immediately and automatically updates to the new admin's name!
      expect(CanonicalZones.kolkataCentral.assignedAdminName, equals('Bikash Mukherjee (ID: $newCode)'));
    });

    test('8. Expel admin deactivates old admin and replaces slot with new unclaimed code preserving zones', () {
      // Create admin and assign to howrah
      final admin = CanonicalZones.createAdminCode(syncRemote: false);
      CanonicalZones.pairAdminCode(
        admin.displayId!,
        fullName: 'Original Admin',
        phoneNumber: '+91 99999 11111',
        syncRemote: false,
      );

      // Expel this admin
      final replaced = CanonicalZones.expelAdmin(admin.id, syncRemote: false);
      expect(replaced.displayId, isNotNull);
      expect(replaced.displayId, isNot(equals(admin.displayId)));
      expect(replaced.fullName, isEmpty);

      // Verify old admin is inactive
      final allAdmins = CanonicalZones.getManagedAdmins();
      expect(allAdmins.any((a) => a.id == admin.id), isFalse);
      expect(allAdmins.any((a) => a.displayId == replaced.displayId), isTrue);
    });
  });
}

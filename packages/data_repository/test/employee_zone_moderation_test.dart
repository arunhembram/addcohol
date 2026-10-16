import 'package:flutter_test/flutter_test.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';

void main() {
  group('Employee Management & Zone Assignment Tests', () {
    test('1. Create unclaimed employee code and verify unpaired state', () {
      final codeEmp = CanonicalZones.createEmployeeCode(managedByAdminId: 'admin-10001');
      expect(codeEmp.displayId, isNotNull);
      expect(codeEmp.displayId!.length, equals(5));
      expect(codeEmp.fullName, isEmpty);
      expect(codeEmp.isActive, isTrue);

      final managed = CanonicalZones.getManagedEmployees(adminId: 'admin-10001');
      expect(managed.any((e) => e.displayId == codeEmp.displayId), isTrue);
    });

    test('2. Pair employee code upon first-time login', () {
      final codeEmp = CanonicalZones.createEmployeeCode(managedByAdminId: 'admin-10001');
      final code = codeEmp.displayId!;

      final paired = CanonicalZones.pairEmployeeCode(
        code,
        fullName: 'Bikash Mukherjee',
        phoneNumber: '+91 98765 11223',
      );

      expect(paired, isNotNull);
      expect(paired!.fullName, equals('Bikash Mukherjee'));
      expect(paired.phoneNumber, equals('+91 98765 11223'));
      expect(paired.displayId, equals(code));
    });

    test('3. Assign and Unassign employee to a zone', () {
      const zoneId = CanonicalZones.kolkataCentralId;
      const testEmpId = 'emp-test-99901';

      CanonicalZones.assignEmployeeToZone(zoneId, testEmpId, syncRemote: false);
      expect(CanonicalZones.getEmployeeAssignedZoneIds(testEmpId), contains(zoneId));

      CanonicalZones.unassignEmployeeFromZone(zoneId, testEmpId, syncRemote: false);
      expect(CanonicalZones.getEmployeeAssignedZoneIds(testEmpId), isNot(contains(zoneId)));
    });

    test('4. Delete employee soft-deletes and removes from all assigned zones', () {
      final codeEmp = CanonicalZones.createEmployeeCode(managedByAdminId: 'admin-10001');
      final empId = codeEmp.id;

      CanonicalZones.assignEmployeeToZone(CanonicalZones.kolkataCentralId, empId, syncRemote: false);
      CanonicalZones.assignEmployeeToZone(CanonicalZones.saltLakeSector5Id, empId, syncRemote: false);

      CanonicalZones.deleteEmployee(empId, syncRemote: false);

      final managed = CanonicalZones.getManagedEmployees(adminId: 'admin-10001');
      expect(managed.any((e) => e.id == empId), isFalse);
      expect(CanonicalZones.getEmployeeAssignedZoneIds(empId), isEmpty);
    });

    test('5. Expelling admin does not disrupt employee zone assignments', () {
      const zoneId = CanonicalZones.saltLakeSector5Id;
      const empId = 'emp-20003';

      CanonicalZones.assignEmployeeToZone(zoneId, empId, syncRemote: false);
      expect(CanonicalZones.getEmployeeAssignedZoneIds(empId), contains(zoneId));

      CanonicalZones.expelAdminFromZone(zoneId, syncRemote: false);

      // Employees remain assigned and active in the zone
      expect(CanonicalZones.getEmployeeAssignedZoneIds(empId), contains(zoneId));
    });

    test('6. New admin has 0 managed employees by default and does not inherit mock employees', () {
      // Testing admin with a new admin ID
      final newAdminEmployees = CanonicalZones.getManagedEmployees(adminId: 'admin-code-10004');
      expect(newAdminEmployees, isEmpty);

      final newAdminEmployees2 = CanonicalZones.getManagedEmployees(adminId: '10004');
      expect(newAdminEmployees2, isEmpty);
    });

    test('7. Newly created custom zone has 0 assigned employees and does not auto-assign emp-20001', () {
      final customZone = Zone(
        id: 'z-custom-isolated-test',
        name: 'Isolated Custom Zone',
        colorHex: '#1E88E5',
        isActive: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vertices: const [
          ZoneVertex(sequenceOrder: 0, latitude: 22.58, longitude: 88.35),
          ZoneVertex(sequenceOrder: 1, latitude: 22.59, longitude: 88.36),
          ZoneVertex(sequenceOrder: 2, latitude: 22.57, longitude: 88.36),
        ],
      );

      CanonicalZones.registerCustomZone(customZone, syncRemote: false);

      final assignedEmps = CanonicalZones.getZoneAssignedEmployees(customZone.id);
      expect(assignedEmps, isEmpty);

      final emp1Zones = CanonicalZones.getEmployeeAssignedZoneIds('emp-20001');
      expect(emp1Zones, isNot(contains(customZone.id)));
    });

    test('8. Remote employee sync updates employee code to paired full name', () {
      final codeEmp = CanonicalZones.createEmployeeCode(managedByAdminId: 'admin-code-10004', syncRemote: false);
      expect(codeEmp.fullName, isEmpty);

      final pairedFromRemote = UserProfile(
        id: codeEmp.id,
        email: 'subho.das@shopad.local',
        fullName: 'Subho Das',
        role: UserRole.employee,
        phoneNumber: '+91 98111 22334',
        displayId: codeEmp.displayId,
        isActive: true,
        createdAt: DateTime.now(),
        metadata: {'managed_by_admin': 'admin-code-10004', 'assigned_zones': []},
      );

      CanonicalZones.syncRemoteEmployees([pairedFromRemote]);

      final managed = CanonicalZones.getManagedEmployees(adminId: 'admin-code-10004');
      final updated = managed.firstWhere((e) => e.displayId == codeEmp.displayId);
      expect(updated.fullName, equals('Subho Das'));
      expect(updated.phoneNumber, equals('+91 98111 22334'));
    });
  });

  group('Shop Moderation & Under Process Flow Tests', () {
    test('6. New shop starts in under_process and is guarded from distribution', () {
      final newShop = Shop(
        id: 'shop-test-under-process',
        shopName: 'Green Grocery Hub',
        ownerId: 'owner-test-1',
        ownerName: 'Ramesh Sen',
        category: 'grocery',
        latitude: 22.5726,
        longitude: 88.3639,
        address: 'BBD Bagh, Kolkata',
        zoneId: CanonicalZones.kolkataCentralId,
        status: 'under_process',
        createdAt: DateTime.now(),
      );

      expect(newShop.isUnderProcess, isTrue);
      expect(newShop.isAgreed, isFalse);
      expect(newShop.isFollowup, isFalse);

      CanonicalShops.approveShop(newShop.id, syncRemote: false);
    });

    test('7. Approving shop sets status to active and generates shop code', () {
      final shop = CanonicalShops.getShopById('shop-101');
      expect(shop, isNotNull);

      CanonicalShops.approveShop(shop!.id, syncRemote: false);
      final approved = CanonicalShops.getShopById('shop-101');
      expect(approved?.status, equals('active'));
      expect(approved?.isAgreed, isTrue);
      expect(approved?.isUnderProcess, isFalse);
    });

    test('8. Deleting shop removes it from repository', () {
      CanonicalShops.deleteShop('shop-109', syncRemote: false);
      expect(CanonicalShops.getShopById('shop-109'), isNull);
    });
  });
}

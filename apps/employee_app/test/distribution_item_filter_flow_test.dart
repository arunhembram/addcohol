import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/providers/employee_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Distribution Item and 3-Category Filter Logic Tests', () {
    final saloon1 = Shop(
      id: 'test-saloon-1',
      ownerId: 'o1',
      shopName: 'Glow Beauty Saloon',
      category: 'Saloon',
      address: 'Central Zone',
      latitude: 22.57,
      longitude: 88.36,
      zoneId: CanonicalZones.kolkataCentralId,
      status: 'active',
      isAgreed: true,
      createdAt: DateTime.now(),
    );

    final saloon2 = Shop(
      id: 'test-saloon-2',
      ownerId: 'o2',
      shopName: 'Habibs Hair & Saloon',
      category: 'Saloon',
      address: 'Central Zone',
      latitude: 22.58,
      longitude: 88.37,
      zoneId: CanonicalZones.kolkataCentralId,
      status: 'active',
      isAgreed: true,
      createdAt: DateTime.now(),
    );

    final regularShop1 = Shop(
      id: 'test-shop-1',
      ownerId: 'o3',
      shopName: 'Dutta Grocery Mart',
      category: 'Grocery',
      address: 'Central Zone',
      latitude: 22.57,
      longitude: 88.36,
      zoneId: CanonicalZones.kolkataCentralId,
      status: 'active',
      isAgreed: true,
      createdAt: DateTime.now(),
    );

    final regularShop2 = Shop(
      id: 'test-shop-2',
      ownerId: 'o4',
      shopName: 'Roy Electronics & Mobiles',
      category: 'Electronics',
      address: 'Central Zone',
      latitude: 22.58,
      longitude: 88.37,
      zoneId: CanonicalZones.kolkataCentralId,
      status: 'active',
      isAgreed: true,
      createdAt: DateTime.now(),
    );

    final allMockShops = [saloon1, saloon2, regularShop1, regularShop2];

    setUp(() {
      CanonicalZones.unmarkShopItemDistributed(
        zoneId: CanonicalZones.kolkataCentralId,
        shopId: saloon1.id,
        itemId: 'ad-run-comp-c-saloon-right',
      );
      CanonicalZones.unmarkShopItemDistributed(
        zoneId: CanonicalZones.kolkataCentralId,
        shopId: saloon2.id,
        itemId: 'ad-run-comp-c-saloon-right',
      );
    });

    test('1. In Normal Mode: 3-filters (All, Shops, Saloons) work accurately', () async {
      final container = ProviderContainer(
        overrides: [
          assignedShopsProvider.overrideWith((ref) async => allMockShops),
          employeeGlobalDistributionModeProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(assignedShopsProvider.future);

      // Default: All shops (4 shops)
      var shops = container.read(filteredAssignedShopsProvider).value!;
      expect(shops.length, 4);

      // Filter: Shops (only non-saloons: 2 shops)
      container.read(shopCategoryFilterProvider.notifier).state = 'shops';
      shops = container.read(filteredAssignedShopsProvider).value!;
      expect(shops.length, 2);
      expect(shops.map((s) => s.id), containsAll(['test-shop-1', 'test-shop-2']));
      expect(shops.any((s) => s.category == 'Saloon'), isFalse);

      // Filter: Saloons (only saloons: 2 shops)
      container.read(shopCategoryFilterProvider.notifier).state = 'saloons';
      shops = container.read(filteredAssignedShopsProvider).value!;
      expect(shops.length, 2);
      expect(shops.map((s) => s.id), containsAll(['test-saloon-1', 'test-saloon-2']));
      expect(shops.every((s) => s.category == 'Saloon'), isTrue);

      // Reset to All: (4 shops)
      container.read(shopCategoryFilterProvider.notifier).state = null;
      shops = container.read(filteredAssignedShopsProvider).value!;
      expect(shops.length, 4);
    });

    test('2. In Distribution Mode: selecting Image A (saloon-exclusive) restricts to saloons only', () async {
      final container = ProviderContainer(
        overrides: [
          assignedShopsProvider.overrideWith((ref) async => allMockShops),
          employeeGlobalDistributionModeProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      await container.read(assignedShopsProvider.future);

      // Select Image A (ad-run-comp-c-saloon-right)
      container.read(selectedDistributionItemIdProvider.notifier).state =
          'ad-run-comp-c-saloon-right';

      final shops = container.read(filteredAssignedShopsProvider).value!;
      // Should ONLY contain saloons, regular shops must be completely hidden
      expect(shops.length, 2);
      expect(shops.map((s) => s.id), containsAll(['test-saloon-1', 'test-saloon-2']));
      expect(shops.any((s) => s.id == 'test-shop-1'), isFalse);
      expect(shops.any((s) => s.id == 'test-shop-2'), isFalse);
    });

    test('3. Smart Vanishing: When Image A is distributed to a saloon, that saloon vanishes from view', () async {
      final container = ProviderContainer(
        overrides: [
          assignedShopsProvider.overrideWith((ref) async => allMockShops),
          employeeGlobalDistributionModeProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      await container.read(assignedShopsProvider.future);

      // Select Image A
      container.read(selectedDistributionItemIdProvider.notifier).state =
          'ad-run-comp-c-saloon-right';

      var shops = container.read(filteredAssignedShopsProvider).value!;
      expect(shops.length, 2);

      // Distribute Image A to saloon1
      CanonicalZones.recordShopItemDistributed(
        zoneId: CanonicalZones.kolkataCentralId,
        shopId: saloon1.id,
        itemId: 'ad-run-comp-c-saloon-right',
      );

      // Invalidate and re-read
      container.invalidate(filteredAssignedShopsProvider);
      shops = container.read(filteredAssignedShopsProvider).value!;

      // saloon1 MUST have vanished! Only saloon2 (where it is still pending) remains
      expect(shops.length, 1);
      expect(shops.first.id, 'test-saloon-2');
      expect(shops.any((s) => s.id == saloon1.id), isFalse);

      // Now distribute Image A to saloon2 as well
      CanonicalZones.recordShopItemDistributed(
        zoneId: CanonicalZones.kolkataCentralId,
        shopId: saloon2.id,
        itemId: 'ad-run-comp-c-saloon-right',
      );

      container.invalidate(filteredAssignedShopsProvider);
      shops = container.read(filteredAssignedShopsProvider).value!;
      // All saloons where Image A was pending have been distributed, so list is now empty (0 left)
      expect(shops.isEmpty, isTrue);
    });

    test('4. Physical Materials strictly mirror Master Admin materials list (Paper, Pens, Cello Tape, Marker Pen, QR Stands)', () {
      final materials = CanonicalZones.getAllMaterials();
      final materialNames = materials.map((m) => m.name).toList();

      expect(materialNames, contains('Paper'));
      expect(materialNames, contains('Pens'));
      expect(materialNames, contains('Cello Tape'));
      expect(materialNames, contains('Marker Pen'));
      expect(materialNames, contains('QR Stands'));

      // Check material runs for Kolkata Central
      final runs = CanonicalZones.getMaterialRuns(CanonicalZones.kolkataCentralId);
      final runNames = runs.map((r) => r.materialName).toList();
      expect(runNames, contains('Paper'));
      expect(runNames, contains('Pens'));
      expect(runNames, contains('Cello Tape'));
      expect(runNames, contains('Marker Pen'));
      expect(runNames, contains('QR Stands'));
    });

    test('5. Dynamic Master Admin Catalog Sync: Adding/Removing material in Master Admin updates runs dynamically', () {
      const testMatId = 'mat-custom-test-stapler';
      final newMat = DistributionMaterial(
        id: testMatId,
        name: 'Stapler & Pins',
        targetBusinessType: 'all',
        defaultQuantity: 1,
        createdAt: DateTime.now(),
      );

      // Master Admin adds new material
      CanonicalZones.addMaterial(newMat, syncRemote: false);

      var runs = CanonicalZones.getMaterialRuns(CanonicalZones.kolkataCentralId);
      expect(runs.any((r) => r.materialId == testMatId), isTrue);
      expect(runs.firstWhere((r) => r.materialId == testMatId).materialName, 'Stapler & Pins');

      // Master Admin removes the material
      CanonicalZones.removeMaterial(testMatId, syncRemote: false);

      runs = CanonicalZones.getMaterialRuns(CanonicalZones.kolkataCentralId);
      expect(runs.any((r) => r.materialId == testMatId), isFalse);
    });
  });
}

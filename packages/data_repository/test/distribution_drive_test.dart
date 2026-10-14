import 'package:data_repository/data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Distribution Drive & Red Cross Persistence Tests', () {
    const zoneId = CanonicalZones.kolkataCentralId;

    setUp(() {
      // Clean baseline before each test
      DistributionSyncService.isSyncEnabled = false;
      CanonicalZones.resetAll();
      CanonicalShops.resetAll();
    });

    tearDown(() {
      CanonicalZones.resetAll();
      CanonicalShops.resetAll();
      DistributionSyncService.isSyncEnabled = true;
    });

    test('1. markShopGone permanently excludes shop from all queries', () {
      final initialShops = CanonicalShops.getShopsForZones({zoneId});
      expect(initialShops.isNotEmpty, isTrue);

      final targetShop = initialShops.first;
      expect(CanonicalShops.isShopGone(targetShop.id), isFalse);

      // Mark shop gone
      CanonicalShops.markShopGone(targetShop.id, syncRemote: false);
      expect(CanonicalShops.isShopGone(targetShop.id), isTrue);

      // Verify excluded from getShopsForZones and all
      final updatedShops = CanonicalShops.getShopsForZones({zoneId});
      expect(updatedShops.any((s) => s.id == targetShop.id), isFalse);
      expect(CanonicalShops.all.any((s) => s.id == targetShop.id), isFalse);
    });

    test('2. markShopClosedToday marks shop as closed today and crossed', () {
      final shops = CanonicalShops.getShopsForZones({zoneId});
      final testShop = shops.first;

      expect(CanonicalShops.isShopClosedToday(testShop.id), isFalse);

      CanonicalShops.markShopClosedToday(testShop.id, syncRemote: false);
      expect(CanonicalShops.isShopClosedToday(testShop.id), isTrue);
      expect(CanonicalShops.isShopCrossed(testShop.id), isTrue);
      expect(CanonicalZones.isShopCrossed(zoneId, testShop.id), isTrue);

      // Marking distributed clears closed today and crossed
      CanonicalShops.markShopDistributed(testShop.id, syncRemote: false);
      expect(CanonicalShops.isShopClosedToday(testShop.id), isFalse);
      expect(CanonicalShops.isShopCrossed(testShop.id), isFalse);
      expect(CanonicalZones.isShopCrossed(zoneId, testShop.id), isFalse);
    });

    test('3. Midnight (12:00 AM) rollover marks undistributed shops as crossed', () {
      final shops = CanonicalShops.getShopsForZones({zoneId})
          .where((s) => !s.isFollowup && !CanonicalShops.isShopGone(s.id))
          .toList();
      final testShop = shops.first;

      // Start distribution on Day 1 at 10:00 AM
      final day1 = DateTime(2026, 4, 1, 10, 0);
      CanonicalZones.setDistributionStartTime(zoneId, day1);
      CanonicalZones.setDistributionMode(zoneId, true, categories: {'Shops', 'Saloons'});

      // Same day at 8:00 PM -> Not crossed yet
      final sameDayEvening = DateTime(2026, 4, 1, 20, 0);
      expect(CanonicalZones.isShopCrossed(zoneId, testShop.id, currentTime: sameDayEvening), isFalse);

      // Next day after midnight 12:00 AM (e.g. Day 2 at 12:05 AM) -> Must be CROSSED (❌)!
      final nextDayPastMidnight = DateTime(2026, 4, 2, 0, 5);
      expect(CanonicalZones.isShopCrossed(zoneId, testShop.id, currentTime: nextDayPastMidnight), isTrue);

      // Distribution mode turned off by admin then turned on again -> CROSSED shop remains crossed!
      CanonicalZones.setDistributionMode(zoneId, false);
      expect(CanonicalZones.isShopCrossed(zoneId, testShop.id, currentTime: nextDayPastMidnight), isTrue);
    });

    test('4. checkAndAutoCompleteZone turns off distribution mode when all shops completed', () {
      CanonicalZones.setDistributionMode(zoneId, true, categories: {'Shops', 'Saloons'});
      expect(CanonicalZones.isDistributionModeActive(zoneId), isTrue);
      expect(CanonicalZones.isZoneDriveCompleted(zoneId), isFalse);

      final targetShops = CanonicalShops.getShopsForZones({zoneId})
          .where((s) => !s.isFollowup && !CanonicalShops.isShopGone(s.id))
          .where((s) => CanonicalZones.isShopCategoryTargeted(zoneId, s.category))
          .toList();

      expect(targetShops.isNotEmpty, isTrue);

      // Mark all except the last shop as distributed
      for (int i = 0; i < targetShops.length - 1; i++) {
        CanonicalShops.markShopDistributed(targetShops[i].id, syncRemote: false);
      }
      expect(CanonicalZones.checkAndAutoCompleteZone(zoneId), isFalse);
      expect(CanonicalZones.isDistributionModeActive(zoneId), isTrue);

      // Mark the last shop as distributed
      CanonicalShops.markShopDistributed(targetShops.last.id, syncRemote: false);
      final completed = CanonicalZones.checkAndAutoCompleteZone(zoneId);

      expect(completed, isTrue);
      expect(CanonicalZones.isDistributionModeActive(zoneId), isFalse,
          reason: 'Distribution mode switch must automatically turn OFF when all shops completed');
      expect(CanonicalZones.isZoneDriveCompleted(zoneId), isTrue);
    });

    test('5. resetDistributionDrive starts fresh campaign and preserves gone shops', () {
      // 1. Mark a shop gone
      final shops = CanonicalShops.getShopsForZones({zoneId});
      final goneShop = shops.first;
      CanonicalShops.markShopGone(goneShop.id, syncRemote: false);

      // 2. Mark zone drive completed
      CanonicalZones.setZoneDriveCompleted(zoneId, true, syncRemote: false);
      CanonicalZones.setDistributionMode(zoneId, false, syncRemote: false);

      // 3. Admin resets distribution drive for new campaign
      CanonicalZones.resetDistributionDrive(zoneId, syncRemote: false);

      // Drive completed is false, distribution mode is ON
      expect(CanonicalZones.isZoneDriveCompleted(zoneId), isFalse);
      expect(CanonicalZones.isDistributionModeActive(zoneId), isTrue);

      // Active shops have isDistributed = false
      final activeShops = CanonicalShops.getShopsForZones({zoneId});
      for (final s in activeShops) {
        expect(s.isDistributed, isFalse);
      }

      // Gone shop remains permanently archived
      expect(CanonicalShops.isShopGone(goneShop.id), isTrue);
      expect(activeShops.any((s) => s.id == goneShop.id), isFalse);
    });
  });
}

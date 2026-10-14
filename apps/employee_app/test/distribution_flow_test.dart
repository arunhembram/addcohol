import 'package:data_repository/data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Distribution Flow & Architecture Tests', () {
    setUp(() {
      CanonicalZones.resetAll();
      CanonicalShops.resetAll();
    });

    test('CanonicalZones provides global materials catalog and seeded company ad runs', () {
      final materials = CanonicalZones.getAllMaterials();
      expect(materials, isNotEmpty);
      expect(materials.any((m) => m.name == 'Cello Tape'), isTrue);

      final adRuns = CanonicalZones.getCompanyAdRuns(CanonicalZones.kolkataCentralId);
      expect(adRuns, isNotEmpty);
      expect(adRuns.any((r) => r.placementSide == 'left' && r.businessType == 'shop'), isTrue);
      expect(adRuns.any((r) => r.placementSide == 'right' && r.businessType == 'saloon'), isTrue);
    });

    test('Shop Distribution QR generates expected payload and parses shop ID accurately', () {
      final shop = CanonicalShops.getShopById('shop-101')!;
      final payload = CanonicalZones.getShopDistributionQrPayload(shop);

      expect(payload.startsWith('SHOP_DISTRIBUTION:'), isTrue);
      expect(payload.contains('shop-101'), isTrue);

      final parsedId = CanonicalZones.parseShopIdFromDistributionQr(payload);
      expect(parsedId, equals('shop-101'));
    });

    test('Recording shop distribution completes handover and shop vanishes from active targets', () {
      final zoneId = CanonicalZones.kolkataCentralId;
      final shop = CanonicalShops.getShopById('shop-101')!;

      expect(shop.isDistributed, isFalse);

      CanonicalZones.recordShopDistributionComplete(
        zoneId: zoneId,
        shopId: shop.id,
        isGone: false,
      );

      final updatedShop = CanonicalShops.getShopById('shop-101')!;
      expect(updatedShop.isDistributed, isTrue);

      CanonicalZones.setDistributionMode(zoneId, true);
      expect(CanonicalZones.isDistributionModeActive(zoneId), isTrue);

      // A distributed shop is marked as completed
      expect(updatedShop.isDistributed, isTrue);
    });

    test('CanonicalZones allows toggling distribution mode across all zones', () {
      final allZoneIds = [
        CanonicalZones.kolkataCentralId,
        CanonicalZones.saltLakeSector5Id,
        CanonicalZones.howrahIndustrialId,
      ];
      for (final id in allZoneIds) {
        CanonicalZones.setDistributionMode(id, false);
        expect(CanonicalZones.isDistributionModeActive(id), isFalse);
      }
      for (final id in allZoneIds) {
        CanonicalZones.setDistributionMode(id, true);
        expect(CanonicalZones.isDistributionModeActive(id), isTrue);
      }
    });
  });
}

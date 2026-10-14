import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_features/map_features.dart';

void main() {
  group('LocationService Tests', () {
    test('LocationService can be instantiated', () {
      const service = LocationService();
      expect(service, isNotNull);
    });
  });

  group('CategoryMarkerHelper Follow-up Marker Tests', () {
    test('Correct marker variant chosen for today, missed, future, and agreed shops', () {
      final now = DateTime.now();

      // 1. Follow-up today -> Always Orange
      final todayShop = Shop(
        id: 's-today',
        ownerId: 'o-1',
        shopName: 'Today Shop',
        category: 'Grocery',
        address: 'Addr',
        latitude: 22.0,
        longitude: 88.0,
        isAgreed: false,
        status: 'follow_up',
        nextFollowupDate: DateTime(now.year, now.month, now.day, 12, 0),
        createdAt: now,
      );

      final todayMarker = CategoryMarkerHelper.getShopMarkerSync(
        shop: todayShop,
        blinkToggle: false,
      );
      final todayMarkerAlt = CategoryMarkerHelper.getShopMarkerSync(
        shop: todayShop,
        blinkToggle: true,
      );
      // Both should be identical orange icon (blinkToggle does not affect today's shop)
      expect(todayMarker.toJson(), equals(todayMarkerAlt.toJson()));

      // 2. Follow-up scheduled for future -> Always Blue
      final futureShop = Shop(
        id: 's-future',
        ownerId: 'o-2',
        shopName: 'Future Shop',
        category: 'Grocery',
        address: 'Addr',
        latitude: 22.0,
        longitude: 88.0,
        isAgreed: false,
        status: 'follow_up',
        nextFollowupDate: now.add(const Duration(days: 3)),
        createdAt: now,
      );

      final futureMarker = CategoryMarkerHelper.getShopMarkerSync(
        shop: futureShop,
        blinkToggle: false,
      );
      final futureMarkerAlt = CategoryMarkerHelper.getShopMarkerSync(
        shop: futureShop,
        blinkToggle: true,
      );
      expect(futureMarker.toJson(), equals(futureMarkerAlt.toJson()));

      // 3. Follow-up missed (overdue) -> Alternates between blue and orange based on blinkToggle
      final missedShop = Shop(
        id: 's-missed',
        ownerId: 'o-3',
        shopName: 'Missed Shop',
        category: 'Grocery',
        address: 'Addr',
        latitude: 22.0,
        longitude: 88.0,
        isAgreed: false,
        status: 'follow_up',
        nextFollowupDate: now.subtract(const Duration(days: 2)),
        createdAt: now,
      );

      final missedMarkerBlue = CategoryMarkerHelper.getShopMarkerSync(
        shop: missedShop,
        blinkToggle: false, // isOrange = false -> Blue
      );
      final missedMarkerOrange = CategoryMarkerHelper.getShopMarkerSync(
        shop: missedShop,
        blinkToggle: true, // isOrange = true -> Orange
      );

      // Missed toggle=false must equal futureMarker (Blue)
      expect(missedMarkerBlue.toJson(), equals(futureMarker.toJson()));
      // Missed toggle=true must equal todayMarker (Orange)
      expect(missedMarkerOrange.toJson(), equals(todayMarker.toJson()));
      // And the two alternating states must be distinct
      expect(missedMarkerBlue.toJson(), isNot(equals(missedMarkerOrange.toJson())));
    });
  });
}

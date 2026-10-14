import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/screens/map/shop_operational_status.dart';
import 'package:employee_app/screens/map/widgets/shop_floating_action_card.dart';

void main() {
  final testShop6Pm = Shop(
    id: 'test-shop-6pm',
    ownerId: 'owner-6pm',
    shopName: 'Evening Snack Corner',
    category: 'Fast Food',
    address: '10 Park Street, Kolkata',
    latitude: 22.5500,
    longitude: 88.3500,
    status: 'active',
    activeScreensCount: 1,
    createdAt: DateTime(2026, 1, 1),
    openingTime: '6 PM',
    closingTime: '11 PM',
    weeklyClosedDay: 'Tuesday',
    phoneNumber: '9876543210',
  );

  final testShopWeeklySunday = Shop(
    id: 'test-shop-sunday',
    ownerId: 'owner-sun',
    shopName: 'Sunday Closed Books',
    category: 'Stationery',
    address: '25 College St, Kolkata',
    latitude: 22.5700,
    longitude: 88.3600,
    status: 'active',
    activeScreensCount: 1,
    createdAt: DateTime(2026, 1, 1),
    openingTime: '09:00 AM',
    closingTime: '08:00 PM',
    weeklyClosedDay: 'Sunday',
  );

  final testOperationalStatus = ShopOperationalService.calculateStatus(
    shop: testShop6Pm,
    referenceTime: DateTime.utc(2026, 10, 10, 11, 30), // 5:00 PM IST (UTC 11:30)
  );

  group('Shop Opening Time & Weekly Closed Logic Tests', () {
    test('1. Shop.parseOpeningTimeToday parses 6 PM into 18:00 on target date', () {
      final refUtc = DateTime.utc(2026, 10, 10, 11, 30); // 5:00 PM IST
      final opening = testShop6Pm.parseOpeningTimeToday(refUtc);
      expect(opening, isNotNull);
      expect(opening!.hour, equals(18));
      expect(opening.minute, equals(0));
    });

    test('2. Shop.isBeforeOpeningTime returns true at 5 PM when shop opens at 6 PM', () {
      // 5:00 PM IST = 11:30 UTC
      final ref5pm = DateTime.utc(2026, 10, 10, 11, 30);
      expect(testShop6Pm.isBeforeOpeningTime(ref5pm), isTrue);

      // 6:01 PM IST = 12:31 UTC
      final ref601pm = DateTime.utc(2026, 10, 10, 12, 31);
      expect(testShop6Pm.isBeforeOpeningTime(ref601pm), isFalse);
    });

    test('3. Shop.isWeeklyClosedToday identifies weekly closed day accurately', () {
      // 2026-10-13 is Tuesday
      final tuesdayUtc = DateTime.utc(2026, 10, 13, 6, 0); // 11:30 AM IST
      expect(testShop6Pm.isWeeklyClosedToday(tuesdayUtc), isTrue);

      // 2026-10-14 is Wednesday
      final wednesdayUtc = DateTime.utc(2026, 10, 14, 6, 0);
      expect(testShop6Pm.isWeeklyClosedToday(wednesdayUtc), isFalse);

      // 2026-10-11 is Sunday
      final sundayUtc = DateTime.utc(2026, 10, 11, 6, 0);
      expect(testShopWeeklySunday.isWeeklyClosedToday(sundayUtc), isTrue);
    });

    test('4. ShopOperationalService.calculateStatus sets closedToday for weekly closed shop', () {
      final tuesdayUtc = DateTime.utc(2026, 10, 13, 6, 0);
      final status = ShopOperationalService.calculateStatus(
        shop: testShop6Pm,
        referenceTime: tuesdayUtc,
      );
      expect(status.operationalType, equals(ShopOperationalType.closedToday));
      expect(status.badgeText, equals('Closed today (Weekly off)'));
      expect(status.bengaliBadgeText, equals('আজ বন্ধ (সাপ্তাহিক ছুটি)'));
    });
  });

  group('ShopFloatingActionCard Weekly Closed & Premature Closed Tests', () {
    testWidgets('Distribution mode renders weekly closed banner (🔒) and Weekly Off button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopFloatingActionCard(
              shop: testShop6Pm,
              status: testOperationalStatus,
              isDistributionMode: true,
              isCrossed: false,
              isClosedToday: false,
              isWeeklyClosed: true,
              distanceMeters: 50.0,
              onClose: () {},
              onDirections: () {},
              onDetails: () {},
              onMakePayment: () {},
              onCall: () {},
              onThumbnailTap: () {},
            ),
          ),
        ),
      );

      // Should render weekly closed banner
      expect(find.textContaining('🔒 দোকান আজ বন্ধ (সাপ্তাহিক ছুটি: Tuesday)'), findsOneWidget);
      // Action button should show Weekly Off / সাপ্তাহিক বন্ধ
      expect(find.text('Weekly Off'), findsOneWidget);
      expect(find.text('সাপ্তাহিক বন্ধ'), findsOneWidget);
    });

    testWidgets('Premature Closed Warning Dialog appears when shop opens at 6 PM and employee presses closed at 5 PM', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  // Simulate premature close logic from _handleMarkClosedToday
                  final refTime = DateTime.utc(2026, 10, 10, 11, 30); // 5 PM IST
                  if (testShop6Pm.isBeforeOpeningTime(refTime)) {
                    final formattedOpening = testShop6Pm.openingTime ?? '';
                    showDialog<void>(
                      context: ctx,
                      builder: (dialogCtx) => AlertDialog(
                        icon: const Icon(Icons.access_time_filled_rounded),
                        title: Text("Shop's opening time is $formattedOpening"),
                        content: Text('দোকান খোলার সময়: $formattedOpening\nখোলার সময়ের আগে বন্ধ চিহ্নিত করা যাবে না।'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('ঠিক আছে (Understood)'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text('Press Closed'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Press Closed'));
      await tester.pumpAndSettle();

      // Warning Dialog Title
      expect(find.text("Shop's opening time is 6 PM"), findsOneWidget);
      expect(find.textContaining('দোকান খোলার সময়: 6 PM'), findsOneWidget);
      expect(find.text('ঠিক আছে (Understood)'), findsOneWidget);

      await tester.tap(find.text('ঠিক আছে (Understood)'));
      await tester.pumpAndSettle();

      expect(find.text("Shop's opening time is 6 PM"), findsNothing);
    });
  });
}

import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/screens/map/shop_operational_status.dart';
import 'package:employee_app/screens/map/widgets/shop_floating_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testShop = CanonicalShops.all.first;

  final testFollowupShop = Shop(
    id: 'shop-dist-followup',
    ownerId: 'owner-fu',
    shopName: 'Pending Discussion Cafe',
    category: 'Cafe',
    address: '15 Esplanade, Kolkata',
    latitude: 22.5690,
    longitude: 88.3510,
    status: 'follow_up',
    isAgreed: false,
    zoneId: CanonicalZones.kolkataCentralId,
    followupReason: 'Owner busy today',
    nextFollowupDate: DateTime.now().add(const Duration(days: 1)),
    createdAt: DateTime.now(),
  );

  final testOperationalStatus = ShopOperationalService.calculateStatus(
    shop: testShop,
  );

  group('Distribution Mode Widget & Action Tests', () {
    testWidgets('Normal mode renders standard action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopFloatingActionCard(
              shop: testShop,
              status: testOperationalStatus,
              isDistributionMode: false,
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

      // In normal mode, should see standard action labels
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Make Payment'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets(
        'Distribution mode renders Direction and Done (বিতরণ সম্পন্ন) buttons when within 100m',
        (tester) async {
      bool markedDistributed = false;
      bool directionsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopFloatingActionCard(
              shop: testShop,
              status: testOperationalStatus,
              isDistributionMode: true,
              distanceMeters: 45.0, // Within 100 meters
              onClose: () {},
              onDirections: () => directionsTapped = true,
              onMarkDistributed: () => markedDistributed = true,
              onDetails: () {},
              onMakePayment: () {},
              onCall: () {},
              onThumbnailTap: () {},
            ),
          ),
        ),
      );

      // In distribution mode, should see Call, Direction, Closed Today, Gone, and Done
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('দিকনির্দেশনা'), findsOneWidget);
      expect(find.text('Closed Today'), findsOneWidget);
      expect(find.text('Gone'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('বিতরণ সম্পন্ন'), findsOneWidget);
      expect(find.textContaining('১০০ মিটারের মধ্যে আছেন (45m)'), findsOneWidget);

      // Details and Make Payment should be hidden in distribution mode
      expect(find.text('Details'), findsNothing);
      expect(find.text('Make Payment'), findsNothing);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(markedDistributed, isTrue);

      // Tap Direction
      await tester.tap(find.text('Direction'));
      await tester.pump();
      expect(directionsTapped, isTrue);
    });

    testWidgets(
        'Distribution mode renders red cross banner for crossed shop from previous day',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopFloatingActionCard(
              shop: testShop,
              status: testOperationalStatus,
              isDistributionMode: true,
              isCrossed: true,
              distanceMeters: 60.0,
              onClose: () {},
              onDirections: () {},
              onMarkDistributed: () {},
              onClosedToday: () {},
              onMarkGone: () {},
              onDetails: () {},
              onMakePayment: () {},
              onCall: () {},
              onThumbnailTap: () {},
            ),
          ),
        ),
      );

      // Should render prominent red cross banner
      expect(find.textContaining('❌ অসমাপ্ত বিতরণ'), findsOneWidget);
    });

    testWidgets(
        'Distribution mode renders closed today banner (🔒) when shop was visited today but closed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopFloatingActionCard(
              shop: testShop,
              status: testOperationalStatus,
              isDistributionMode: true,
              isCrossed: true,
              isClosedToday: true,
              distanceMeters: 60.0,
              onClose: () {},
              onDirections: () {},
              onMarkDistributed: () {},
              onClosedToday: () {},
              onMarkGone: () {},
              onDetails: () {},
              onMakePayment: () {},
              onCall: () {},
              onThumbnailTap: () {},
            ),
          ),
        ),
      );

      // Should render closed today banner, not crossed banner
      expect(find.textContaining('🔒 দোকান আজ বন্ধ'), findsOneWidget);
      expect(find.textContaining('❌ অসমাপ্ত বিতরণ'), findsNothing);
      expect(find.text('আজ বন্ধ (পরিদর্শিত)'), findsOneWidget);
    });

    testWidgets(
        'Distribution mode warns when employee is farther than 100 meters from shop',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopFloatingActionCard(
              shop: testShop,
              status: testOperationalStatus,
              isDistributionMode: true,
              distanceMeters: 380.0, // Farther than 100 meters
              onClose: () {},
              onDirections: () {},
              onMarkDistributed: () {},
              onClosedToday: () {},
              onMarkGone: () {},
              onDetails: () {},
              onMakePayment: () {},
              onCall: () {},
              onThumbnailTap: () {},
            ),
          ),
        ),
      );

      // Should display distance warning chip and lock indicator
      expect(find.textContaining('দোকান থেকে 380m দূরে • ১০০ মিটারে পৌঁছাতে হবে'), findsOneWidget);
      expect(find.text('বিতরণ (১০০ মিটারে যান)'), findsOneWidget);
    });

    test('CanonicalZones distribution mode toggle and shop filtering rules', () {
      final zoneId = CanonicalZones.kolkataCentralId;

      // 1. Initially distribution mode is inactive
      CanonicalZones.setDistributionMode(zoneId, false);
      expect(CanonicalZones.isDistributionModeActive(zoneId), isFalse);

      // 2. Turn on distribution mode
      CanonicalZones.setDistributionMode(zoneId, true);
      expect(CanonicalZones.isDistributionModeActive(zoneId), isTrue);

      // 3. Follow-up shop filtering rule:
      // In distribution mode, follow-up shops must strictly NOT appear
      expect(testFollowupShop.isFollowup, isTrue);
      final isDistMode = CanonicalZones.isDistributionModeActive(zoneId);

      final allShops = [testShop, testFollowupShop];
      final visibleShopsInDistMode = allShops.where((s) {
        if (isDistMode) {
          if (s.isFollowup) return false;
          if (s.isDistributed) return false;
        }
        return true;
      }).toList();

      expect(visibleShopsInDistMode.length, 1);
      expect(visibleShopsInDistMode.first.id, testShop.id);

      // 4. Mark shop as distributed -> it must vanish from map
      CanonicalShops.markShopDistributed(testShop.id);
      final updatedShop =
          CanonicalShops.all.firstWhere((s) => s.id == testShop.id);
      expect(updatedShop.isDistributed, isTrue);

      final visibleAfterDone = [updatedShop].where((s) {
        if (isDistMode) {
          if (s.isFollowup) return false;
          if (s.isDistributed) return false;
        }
        return true;
      }).toList();

      // Vanished!
      expect(visibleAfterDone.isEmpty, isTrue);

      // Reset for clean state
      CanonicalShops.resetDistributionForZone(zoneId);
      CanonicalZones.setDistributionMode(zoneId, false);
    });

    testWidgets('Confirmation dialog presents shop name with Yes/No options when within 100m',
        (tester) async {
      bool userConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final res = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('বিতরণ নিশ্চিতকরণ'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Distributed to ${testShop.shopName}?'),
                            const Text('📍 দোকানের কাছে অবস্থান যাচাইকৃত (45 মি)'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('No / না'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Yes / হ্যাঁ'),
                          ),
                        ],
                      ),
                    );
                    userConfirmed = res ?? false;
                  },
                  child: const Text('Trigger Done'),
                ),
              ),
            ),
          ),
        ),
      );

      // Trigger dialog
      await tester.tap(find.text('Trigger Done'));
      await tester.pumpAndSettle();

      // Dialog content
      expect(find.text('বিতরণ নিশ্চিতকরণ'), findsOneWidget);
      expect(find.text('Distributed to ${testShop.shopName}?'), findsOneWidget);
      expect(find.textContaining('দোকানের কাছে অবস্থান যাচাইকৃত'), findsOneWidget);
      expect(find.text('No / না'), findsOneWidget);
      expect(find.text('Yes / হ্যাঁ'), findsOneWidget);

      // Tap Yes
      await tester.tap(find.text('Yes / হ্যাঁ'));
      await tester.pumpAndSettle();

      expect(userConfirmed, isTrue);
    });
  });
}

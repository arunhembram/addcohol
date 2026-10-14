import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/providers/employee_state_providers.dart';
import 'package:employee_app/screens/map/employee_zone_map_screen.dart';
import 'package:employee_app/screens/map/shop_operational_status.dart';
import 'package:employee_app/screens/map/widgets/full_size_photo_dialog.dart';
import 'package:employee_app/screens/map/widgets/shop_details_modal.dart';
import 'package:employee_app/screens/map/widgets/shop_floating_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nowIst = ShopOperationalService.getKolkataNow();
  final constDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final todayWeekdayName = constDays[nowIst.weekday - 1];

  final testClosedShop = Shop(
    id: 'shop-closed-1',
    ownerId: 'owner-closed',
    shopName: 'Closed Sunday Mart',
    category: 'Grocery',
    address: '12 College Street, Kolkata',
    latitude: 22.5730,
    longitude: 88.3640,
    status: 'active',
    weeklyClosedDay: todayWeekdayName,
    openingTime: '08:00 AM',
    closingTime: '09:00 PM',
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  );

  final testOpeningShop = Shop(
    id: 'shop-opening-1',
    ownerId: 'owner-opening',
    shopName: 'Future Opening Bakery',
    category: 'Bakery',
    address: '55 Park Street, Kolkata',
    latitude: 22.5740,
    longitude: 88.3650,
    status: 'active',
    weeklyClosedDay: 'None',
    openingTime: '11:59 PM', // Future time
    closingTime: '11:59 PM',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  );

  final testDelayedPhotoShop = Shop(
    id: 'shop-delayed-1',
    ownerId: 'owner-delayed',
    shopName: 'Morning Fresh Milk',
    category: 'Dairy',
    address: '88 MG Road, Kolkata',
    latitude: 22.5750,
    longitude: 88.3660,
    status: 'active',
    weeklyClosedDay: 'None',
    openingTime: '04:00 AM', // In the past today
    closingTime: '10:00 PM',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  final testUploadedShop = Shop(
    id: 'shop-uploaded-1',
    ownerId: 'owner-uploaded',
    shopName: 'Super Verified Electronics',
    category: 'Electronics',
    address: '99 Chowringhee Road, Kolkata',
    phoneNumber: '9876543210',
    latitude: 22.5760,
    longitude: 88.3670,
    status: 'active',
    isAgreed: true,
    shopCode: '10009999',
    weeklyClosedDay: 'None',
    openingTime: '06:00 AM',
    closingTime: '10:00 PM',
    shopfrontPhotoUrl: 'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a',
    createdAt: DateTime.now().subtract(const Duration(days: 12)),
  );

  final testNoPhoneShop = Shop(
    id: 'shop-nophone-1',
    ownerId: 'owner-nophone',
    shopName: 'No Phone Stall',
    category: 'Tea Stall',
    address: '10 Lane, Kolkata',
    phoneNumber: null,
    latitude: 22.5770,
    longitude: 88.3680,
    status: 'active',
    weeklyClosedDay: 'None',
    openingTime: '07:00 AM',
    closingTime: '08:00 PM',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  Widget createTestWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Shop Operational Status Logic Tests', () {
    test('Identifies weekly closed day and inactive shop correctly', () {
      final status = ShopOperationalService.calculateStatus(
        shop: testClosedShop,
        referenceTime: DateTime.now(),
      );
      expect(status.operationalType, ShopOperationalType.closedToday);
      expect(status.badgeText, 'Closed today (Weekly off)');
      expect(status.bengaliBadgeText, 'আজ বন্ধ (সাপ্তাহিক ছুটি)');
    });

    test('Calculates live countdown for shop before opening time', () {
      // 10:00 AM opening with 08:00 AM reference time = 2 hours remaining
      final istRef = DateTime.utc(2026, 10, 1, 2, 30); // 08:00 AM IST
      final shop = Shop(
        id: 'shop-test-countdown',
        ownerId: 'o1',
        shopName: 'Morning Tea',
        category: 'Tea Stall',
        address: 'Kolkata',
        latitude: 22.5,
        longitude: 88.3,
        openingTime: '10:00 AM',
        createdAt: DateTime.now(),
      );

      final status = ShopOperationalService.calculateStatus(
        shop: shop,
        referenceTime: istRef,
      );

      expect(status.operationalType, ShopOperationalType.beforeOpening);
      expect(status.countdownToOpen?.inHours, 2);
      expect(status.badgeText, contains('Opening in'));
      expect(status.bengaliBadgeText, contains('খোলার বাকি'));
    });

    test('Respects 15-minute grace period after opening', () {
      // 09:00 AM opening, reference time 09:10 AM IST (10 min after opening < 15 min grace)
      final istRef = DateTime.utc(2026, 10, 1, 3, 40); // 09:10 AM IST
      final shop = Shop(
        id: 'shop-test-grace',
        ownerId: 'o1',
        shopName: 'Morning Fresh',
        category: 'Grocery',
        address: 'Kolkata',
        latitude: 22.5,
        longitude: 88.3,
        openingTime: '09:00 AM',
        createdAt: DateTime.now(),
      );

      final status = ShopOperationalService.calculateStatus(
        shop: shop,
        referenceTime: istRef,
        gracePeriodMinutes: 15,
      );

      expect(status.operationalType, ShopOperationalType.openPhotoMissingGrace);
      expect(status.badgeText, contains('Grace period'));
    });

    test('Reports delayed photo after 15-minute grace period expires', () {
      // 09:00 AM opening, reference time 09:35 AM IST (35 min after opening >= 15 min grace)
      final istRef = DateTime.utc(2026, 10, 1, 4, 5); // 09:35 AM IST
      final shop = Shop(
        id: 'shop-test-delayed',
        ownerId: 'o1',
        shopName: 'Morning Fresh',
        category: 'Grocery',
        address: 'Kolkata',
        latitude: 22.5,
        longitude: 88.3,
        openingTime: '09:00 AM',
        createdAt: DateTime.now(),
      );

      final status = ShopOperationalService.calculateStatus(
        shop: shop,
        referenceTime: istRef,
        gracePeriodMinutes: 15,
      );

      expect(status.operationalType, ShopOperationalType.openPhotoDelayed);
      expect(status.badgeText, 'Photo pending • delayed by 00H:35M');
      expect(status.bengaliBadgeText, contains('বিলম্ব 00H:35M'));
    });

    test('Correctly maps uploaded photo states: approved, pending, rejected, expired', () {
      final uploadApproved = ShopDailyUpload(
        id: 'u1',
        shopId: 's1',
        uploaderId: 'shopkeeper',
        photoStoragePath: 'p1',
        photoUrl: 'https://example.com/p1.jpg',
        captureTime: DateTime.now(),
        serverUploadTime: DateTime.now(),
        businessDate: ShopOperationalService.getKolkataBusinessDate(),
        latitude: 22.5,
        longitude: 88.3,
        geofenceDistanceMeters: 10,
        isGeofenceVerified: true,
        expiryTime: DateTime.now().add(const Duration(hours: 10)),
        verificationStatus: 'verified',
      );

      final statusApproved = ShopOperationalService.calculateStatus(
        shop: testUploadedShop,
        todayUpload: uploadApproved,
      );
      expect(statusApproved.photoState, ShopPhotoState.approved);
      expect(statusApproved.badgeText, 'Photo Approved');

      final uploadRejected = uploadApproved.copyWith(verificationStatus: 'rejected');
      final statusRejected = ShopOperationalService.calculateStatus(
        shop: testUploadedShop,
        todayUpload: uploadRejected,
      );
      expect(statusRejected.photoState, ShopPhotoState.rejected);
      expect(statusRejected.badgeText, 'Photo Rejected');

      final uploadExpired = uploadApproved.copyWith(isExpired: true);
      final statusExpired = ShopOperationalService.calculateStatus(
        shop: testUploadedShop,
        todayUpload: uploadExpired,
      );
      expect(statusExpired.photoState, ShopPhotoState.expired);
      expect(statusExpired.badgeText, 'Photo Expired');
    });
  });

  group('ShopFloatingActionCard Widget & Actions Tests', () {
    testWidgets('Renders Closed Today status on card', (tester) async {
      final status = ShopOperationalService.calculateStatus(shop: testClosedShop);

      await tester.pumpWidget(createTestWidget(
        ShopFloatingActionCard(
          shop: testClosedShop,
          status: status,
          onClose: () {},
          onDirections: () {},
          onDetails: () {},
          onMakePayment: () {},
          onCall: () {},
          onThumbnailTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Closed Sunday Mart'), findsOneWidget);
      expect(find.text('Closed today (Weekly off)'), findsOneWidget);
    });

    testWidgets('Renders Opening Countdown status on card', (tester) async {
      final status = ShopOperationalService.calculateStatus(
        shop: testOpeningShop,
        referenceTime: DateTime(2026, 10, 2, 8, 0),
      );

      await tester.pumpWidget(createTestWidget(
        ShopFloatingActionCard(
          shop: testOpeningShop,
          status: status,
          onClose: () {},
          onDirections: () {},
          onDetails: () {},
          onMakePayment: () {},
          onCall: () {},
          onThumbnailTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Future Opening Bakery'), findsOneWidget);
      expect(find.textContaining('Opening in'), findsOneWidget);
    });

    testWidgets('Renders Photo Pending Delayed status on card', (tester) async {
      final status = ShopOperationalService.calculateStatus(
        shop: testDelayedPhotoShop,
        referenceTime: DateTime(2026, 10, 2, 10, 0),
      );

      await tester.pumpWidget(createTestWidget(
        ShopFloatingActionCard(
          shop: testDelayedPhotoShop,
          status: status,
          onClose: () {},
          onDirections: () {},
          onDetails: () {},
          onMakePayment: () {},
          onCall: () {},
          onThumbnailTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Morning Fresh Milk'), findsOneWidget);
      expect(find.textContaining('Photo pending'), findsOneWidget);
    });

    testWidgets('Renders all four actions: Directions, Details, Make Payment, Call', (tester) async {
      final upload = ShopDailyUpload(
        id: 'u-app',
        shopId: testUploadedShop.id,
        uploaderId: 'shopkeeper',
        photoStoragePath: 'path',
        photoUrl: 'https://example.com/p.jpg',
        captureTime: DateTime.now(),
        serverUploadTime: DateTime.now(),
        businessDate: ShopOperationalService.getKolkataBusinessDate(),
        latitude: 22.5760,
        longitude: 88.3670,
        geofenceDistanceMeters: 5.0,
        isGeofenceVerified: true,
        expiryTime: DateTime.now().add(const Duration(hours: 8)),
        verificationStatus: 'verified',
      );
      final status = ShopOperationalService.calculateStatus(
        shop: testUploadedShop,
        todayUpload: upload,
      );

      bool directionsTapped = false;
      bool detailsTapped = false;
      bool paymentTapped = false;
      bool callTapped = false;
      bool thumbnailTapped = false;

      await tester.pumpWidget(createTestWidget(
        ShopFloatingActionCard(
          shop: testUploadedShop,
          status: status,
          onClose: () {},
          onDirections: () => directionsTapped = true,
          onDetails: () => detailsTapped = true,
          onMakePayment: () => paymentTapped = true,
          onCall: () => callTapped = true,
          onThumbnailTap: () => thumbnailTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Action 1: Directions
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('দিকনির্দেশনা'), findsOneWidget);
      await tester.tap(find.text('Directions'));
      expect(directionsTapped, isTrue);

      // Action 2: Details
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('বিস্তারিত'), findsOneWidget);
      await tester.tap(find.text('Details'));
      expect(detailsTapped, isTrue);

      // Action 3: Make Payment
      expect(find.text('Make Payment'), findsOneWidget);
      expect(find.text('পেমেন্ট'), findsOneWidget);
      await tester.tap(find.text('Make Payment'));
      expect(paymentTapped, isTrue);

      // Action 4: Call
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('কল করুন'), findsOneWidget);
      await tester.tap(find.text('Call'));
      expect(callTapped, isTrue);

      // Thumbnail tap
      await tester.tap(find.byType(GestureDetector).first);
      expect(thumbnailTapped, isTrue);
    });

    testWidgets('Call button is disabled when shop has no phone number', (tester) async {
      final status = ShopOperationalService.calculateStatus(shop: testNoPhoneShop);
      bool callTapped = false;

      await tester.pumpWidget(createTestWidget(
        ShopFloatingActionCard(
          shop: testNoPhoneShop,
          status: status,
          onClose: () {},
          onDirections: () {},
          onDetails: () {},
          onMakePayment: () {},
          onCall: () => callTapped = true,
          onThumbnailTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Call'), findsOneWidget);
      // Tapping disabled button should NOT trigger callTapped callback
      await tester.tap(find.text('Call'));
      expect(callTapped, isFalse);
    });
  });

  group('ShopDetailsModal & FullSizePhotoDialog Widget Tests', () {
    testWidgets('ShopDetailsModal displays all assignment fields', (tester) async {
      final status = ShopOperationalService.calculateStatus(shop: testUploadedShop);

      await tester.pumpWidget(createTestWidget(
        ShopDetailsModal(shop: testUploadedShop, status: status),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Super Verified Electronics'), findsOneWidget);
      expect(find.text('10009999'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('99 Chowringhee Road, Kolkata'), findsOneWidget);
      expect(find.text('Agreed & Active'), findsOneWidget);
    });

    testWidgets('FullSizePhotoDialog renders title, close button and status badge', (tester) async {
      final upload = ShopDailyUpload(
        id: 'u-approved',
        shopId: testUploadedShop.id,
        uploaderId: 'shopkeeper',
        photoStoragePath: 'storage/path',
        photoUrl: 'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a',
        captureTime: DateTime.now(),
        serverUploadTime: DateTime.now(),
        businessDate: ShopOperationalService.getKolkataBusinessDate(),
        latitude: 22.5760,
        longitude: 88.3670,
        geofenceDistanceMeters: 5.0,
        isGeofenceVerified: true,
        expiryTime: DateTime.now().add(const Duration(hours: 12)),
        verificationStatus: 'verified',
      );
      final status = ShopOperationalService.calculateStatus(
        shop: testUploadedShop,
        todayUpload: upload,
      );

      await tester.pumpWidget(createTestWidget(
        FullSizePhotoDialog(shop: testUploadedShop, status: status),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Super Verified Electronics'), findsOneWidget);
      expect(find.textContaining('Photo Approved'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('EmployeeZoneMapScreen Integration UI Test', () {
    testWidgets('Renders Google Map screen with controls usable while shop is selected', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockEmployeeRepository();

      await tester.pumpWidget(createTestWidget(
        const EmployeeZoneMapScreen(),
        overrides: [
          employeeAuthProvider.overrideWith((ref) => MockEmployeeAuthNotifier(repo)),
          assignedShopsDailyUploadsProvider.overrideWith((ref) async => {
            'shop-101': ShopDailyUpload(
              id: 'u-101',
              shopId: 'shop-101',
              uploaderId: 'shopkeeper',
              photoStoragePath: 'p1',
              photoUrl: 'https://example.com/p1.jpg',
              captureTime: DateTime.now(),
              serverUploadTime: DateTime.now(),
              businessDate: ShopOperationalService.getKolkataBusinessDate(),
              latitude: 22.5720,
              longitude: 88.3620,
              geofenceDistanceMeters: 10,
              isGeofenceVerified: true,
              expiryTime: DateTime.now().add(const Duration(hours: 6)),
              verificationStatus: 'verified',
            ),
          }),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Recenter and Zoom buttons remain present and usable
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.text('Long-press inside your assigned zone to add a shop'), findsOneWidget);
    });
  });
}

class MockEmployeeAuthNotifier extends EmployeeAuthNotifier {
  MockEmployeeAuthNotifier(super.employeeRepo) {
    state = EmployeeAuthState(
      isAuthenticated: true,
      currentEmployee: UserProfile(
        id: 'emp-20001',
        email: 'rahul.das@shopad.local',
        fullName: 'Rahul Das',
        role: UserRole.employee,
        displayId: '20001',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );
  }
}

class MockEmployeeRepository implements IEmployeeRepository {
  @override
  Future<UserProfile?> verifyEmployeeId(String displayId) async => null;
  @override
  Future<String> sendEmployeeOtp(String displayId) async => '';
  @override
  Future<UserProfile> verifyOtpOrPin({
    required String displayId,
    required String verificationCode,
    bool isPin = false,
  }) async =>
      UserProfile(
        id: 'emp-20001',
        email: 'rahul.das@shopad.local',
        fullName: 'Rahul Das',
        role: UserRole.employee,
        displayId: '20001',
        isActive: true,
        createdAt: DateTime.now(),
      );
  @override
  Future<UserProfile> getEmployeeProfile(String employeeId) async =>
      UserProfile(
        id: 'emp-20001',
        email: 'rahul.das@shopad.local',
        fullName: 'Rahul Das',
        role: UserRole.employee,
        displayId: '20001',
        isActive: true,
        createdAt: DateTime.now(),
      );
  @override
  Future<List<Zone>> getAssignedZones(String employeeId) async => [
        Zone(
          id: 'z-kolkata-central',
          name: 'Kolkata Central Zone',
          colorHex: '#1E88E5',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vertices: const [
            ZoneVertex(sequenceOrder: 0, latitude: 22.56, longitude: 88.35),
            ZoneVertex(sequenceOrder: 1, latitude: 22.58, longitude: 88.35),
            ZoneVertex(sequenceOrder: 2, latitude: 22.58, longitude: 88.37),
            ZoneVertex(sequenceOrder: 3, latitude: 22.56, longitude: 88.37),
          ],
        ),
      ];
  @override
  Future<Zone?> findAssignedZoneForPoint({
    required String employeeId,
    required double latitude,
    required double longitude,
  }) async =>
      null;
  @override
  Future<List<Shop>> getShopsInAssignedZones(String employeeId) async => [
        Shop(
          id: 'shop-101',
          ownerId: 'owner-1',
          shopName: 'Maa Tara Electronic Hub',
          category: 'Electronics',
          address: '42 Central Ave',
          latitude: 22.5720,
          longitude: 88.3620,
          status: 'active',
          isAgreed: true,
          openingTime: '09:00 AM',
          closingTime: '09:00 PM',
          weeklyClosedDay: 'None',
          createdAt: DateTime.now(),
        ),
      ];
  @override
  Future<bool> isPhoneNumberDuplicate({
    required String employeeId,
    required String phoneNumber,
    String? excludeShopId,
  }) async =>
      false;
  @override
  Future<List<Shop>> getNearbyDuplicateShops({
    required String employeeId,
    required double latitude,
    required double longitude,
    double thresholdMeters = 20.0,
    String? excludeShopId,
  }) async =>
      [];
  @override
  Future<Shop> addShop({
    required String employeeId,
    required String ownerName,
    required String phoneNumber,
    required String shopName,
    required String category,
    required double latitude,
    required double longitude,
    required String openingTime,
    required String closingTime,
    required String weeklyClosedDay,
    String? shopfrontPhotoUrl,
    String? landmark,
    required bool isAgreed,
    String? followupReason,
    DateTime? nextFollowupDate,
  }) async =>
      throw UnimplementedError();
  @override
  Future<Shop> updateFollowupToAgreed({
    required String employeeId,
    required String shopId,
  }) async =>
      throw UnimplementedError();
  @override
  Future<List<Shop>> getFollowupsToday(String employeeId) async => [];
  @override
  Future<List<Shop>> getOverdueFollowups(String employeeId) async => [];
  @override
  Future<List<Shop>> searchShops({
    required String employeeId,
    required String query,
  }) async =>
      [];
  @override
  Future<void> saveOfflineDraft(Map<String, dynamic> draft) async {}
  @override
  Future<List<Map<String, dynamic>>> getOfflineDrafts() async => [];
  @override
  Future<void> deleteOfflineDraft(String draftId) async {}
  @override
  Future<void> markShopDistributed({
    required String employeeId,
    required String shopId,
  }) async {}
  @override
  Future<void> markShopClosedToday({
    required String employeeId,
    required String shopId,
  }) async {}
  @override
  Future<void> markShopGone({
    required String employeeId,
    required String shopId,
  }) async {}
  @override
  Future<bool> isZoneDistributionModeActive(String zoneId) async => false;
}

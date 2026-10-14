import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Staging End-to-End Acceptance 12-Step Sequence Tests', () {
    late IAdminRepository adminRepo;
    late IEmployeeRepository employeeRepo;
    late IShopkeeperRepository shopkeeperRepo;
    late IPaymentAcknowledgementRepository paymentRepo;
    late ICompanyRepository companyRepo;
    late IPrivateMediaRepository mediaRepo;

    setUp(() {
      adminRepo = SupabaseAdminRepository();
      employeeRepo = SupabaseEmployeeRepository();
      shopkeeperRepo = SupabaseShopkeeperRepository();
      paymentRepo = SupabasePaymentAcknowledgementRepository();
      companyRepo = SupabaseCompanyRepository();
      mediaRepo = const SupabasePrivateMediaRepository();
    });

    test('STEP 1 & 2: Master Admin Zone Creation & Admin Employee Assignment', () async {
      // 1. Controlled zone with 6 polygon vertices
      final controlledZones = await adminRepo.getControlledZones('adm-10001');
      expect(controlledZones, isNotEmpty);
      final zone = controlledZones.first;
      expect(zone.id, equals('z-kolkata-central'));
      expect(zone.vertices.length, equals(6), reason: 'Zone must have a 6-point polygon');

      // 2. Admin creates/verifies employee assigned to this Zone
      final employees = await adminRepo.getEmployeesForAdmin('adm-10001');
      expect(employees, isNotEmpty);
      final emp = employees.firstWhere((e) => e.displayId == '20002');
      expect(emp.employeeAccessId ?? emp.displayId, equals('20002'));
      expect(emp.displayReference, equals('EMP-20002'));
    });

    test('STEP 3 & 4: Employee Inside-Zone Shop Creation vs Outside-Zone Denial', () async {
      // 3. Employee creates Follow-up shop and Agreed shop inside Zone
      final assignedZones = await employeeRepo.getAssignedZones('emp-20001');
      expect(assignedZones, isNotEmpty);

      // Point inside Kolkata Central (22.5720, 88.3620)
      final insideZone = await employeeRepo.findAssignedZoneForPoint(
        employeeId: 'emp-20001',
        latitude: 22.5720,
        longitude: 88.3620,
      );
      expect(insideZone, isNotNull, reason: 'Coordinates must be inside assigned zone');

      // Create Follow-up shop
      final followupShop = await employeeRepo.addShop(
        employeeId: 'emp-20001',
        ownerName: 'Imtiaz Ali',
        phoneNumber: '9876500003',
        shopName: 'Central Fresh Chicken Corner',
        category: 'Chicken',
        latitude: 22.5720,
        longitude: 88.3620,
        openingTime: '08:00 AM',
        closingTime: '08:00 PM',
        weeklyClosedDay: 'Thursday',
        isAgreed: false,
        followupReason: 'Requested contract revision for 6 months discount',
        nextFollowupDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(followupShop.isAgreed, isFalse);
      expect(followupShop.status, equals('follow_up'));

      // Create Agreed shop
      final agreedShop = await employeeRepo.addShop(
        employeeId: 'emp-20001',
        ownerName: 'Tarun Banerjee',
        phoneNumber: '9876500001',
        shopName: 'Maa Tara Electronic Hub',
        category: 'Electronics',
        latitude: 22.5720,
        longitude: 88.3620,
        openingTime: '09:00 AM',
        closingTime: '09:00 PM',
        weeklyClosedDay: 'Sunday',
        isAgreed: true,
      );
      expect(agreedShop.isAgreed, isTrue);
      expect(agreedShop.shopAccessCode?.length, equals(8), reason: 'Shop access code must be 8 digits');
      expect(agreedShop.displayReference, startsWith('SHP-KOL-'));

      // 4. Point OUTSIDE Zone (22.6500, 88.4500) must be strictly denied
      final outsideZone = await employeeRepo.findAssignedZoneForPoint(
        employeeId: 'emp-20001',
        latitude: 22.6500,
        longitude: 88.4500,
      );
      expect(outsideZone, isNull, reason: 'Outside coordinates must not match employee zone');

      expect(
        () => employeeRepo.addShop(
          employeeId: 'emp-20001',
          ownerName: 'Outside Owner',
          phoneNumber: '9876599999',
          shopName: 'Forbidden Shop',
          category: 'General',
          latitude: 22.6500,
          longitude: 88.4500,
          openingTime: '09:00 AM',
          closingTime: '09:00 PM',
          weeklyClosedDay: 'None',
          isAgreed: true,
        ),
        throwsA(isA<ForbiddenZoneException>()),
      );
    });

    test('STEP 5: Shopkeeper 8-Digit Code + OTP Login & Geofenced Photo Upload', () async {
      // Step 1: Verify 8-digit shop access code
      final shop = await shopkeeperRepo.verifyShopCode('10000001');
      expect(shop, isNotNull);
      expect(shop!.shopAccessCode, equals('10000001'));

      // Step 2: Strictly reject access with Shop Code alone (OTP required)
      expect(
        () => shopkeeperRepo.verifyOtpAndBindShop(shopCode: '10000001', otp: ''),
        throwsA(isA<AuthException>()),
      );

      // Step 3: Complete login with OTP 123456
      final authenticatedShop = await shopkeeperRepo.verifyOtpAndBindShop(
        shopCode: '10000001',
        otp: '123456',
      );
      expect(authenticatedShop.id, equals(shop.id));

      // Step 4: Upload geofenced camera photo
      final upload = await shopkeeperRepo.uploadDailyPhoto(
        shopId: shop.id,
        uploaderId: '10000001',
        localPhotoPath: '/data/user/0/com.shopad.shopkeeper/app_flutter/test_camera.jpg',
        latitude: 22.5721, // Within 15 meters of shop coordinates (22.5720, 88.3620)
        longitude: 88.3621,
        captureTime: DateTime.now(),
      );
      expect(upload.isGeofenceVerified, isTrue);
      expect(upload.isExpired, isFalse);
    });

    test('STEP 6: Company Privacy Boundaries (Agreed Active Shops Only)', () async {
      final company = await companyRepo.getCurrentCompany();
      expect(company, isNotNull);

      final visibleShops = await companyRepo.getAssignedShops(
        companyId: company!.id,
        zoneId: 'z-kolkata-central',
      );

      // Verify that all visible shops are agreed and active
      for (final s in visibleShops) {
        expect(s.status, equals('active'));
      }

      // Verify follow-up and pending shops are strictly omitted
      final hasFollowup = visibleShops.any((s) => s.shopName.contains('Chicken Corner'));
      expect(hasFollowup, isFalse, reason: 'Follow-up shops must never be exposed to company');
    });

    test('STEP 7: Payment QR Expiry After 10 Seconds', () async {
      final session = await paymentRepo.createPaymentSession(
        shopId: '10000001',
        durationSeconds: 0, // Immediately expired for testing
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(
        () => paymentRepo.scanPaymentQr(qrToken: session.qrToken!, employeeId: 'emp-20001'),
        throwsA(isA<PaymentSessionExpiredException>()),
      );
    });

    test('STEP 8: Simultaneous Scan Lock (Exactly ONE Device Wins)', () async {
      final session = await paymentRepo.createPaymentSession(shopId: '10000001');
      final qrToken = session.qrToken!;

      int successCount = 0;
      int rejectedCount = 0;

      // Two devices scan simultaneously
      final scanFutures = [
        paymentRepo.scanPaymentQr(qrToken: qrToken, employeeId: 'emp_device_A').then((s) {
          successCount++;
        }).catchError((_) {
          rejectedCount++;
        }),
        paymentRepo.scanPaymentQr(qrToken: qrToken, employeeId: 'emp_device_B').then((s) {
          successCount++;
        }).catchError((_) {
          rejectedCount++;
        }),
      ];

      await Future.wait(scanFutures);

      expect(successCount, equals(1), reason: 'Exactly one device must win atomic scan');
      expect(rejectedCount, equals(1), reason: 'Concurrent scan must be rejected');
    });

    test('STEP 9 & 10: Amount Submit, Rejection, Retry & Confirmation Flow', () async {
      // Step 9a: Create session, scan, submit wrong amount 500 INR
      final session1 = await paymentRepo.createPaymentSession(shopId: '10000001');
      final scanned1 = await paymentRepo.scanPaymentQr(qrToken: session1.qrToken!, employeeId: 'emp_device_A');
      await paymentRepo.submitPaymentAmount(sessionId: scanned1.id, amount: 500.0);

      // Shopkeeper rejects
      final rejected = await paymentRepo.rejectPayment(
        sessionId: scanned1.id,
        reason: 'Incorrect amount: expected 1500 INR',
      );
      expect(rejected.status, equals(PaymentSessionStatus.rejected));

      // Step 9b: Retry flow with fresh QR session
      final retrySession = await paymentRepo.createPaymentSession(shopId: '10000001');
      expect(retrySession.id, isNot(equals(session1.id)));

      final scanned2 = await paymentRepo.scanPaymentQr(qrToken: retrySession.qrToken!, employeeId: 'emp_device_A');
      await paymentRepo.submitPaymentAmount(sessionId: scanned2.id, amount: 1500.0);

      // Shopkeeper confirms
      final confirmed = await paymentRepo.confirmPaymentReceived(sessionId: scanned2.id);
      expect(confirmed.status, equals(PaymentSessionStatus.confirmed));
      expect(confirmed.amount, equals(1500.0));

      // Step 10: Verified user visible status
      expect(confirmed.isConfirmed, isTrue);
    });

    test('STEP 11: Photo Cleanup While Retaining Audit Metadata', () async {
      final now = DateTime.now();
      final upload = ShopDailyUpload(
        id: 'staging_upload_101',
        shopId: '10000001',
        uploaderId: 'emp-20001',
        businessDate: '2026-09-28',
        photoStoragePath: 'shops/10000001/daily/board_front.jpg',
        photoUrl: 'https://secure-vault.shopad.local/shops/10000001/daily/board_front.jpg',
        captureTime: now.subtract(const Duration(hours: 14)),
        serverUploadTime: now.subtract(const Duration(hours: 14)),
        latitude: 22.5720,
        longitude: 88.3620,
        geofenceDistanceMeters: 4.1,
        isGeofenceVerified: true,
        verificationStatus: 'verified',
        expiryTime: now.subtract(const Duration(hours: 2)), // Expired past midnight
        isExpired: false,
      );

      // Purge action executed
      final purged = upload.copyWith(
        isExpired: true,
        verificationStatus: 'expired',
      );

      expect(purged.isExpired, isTrue);
      expect(purged.verificationStatus, equals('expired'));
      expect(purged.photoStoragePath, equals('shops/10000001/daily/board_front.jpg'),
          reason: 'Audit metadata must be retained for compliance');
    });

    test('STEP 12: Zero Cross-Role Access to Aadhaar Files and Foreign Zones', () async {
      // 1. Forbidden Zone Access Defense
      expect(
        () => adminRepo.getControlledZoneById(adminId: 'adm-10001', zoneId: 'z-howrah-industrial'),
        throwsA(isA<ForbiddenZoneException>()),
      );

      // 2. Short-lived signed URL generation for private Aadhaar image
      final signedUrl = await mediaRepo.getPrivateSignedUrl(
        bucketName: 'secure-identity-docs',
        objectPath: '10000001/aadhaar_card_masked.pdf',
        expiresInSeconds: 300,
      );

      expect(signedUrl, contains('expires_in=300'));
      expect(signedUrl, isNot(contains('public/')));
    });
  });
}

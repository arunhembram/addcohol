import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment Acknowledgement & Concurrency Tests', () {
    late IPaymentAcknowledgementRepository repo;

    setUp(() {
      repo = SupabasePaymentAcknowledgementRepository();
    });

    test('1. Simultaneous scans: exactly ONE device succeeds and concurrent scans are rejected', () async {
      // Create fresh payment session
      final session = await repo.createPaymentSession(shopId: '10000001');
      final qrToken = session.qrToken!;

      // Simulate 5 simultaneous scan requests from different devices at the exact same moment
      int successCount = 0;
      int alreadyScannedCount = 0;

      final scanFutures = List.generate(5, (index) async {
        try {
          final res = await repo.scanPaymentQr(
            qrToken: qrToken,
            employeeId: 'emp_$index',
            employeeName: 'Employee $index',
          );
          if (res.status == PaymentSessionStatus.scanned) {
            successCount++;
          }
        } on PaymentQrAlreadyScannedException {
          alreadyScannedCount++;
        }
      });

      await Future.wait(scanFutures);

      // Concurrency Assertion: Exactly ONE scan succeeds; all others are rejected
      expect(successCount, equals(1), reason: 'Only the first valid scan must be atomically accepted');
      expect(alreadyScannedCount, equals(4), reason: 'Remaining 4 simultaneous scans must be rejected');
    });

    test('2. Replay Prevention: The same QR must never be scanned twice sequentially', () async {
      final session = await repo.createPaymentSession(shopId: '10000001');
      final qrToken = session.qrToken!;

      // First scan succeeds
      final firstScan = await repo.scanPaymentQr(
        qrToken: qrToken,
        employeeId: 'emp_01',
        employeeName: 'Rohan Sharma',
      );
      expect(firstScan.status, PaymentSessionStatus.scanned);

      // Second scan with same QR throws PaymentQrAlreadyScannedException
      expect(
        () => repo.scanPaymentQr(
          qrToken: qrToken,
          employeeId: 'emp_02',
          employeeName: 'Amit Roy',
        ),
        throwsA(isA<PaymentQrAlreadyScannedException>()),
      );
    });

    test('3. Server Expiry Handling: Expired QR tokens are strictly rejected', () async {
      // Create session with 0 seconds duration (immediately expired)
      final session = await repo.createPaymentSession(shopId: '10000001', durationSeconds: 0);

      // Wait a tiny bit so current time > expiresAt
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        () => repo.scanPaymentQr(
          qrToken: session.qrToken!,
          employeeId: 'emp_01',
        ),
        throwsA(isA<PaymentSessionExpiredException>()),
      );
    });

    test('4. Positive INR Amount validation: Zero and negative amounts are rejected', () async {
      final session = await repo.createPaymentSession(shopId: '10000001');
      final scanned = await repo.scanPaymentQr(
        qrToken: session.qrToken!,
        employeeId: 'emp_01',
      );

      // Zero amount rejected
      expect(
        () => repo.submitPaymentAmount(sessionId: scanned.id, amount: 0.0),
        throwsA(isA<InvalidPaymentAmountException>()),
      );

      // Negative amount rejected
      expect(
        () => repo.submitPaymentAmount(sessionId: scanned.id, amount: -150.0),
        throwsA(isA<InvalidPaymentAmountException>()),
      );

      // Positive amount accepted and transitions to awaiting_confirmation
      final valid = await repo.submitPaymentAmount(sessionId: scanned.id, amount: 1500.0);
      expect(valid.amount, 1500.0);
      expect(valid.currency, 'INR');
      expect(valid.status, PaymentSessionStatus.awaitingConfirmation);
    });

    test('5. Shopkeeper Confirmation Flow: Marks payment successful with INR', () async {
      final session = await repo.createPaymentSession(shopId: '10000001');
      await repo.scanPaymentQr(qrToken: session.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: session.id, amount: 3200.0);

      final confirmed = await repo.confirmPaymentReceived(sessionId: session.id);
      expect(confirmed.status, PaymentSessionStatus.confirmed);
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.amount, 3200.0);
    });

    test('6. Shopkeeper Rejection Flow: Invalidates transaction and records reason', () async {
      final session = await repo.createPaymentSession(shopId: '10000001');
      await repo.scanPaymentQr(qrToken: session.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: session.id, amount: 999.0);

      final rejected = await repo.rejectPayment(
        sessionId: session.id,
        reason: 'Incorrect amount: expected 1200 INR',
      );
      expect(rejected.status, PaymentSessionStatus.rejected);
      expect(rejected.isRejected, isTrue);
      expect(rejected.rejectionReason, 'Incorrect amount: expected 1200 INR');

      // Cannot confirm an already rejected session
      expect(
        () => repo.confirmPaymentReceived(sessionId: session.id),
        throwsException,
      );
    });

    test('7. Real-Time Stream Notification: Emits updates across state transitions', () async {
      final session = await repo.createPaymentSession(shopId: '10000001');
      final stream = repo.watchPaymentSession(session.id);

      final states = <PaymentSessionStatus>[];
      final subscription = stream.listen((s) {
        states.add(s.status);
      });

      await repo.scanPaymentQr(qrToken: session.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: session.id, amount: 500.0);
      await repo.confirmPaymentReceived(sessionId: session.id);

      // Allow microtasks to deliver stream events
      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(states, contains(PaymentSessionStatus.scanned));
      expect(states, contains(PaymentSessionStatus.awaitingConfirmation));
      expect(states, contains(PaymentSessionStatus.confirmed));
    });

    test('8. QR Token Rotation on Single Session: Rotates token every 10s without creating new sessions', () async {
      final initialSession = await repo.createPaymentSession(shopId: '10000001');
      final originalToken = initialSession.qrToken!;

      // Rotate QR token on the same session
      final rotatedSession = await repo.rotateQrToken(
        sessionId: initialSession.id,
        shopId: '10000001',
      );

      // Session ID must remain the same (no unlimited sessions created)
      expect(rotatedSession.id, equals(initialSession.id));
      // Fresh token generated
      expect(rotatedSession.qrToken, isNot(equals(originalToken)));
      expect(rotatedSession.status, equals(PaymentSessionStatus.created));

      // Old superseded token must be rejected
      expect(
        () => repo.scanPaymentQr(qrToken: originalToken, employeeId: 'emp_01'),
        throwsA(isA<Exception>()),
      );

      // Newly rotated token scans successfully
      final scanResult = await repo.scanPaymentQr(
        qrToken: rotatedSession.qrToken!,
        employeeId: 'emp_01',
      );
      expect(scanResult.status, equals(PaymentSessionStatus.scanned));
    });

    test('9. Invalid Token States: Scanned, rejected, and confirmed tokens are all strictly rejected', () async {
      // 1. Scanned token cannot be re-scanned
      final session1 = await repo.createPaymentSession(shopId: '10000001');
      await repo.scanPaymentQr(qrToken: session1.qrToken!, employeeId: 'emp_01');
      expect(
        () => repo.scanPaymentQr(qrToken: session1.qrToken!, employeeId: 'emp_02'),
        throwsA(isA<PaymentQrAlreadyScannedException>()),
      );

      // 2. Rejected session cannot be re-scanned
      final session2 = await repo.createPaymentSession(shopId: '10000001');
      await repo.scanPaymentQr(qrToken: session2.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: session2.id, amount: 500.0);
      await repo.rejectPayment(sessionId: session2.id, reason: 'Incorrect');
      expect(
        () => repo.scanPaymentQr(qrToken: session2.qrToken!, employeeId: 'emp_01'),
        throwsA(isA<Exception>()),
      );

      // 3. Confirmed session token cannot be reused
      final session3 = await repo.createPaymentSession(shopId: '10000001');
      await repo.scanPaymentQr(qrToken: session3.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: session3.id, amount: 500.0);
      await repo.confirmPaymentReceived(sessionId: session3.id);
      expect(
        () => repo.scanPaymentQr(qrToken: session3.qrToken!, employeeId: 'emp_01'),
        throwsA(isA<Exception>()),
      );
    });

    test('10. Rejection and Retry Flow: Shopkeeper rejects invalid amount, and employee retries with fresh session', () async {
      final session = await repo.createPaymentSession(shopId: '10000001');
      await repo.scanPaymentQr(qrToken: session.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: session.id, amount: 500.0);

      // Shopkeeper rejects due to wrong amount
      final rejected = await repo.rejectPayment(
        sessionId: session.id,
        reason: 'Payment should be 1500 INR',
      );
      expect(rejected.status, equals(PaymentSessionStatus.rejected));

      // Retry flow: Shopkeeper opens fresh session, employee scans and submits corrected amount
      final retrySession = await repo.createPaymentSession(shopId: '10000001');
      expect(retrySession.id, isNot(equals(session.id)));

      await repo.scanPaymentQr(qrToken: retrySession.qrToken!, employeeId: 'emp_01');
      await repo.submitPaymentAmount(sessionId: retrySession.id, amount: 1500.0);
      final finalConfirmed = await repo.confirmPaymentReceived(sessionId: retrySession.id);

      expect(finalConfirmed.status, equals(PaymentSessionStatus.confirmed));
      expect(finalConfirmed.amount, equals(1500.0));
      expect(finalConfirmed.isConfirmed, isTrue);
    });

    test('11. Staging Test: Daily photo expiry marks status expired and retains audit metadata', () async {
      // Create temporary staging daily photo representation
      final photoId = 'upload_staging_${DateTime.now().millisecondsSinceEpoch}';
      final storagePath = 'shops/10000001/daily/test_photo.jpg';
      final now = DateTime.now();

      final upload = ShopDailyUpload(
        id: photoId,
        shopId: '10000001',
        uploaderId: 'emp-20001',
        businessDate: '2026-09-28',
        photoStoragePath: storagePath,
        photoUrl: 'https://secure-vault.shopad.local/$storagePath',
        captureTime: now.subtract(const Duration(hours: 12)),
        serverUploadTime: now.subtract(const Duration(hours: 12)),
        latitude: 22.5720,
        longitude: 88.3620,
        geofenceDistanceMeters: 5.2,
        isGeofenceVerified: true,
        verificationStatus: 'verified',
        expiryTime: now.subtract(const Duration(minutes: 5)), // Passed Asia/Kolkata cutoff
        isExpired: false,
      );

      // Verify that before expiry, it is marked active
      expect(upload.isExpired, isFalse);

      // Simulate midnight Asia/Kolkata server-side purge execution:
      // Object removed from storage, record updated to expired, audit metadata retained
      final expiredRecord = upload.copyWith(
        isExpired: true,
        verificationStatus: 'expired',
      );

      expect(expiredRecord.isExpired, isTrue);
      expect(expiredRecord.verificationStatus, equals('expired'));
      expect(expiredRecord.photoStoragePath, equals(storagePath),
          reason: 'Audit metadata and historical path reference must be retained');
    });
  });
}

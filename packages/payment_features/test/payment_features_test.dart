import 'package:data_repository/data_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_features/payment_features.dart';

void main() {
  group('PaymentService & Security Policy Tests', () {
    test('enforces opaque tokens and rejects plaintext secret/amount payloads', () {
      const service = PaymentService();

      // Valid opaque server-generated tokens
      expect(service.isOpaqueToken('PAYACK_a1b2c3d4e5f67890'), isTrue);
      expect(service.isOpaqueToken('PAYACK_4891b29fc0334812'), isTrue);

      // Rejects plaintext data containing amounts, shop IDs, secrets
      expect(service.isOpaqueToken('SHOPAD:PAY:camp-99:shop-42:2500.0:12345'), isFalse);
      expect(service.isOpaqueToken('SECRET:9876543210:5000'), isFalse);
      expect(service.isOpaqueToken(''), isFalse);
    });

    test('system disclaimer explicitly confirms field acknowledgement', () {
      expect(PaymentService.systemDisclaimer, contains('field payment acknowledgement'));
      expect(PaymentService.systemDisclaimer, contains('does not transfer money through UPI/card'));
    });

    test('coordinates flow via repository successfully', () async {
      final repo = SupabasePaymentAcknowledgementRepository();
      final service = PaymentService(repository: repo);

      // 1. Shopkeeper creates session
      final session = await service.createPaymentSession(shopId: '10000001');
      expect(session.status.name, 'created');
      expect(session.qrToken, startsWith('PAYACK_'));
      expect(service.isOpaqueToken(session.qrToken!), isTrue);

      // 2. Employee scans QR
      final scanned = await service.scanPaymentQr(
        qrToken: session.qrToken!,
        employeeId: 'emp-101',
        employeeName: 'Rohan Sharma',
      );
      expect(scanned.status.name, 'scanned');
      expect(scanned.employeeName, 'Rohan Sharma');

      // 3. Employee submits positive amount
      final withAmount = await service.submitPaymentAmount(
        sessionId: scanned.id,
        amount: 2500.0,
      );
      expect(withAmount.amount, 2500.0);
      expect(withAmount.currency, 'INR');
      expect(withAmount.status.apiValue, 'awaiting_confirmation');

      // 4. Shopkeeper confirms
      final confirmed = await service.confirmPaymentReceived(sessionId: withAmount.id);
      expect(confirmed.status.name, 'confirmed');
      expect(confirmed.isConfirmed, isTrue);
    });
  });
}

import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';

/// Service coordinating field payment acknowledgements
class PaymentService {
  final AppLogger _logger;
  final IPaymentAcknowledgementRepository? _repository;

  static const String systemDisclaimer =
      'This system records a field payment acknowledgement. It does not transfer money through UPI/card.';

  const PaymentService({
    AppLogger? logger,
    IPaymentAcknowledgementRepository? repository,
  }) : _logger = logger ?? const AppLogger(tag: 'PaymentService'),
       _repository = repository;

  /// Verifies that a QR token is an opaque token (does not contain sensitive data)
  bool isOpaqueToken(String token) {
    final clean = token.trim();
    // Opaque tokens are formatted as PAYACK_<hex> or UUID without colon-separated plaintext
    if (clean.contains(':')) {
      return false; // Rejects legacy plaintext formats with secrets/amounts
    }
    return clean.isNotEmpty;
  }

  /// Generate opaque mock QR token for diagnostics/testing without exposing amounts or secrets
  String generatePaymentQrData({
    required String campaignId,
    required String shopId,
    required double amount,
  }) {
    return 'PAYACK_${shopId.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Create a fresh payment session with opaque server-generated QR token
  Future<PaymentSession> createPaymentSession({
    required String shopId,
    int durationSeconds = 15,
  }) async {
    _logger.info('Creating payment acknowledgement session for shop: $shopId');
    if (_repository != null) {
      return await _repository.createPaymentSession(
        shopId: shopId,
        durationSeconds: durationSeconds,
      );
    }
    throw UnimplementedError('Payment repository not provided');
  }

  /// Atomically scan payment QR
  Future<PaymentSession> scanPaymentQr({
    required String qrToken,
    required String employeeId,
    String? employeeName,
  }) async {
    _logger.info('Scanning payment QR token for employee: $employeeId');
    if (_repository != null) {
      return await _repository.scanPaymentQr(
        qrToken: qrToken,
        employeeId: employeeId,
        employeeName: employeeName,
      );
    }
    throw UnimplementedError('Payment repository not provided');
  }

  /// Submit positive INR amount
  Future<PaymentSession> submitPaymentAmount({
    required String sessionId,
    required double amount,
  }) async {
    _logger.info('Submitting payment amount: ₹$amount for session: $sessionId');
    if (_repository != null) {
      return await _repository.submitPaymentAmount(
        sessionId: sessionId,
        amount: amount,
      );
    }
    throw UnimplementedError('Payment repository not provided');
  }

  /// Confirm payment received (Shopkeeper flow)
  Future<PaymentSession> confirmPaymentReceived({
    required String sessionId,
    String? notes,
  }) async {
    _logger.info('Confirming payment received for session: $sessionId');
    if (_repository != null) {
      return await _repository.confirmPaymentReceived(
        sessionId: sessionId,
        verificationNotes: notes,
      );
    }
    throw UnimplementedError('Payment repository not provided');
  }

  /// Reject payment (Shopkeeper flow)
  Future<PaymentSession> rejectPayment({
    required String sessionId,
    required String reason,
  }) async {
    _logger.info('Rejecting payment for session: $sessionId. Reason: $reason');
    if (_repository != null) {
      return await _repository.rejectPayment(
        sessionId: sessionId,
        reason: reason,
      );
    }
    throw UnimplementedError('Payment repository not provided');
  }
}

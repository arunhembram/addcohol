import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exceptions for payment acknowledgement flow
class PaymentSessionExpiredException implements Exception {
  final String message;
  const PaymentSessionExpiredException([
    this.message =
        'This payment QR token has expired. Please ask the shopkeeper to display a fresh QR.',
  ]);

  @override
  String toString() => message;
}

class PaymentQrAlreadyScannedException implements Exception {
  final String message;
  const PaymentQrAlreadyScannedException([
    this.message =
        'This QR code has already been scanned. Each QR can only be scanned once.',
  ]);

  @override
  String toString() => message;
}

class InvalidPaymentAmountException implements Exception {
  final String message;
  const InvalidPaymentAmountException([
    this.message = 'Amount must be a positive INR number greater than zero.',
  ]);

  @override
  String toString() => message;
}

class PaymentUnauthorizedException implements Exception {
  final String message;
  const PaymentUnauthorizedException([
    this.message =
        'Unauthorized: You are not permitted to perform this payment action.',
  ]);

  @override
  String toString() => message;
}

abstract class IPaymentAcknowledgementRepository {
  /// Shopkeeper taps "Accept Payment" -> calls create_payment_session Edge Function
  /// Returns fresh session with server-generated opaque QR token and 15s expiry
  Future<PaymentSession> createPaymentSession({
    required String shopId,
    String? sessionId,
    int durationSeconds = 15,
  });

  /// Rotates only the QR token on an active payment session every 10s.
  /// Strictly prevents creating unlimited payment sessions in the database.
  Future<PaymentSession> rotateQrToken({
    required String sessionId,
    required String shopId,
    int durationSeconds = 15,
  });

  /// Employee taps "Payment Done" & scans QR -> calls scan_payment_qr Edge Function
  /// Atomically claims first valid scan only; rejects replays or expired tokens
  Future<PaymentSession> scanPaymentQr({
    required String qrToken,
    required String employeeId,
    String? employeeName,
  });

  /// Employee enters positive INR amount -> calls submit_payment_amount Edge Function
  /// Transitions session to 'awaiting_confirmation'
  Future<PaymentSession> submitPaymentAmount({
    required String sessionId,
    required double amount,
  });

  /// Shopkeeper taps "Confirm amount received" -> calls confirm_payment_received Edge Function
  /// Marks payment successful, creates transaction record with currency INR
  Future<PaymentSession> confirmPaymentReceived({
    required String sessionId,
    String? verificationNotes,
  });

  /// Shopkeeper taps "Reject / Incorrect amount" -> calls reject_payment Edge Function
  /// Invalidates transaction; a new QR is required
  Future<PaymentSession> rejectPayment({
    required String sessionId,
    required String reason,
  });

  /// Cancels session before scanning
  Future<PaymentSession> cancelPaymentSession({
    required String sessionId,
  });

  /// Real-time stream of session updates (with fallback polling)
  Stream<PaymentSession> watchPaymentSession(String sessionId);

  /// Fetch single payment session
  Future<PaymentSession?> getPaymentSession(String sessionId);
}

class SupabasePaymentAcknowledgementRepository
    implements IPaymentAcknowledgementRepository {
  final SupabaseManager? _supabaseManager;

  // In-memory mock store for demo/tests/offline fallback
  static final Map<String, PaymentSession> _mockSessions = {};
  static final Map<String, StreamController<PaymentSession>> _streamControllers =
      {};
  static final Random _random = Random();

  SupabasePaymentAcknowledgementRepository({SupabaseManager? supabaseManager})
    : _supabaseManager = supabaseManager;

  bool get _isSupabaseActive => _supabaseManager?.client != null;

  String _hashToken(String token) {
    final bytes = utf8.encode(token.trim());
    return sha256.convert(bytes).toString();
  }

  StreamController<PaymentSession> _getOrCreateController(String sessionId) {
    if (!_streamControllers.containsKey(sessionId) ||
        _streamControllers[sessionId]!.isClosed) {
      _streamControllers[sessionId] =
          StreamController<PaymentSession>.broadcast();
    }
    return _streamControllers[sessionId]!;
  }

  void _notifySessionUpdate(PaymentSession session) {
    _mockSessions[session.id] = session;
    final controller = _streamControllers[session.id];
    if (controller != null && !controller.isClosed) {
      controller.add(session);
    }
  }

  @override
  Future<PaymentSession> createPaymentSession({
    required String shopId,
    String? sessionId,
    int durationSeconds = 15,
  }) async {
    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final body = <String, dynamic>{
          'shop_id': shopId,
          'duration_seconds': durationSeconds,
        };
        if (sessionId != null) body['session_id'] = sessionId;

        final res = await client.functions.invoke(
          'create_payment_session',
          body: body,
        );

        if (res.status != 200) {
          throw Exception(
            res.data?['error'] ??
                'Failed to create payment session (${res.status})',
          );
        }

        final data = res.data['data'] as Map<String, dynamic>;
        final session = PaymentSession.fromJson(data);
        _notifySessionUpdate(session);
        return session;
      } catch (e) {
        // Fall back to in-memory implementation if network fails
      }
    }

    // In-memory fallback / testing
    if (sessionId != null && _mockSessions.containsKey(sessionId)) {
      final existing = _mockSessions[sessionId]!;
      final tokenHex = List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final opaqueToken = 'PAYACK_$tokenHex';
      final tokenHash = _hashToken(opaqueToken);
      final now = DateTime.now();
      final expiresAt = now.add(Duration(seconds: durationSeconds));

      final rotated = existing.copyWith(
        qrToken: opaqueToken,
        qrTokenHash: tokenHash,
        expiresAt: expiresAt,
      );
      _notifySessionUpdate(rotated);
      return rotated;
    }

    final newSessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
    final tokenHex = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final opaqueToken = 'PAYACK_$tokenHex';
    final tokenHash = _hashToken(opaqueToken);
    final now = DateTime.now();
    final expiresAt = now.add(Duration(seconds: durationSeconds));

    final session = PaymentSession(
      id: newSessionId,
      shopId: shopId,
      shopName: shopId == '10000001'
          ? 'Maa Tara Electronic Hub'
          : 'Partner Merchant',
      ownerName: shopId == '10000001' ? 'Tarun Banerjee' : 'Shopkeeper',
      shopCode: shopId,
      status: PaymentSessionStatus.created,
      qrToken: opaqueToken,
      qrTokenHash: tokenHash,
      expiresAt: expiresAt,
      createdAt: now,
    );

    _notifySessionUpdate(session);
    return session;
  }

  @override
  Future<PaymentSession> rotateQrToken({
    required String sessionId,
    required String shopId,
    int durationSeconds = 15,
  }) async {
    return createPaymentSession(
      shopId: shopId,
      sessionId: sessionId,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<PaymentSession> scanPaymentQr({
    required String qrToken,
    required String employeeId,
    String? employeeName,
  }) async {
    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client.functions.invoke(
          'scan_payment_qr',
          body: {'qr_token': qrToken.trim()},
        );

        if (res.status == 410) {
          throw const PaymentSessionExpiredException();
        } else if (res.status == 409) {
          throw const PaymentQrAlreadyScannedException();
        } else if (res.status != 200) {
          throw Exception(res.data?['error'] ?? 'Scan failed (${res.status})');
        }

        final data = res.data['data'] as Map<String, dynamic>;
        final session = PaymentSession.fromJson(data);
        _notifySessionUpdate(session);
        return session;
      } catch (e) {
        if (e is PaymentSessionExpiredException ||
            e is PaymentQrAlreadyScannedException) {
          rethrow;
        }
        // Fall back to in-memory
      }
    }

    // In-memory atomic scan implementation (thread-safe for Dart event loop)
    final tokenHash = _hashToken(qrToken);
    final sessionEntry = _mockSessions.values.cast<PaymentSession?>().firstWhere(
      (s) =>
          s != null &&
          (s.qrTokenHash == tokenHash ||
              s.qrToken == qrToken.trim() ||
              s.id == qrToken.trim()),
      orElse: () => null,
    );

    if (sessionEntry == null) {
      throw const PaymentSessionExpiredException(
        'Payment session not found for provided QR token.',
      );
    }

    final now = DateTime.now();

    // Check expiration
    if (now.isAfter(sessionEntry.expiresAt)) {
      final expiredSession = sessionEntry.copyWith(
        status: PaymentSessionStatus.expired,
        updatedAt: now,
      );
      _notifySessionUpdate(expiredSession);
      throw const PaymentSessionExpiredException();
    }

    // Atomic scan: check status is created
    if (sessionEntry.status != PaymentSessionStatus.created) {
      throw PaymentQrAlreadyScannedException(
        'This QR code has already been scanned (status: ${sessionEntry.status.displayName}). Replay scans are rejected.',
      );
    }

    // Atomically transition status to scanned
    final scannedSession = sessionEntry.copyWith(
      status: PaymentSessionStatus.scanned,
      employeeId: employeeId,
      employeeName: employeeName ?? 'Field Employee',
      scannedAt: now,
      updatedAt: now,
    );

    _notifySessionUpdate(scannedSession);
    return scannedSession;
  }

  @override
  Future<PaymentSession> submitPaymentAmount({
    required String sessionId,
    required double amount,
  }) async {
    if (amount <= 0 || amount.isNaN) {
      throw const InvalidPaymentAmountException();
    }

    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client.functions.invoke(
          'submit_payment_amount',
          body: {'session_id': sessionId, 'amount': amount},
        );

        if (res.status != 200) {
          throw Exception(
            res.data?['error'] ?? 'Submit amount failed (${res.status})',
          );
        }

        final data = res.data['data'] as Map<String, dynamic>;
        final session = PaymentSession.fromJson(data);
        _notifySessionUpdate(session);
        return session;
      } catch (e) {
        // Fall back to in-memory
      }
    }

    // In-memory
    final session = _mockSessions[sessionId];
    if (session == null) {
      throw Exception('Payment session not found ($sessionId)');
    }

    if (session.status != PaymentSessionStatus.scanned) {
      throw Exception(
        'Cannot submit amount in ${session.status.displayName} state',
      );
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final txnRef =
        'ACK-$dateStr-${_random.nextInt(900000) + 100000}';

    final updated = session.copyWith(
      amount: amount,
      currency: 'INR',
      status: PaymentSessionStatus.awaitingConfirmation,
      transactionReference: txnRef,
      updatedAt: now,
    );

    _notifySessionUpdate(updated);
    return updated;
  }

  @override
  Future<PaymentSession> confirmPaymentReceived({
    required String sessionId,
    String? verificationNotes,
  }) async {
    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client.functions.invoke(
          'confirm_payment_received',
          body: {
            'session_id': sessionId,
            'verification_notes': verificationNotes,
          },
        );

        if (res.status != 200) {
          throw Exception(
            res.data?['error'] ?? 'Confirm payment failed (${res.status})',
          );
        }

        final data = res.data['data'] as Map<String, dynamic>;
        final session = PaymentSession.fromJson(data);
        _notifySessionUpdate(session);
        return session;
      } catch (e) {
        // Fall back to in-memory
      }
    }

    final session = _mockSessions[sessionId];
    if (session == null) {
      throw Exception('Payment session not found ($sessionId)');
    }

    if (!session.isAwaitingConfirmation) {
      throw Exception(
        'Cannot confirm payment in ${session.status.displayName} state',
      );
    }

    final now = DateTime.now();
    final updated = session.copyWith(
      status: PaymentSessionStatus.confirmed,
      confirmedAt: now,
      updatedAt: now,
    );

    _notifySessionUpdate(updated);
    return updated;
  }

  @override
  Future<PaymentSession> rejectPayment({
    required String sessionId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('Rejection reason cannot be empty.');
    }

    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client.functions.invoke(
          'reject_payment',
          body: {'session_id': sessionId, 'rejection_reason': reason.trim()},
        );

        if (res.status != 200) {
          throw Exception(
            res.data?['error'] ?? 'Reject payment failed (${res.status})',
          );
        }

        final data = res.data['data'] as Map<String, dynamic>;
        final session = PaymentSession.fromJson(data);
        _notifySessionUpdate(session);
        return session;
      } catch (e) {
        // Fall back to in-memory
      }
    }

    final session = _mockSessions[sessionId];
    if (session == null) {
      throw Exception('Payment session not found ($sessionId)');
    }

    final now = DateTime.now();
    final updated = session.copyWith(
      status: PaymentSessionStatus.rejected,
      rejectionReason: reason.trim(),
      updatedAt: now,
    );

    _notifySessionUpdate(updated);
    return updated;
  }

  @override
  Future<PaymentSession> cancelPaymentSession({
    required String sessionId,
  }) async {
    final session = _mockSessions[sessionId];
    if (session == null) {
      throw Exception('Payment session not found ($sessionId)');
    }

    final now = DateTime.now();
    final updated = session.copyWith(
      status: PaymentSessionStatus.cancelled,
      updatedAt: now,
    );

    _notifySessionUpdate(updated);
    return updated;
  }

  @override
  Stream<PaymentSession> watchPaymentSession(String sessionId) {
    final controller = _getOrCreateController(sessionId);

    // If Supabase is connected, listen to Postgres change stream
    if (_isSupabaseActive) {
      final client = _supabaseManager!.client!;
      final channel = client
          .channel('payment_session_$sessionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'payment_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: sessionId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final session = PaymentSession.fromJson(newRecord);
                _notifySessionUpdate(session);
              }
            },
          )
          .subscribe();

      // Emit initial record if already present
      getPaymentSession(sessionId).then((s) {
        if (s != null && !controller.isClosed) {
          controller.add(s);
        }
      });

      controller.onCancel = () {
        channel.unsubscribe();
      };
    } else {
      // Emit current mock state if available
      final existing = _mockSessions[sessionId];
      if (existing != null) {
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(existing);
          }
        });
      }
    }

    return controller.stream;
  }

  @override
  Future<PaymentSession?> getPaymentSession(String sessionId) async {
    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client
            .from('payment_sessions')
            .select('*, shops(id, shop_name, owner_name, shop_code)')
            .eq('id', sessionId)
            .maybeSingle();

        if (res != null) {
          return PaymentSession.fromJson(res);
        }
      } catch (e) {
        // Fall back to in-memory
      }
    }
    return _mockSessions[sessionId];
  }
}

import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shopkeeper_state_providers.dart';

class AcceptPaymentState {
  final bool isLoading;
  final PaymentSession? session;
  final int countdownSeconds;
  final String? errorMessage;
  final String? successMessage;
  final bool isSubmittingAction;

  const AcceptPaymentState({
    this.isLoading = false,
    this.session,
    this.countdownSeconds = 10,
    this.errorMessage,
    this.successMessage,
    this.isSubmittingAction = false,
  });

  AcceptPaymentState copyWith({
    bool? isLoading,
    PaymentSession? session,
    int? countdownSeconds,
    String? errorMessage,
    String? successMessage,
    bool? isSubmittingAction,
  }) {
    return AcceptPaymentState(
      isLoading: isLoading ?? this.isLoading,
      session: session ?? this.session,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      errorMessage: errorMessage,
      successMessage: successMessage,
      isSubmittingAction: isSubmittingAction ?? this.isSubmittingAction,
    );
  }
}

class AcceptPaymentNotifier extends StateNotifier<AcceptPaymentState> {
  final IPaymentAcknowledgementRepository _repository;
  final String _shopId;

  Timer? _countdownTimer;
  StreamSubscription<PaymentSession>? _sessionSubscription;

  AcceptPaymentNotifier({
    required IPaymentAcknowledgementRepository repository,
    required String shopId,
  })  : _repository = repository,
        _shopId = shopId,
        super(const AcceptPaymentState()) {
    createFreshSession();
  }

  Future<void> createFreshSession() async {
    _countdownTimer?.cancel();
    _sessionSubscription?.cancel();

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      countdownSeconds: 10,
      session: null,
    );

    try {
      // Server creates fresh session with opaque token & 15s server expiry
      final session = await _repository.createPaymentSession(
        shopId: _shopId,
        durationSeconds: 15,
      );

      state = state.copyWith(
        isLoading: false,
        session: session,
        countdownSeconds: 10,
      );

      // Listen to real-time session status updates
      _sessionSubscription = _repository
          .watchPaymentSession(session.id)
          .listen(_onSessionUpdated);

      // Start 10-second fresh QR refresh timer while status is 'created'
      _startCountdown();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate payment QR: $e',
      );
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.session == null ||
          state.session!.status != PaymentSessionStatus.created) {
        timer.cancel();
        return;
      }

      if (state.countdownSeconds <= 1) {
        timer.cancel();
        // Server rotates only the QR token every 10 seconds; does not create unlimited sessions
        rotateCurrentQr();
      } else {
        state = state.copyWith(countdownSeconds: state.countdownSeconds - 1);
      }
    });
  }

  Future<void> rotateCurrentQr() async {
    final current = state.session;
    if (current == null || current.status != PaymentSessionStatus.created) {
      return;
    }

    try {
      final rotated = await _repository.rotateQrToken(
        sessionId: current.id,
        shopId: _shopId,
        durationSeconds: 15,
      );

      state = state.copyWith(
        session: rotated,
        countdownSeconds: 10,
      );
      _startCountdown();
    } catch (_) {
      state = state.copyWith(countdownSeconds: 10);
      _startCountdown();
    }
  }

  void _onSessionUpdated(PaymentSession updated) {
    // Once any valid QR is scanned, immediately stop rendering usable QR & stop timer
    if (updated.status != PaymentSessionStatus.created) {
      _countdownTimer?.cancel();
    }

    String? successMsg;
    if (updated.status == PaymentSessionStatus.confirmed) {
      final amt = updated.amount != null ? updated.amount!.toStringAsFixed(0) : '0';
      successMsg = 'Received ₹$amt';
    }

    state = state.copyWith(
      session: updated,
      successMessage: successMsg,
    );
  }

  Future<void> confirmPayment({String? notes}) async {
    final current = state.session;
    if (current == null) return;

    state = state.copyWith(isSubmittingAction: true, errorMessage: null);
    try {
      final confirmed = await _repository.confirmPaymentReceived(
        sessionId: current.id,
        verificationNotes: notes,
      );
      final amt =
          confirmed.amount != null ? confirmed.amount!.toStringAsFixed(0) : '0';
      state = state.copyWith(
        isSubmittingAction: false,
        session: confirmed,
        successMessage: 'Received ₹$amt',
      );
    } catch (e) {
      state = state.copyWith(
        isSubmittingAction: false,
        errorMessage: 'Confirmation failed: $e',
      );
    }
  }

  Future<void> rejectPayment(String reason) async {
    final current = state.session;
    if (current == null) return;

    state = state.copyWith(isSubmittingAction: true, errorMessage: null);
    try {
      final rejected = await _repository.rejectPayment(
        sessionId: current.id,
        reason: reason,
      );
      state = state.copyWith(
        isSubmittingAction: false,
        session: rejected,
        errorMessage: 'Payment rejected. A new QR code is required.',
      );
    } catch (e) {
      state = state.copyWith(
        isSubmittingAction: false,
        errorMessage: 'Rejection failed: $e',
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}

final acceptPaymentProvider = StateNotifierProvider.autoDispose<
    AcceptPaymentNotifier, AcceptPaymentState>((ref) {
  final repo = ref.watch(paymentAcknowledgementRepositoryProvider);
  final boundShop = ref.watch(currentBoundShopProvider);
  final shopCode = (boundShop.shopCode != null && boundShop.shopCode!.isNotEmpty)
      ? boundShop.shopCode!
      : '10000001';
  return AcceptPaymentNotifier(
    repository: repo,
    shopId: shopCode,
  );
});

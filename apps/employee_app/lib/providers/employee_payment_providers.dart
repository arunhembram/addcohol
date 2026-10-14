import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'employee_state_providers.dart';

enum EmployeePaymentStep {
  scanning,
  enteringAmount,
  awaitingConfirmation,
  confirmed,
  rejected,
}

class EmployeePaymentFlowState {
  final EmployeePaymentStep step;
  final bool isLoading;
  final PaymentSession? session;
  final double? amount;
  final String? errorMessage;
  final String? confirmationMessage;

  const EmployeePaymentFlowState({
    this.step = EmployeePaymentStep.scanning,
    this.isLoading = false,
    this.session,
    this.amount,
    this.errorMessage,
    this.confirmationMessage,
  });

  EmployeePaymentFlowState copyWith({
    EmployeePaymentStep? step,
    bool? isLoading,
    PaymentSession? session,
    double? amount,
    String? errorMessage,
    String? confirmationMessage,
  }) {
    return EmployeePaymentFlowState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      session: session ?? this.session,
      amount: amount ?? this.amount,
      errorMessage: errorMessage,
      confirmationMessage: confirmationMessage,
    );
  }
}

class EmployeePaymentFlowNotifier extends StateNotifier<EmployeePaymentFlowState> {
  final IPaymentAcknowledgementRepository _repository;
  final String _employeeId;
  final String _employeeName;

  StreamSubscription<PaymentSession>? _sessionSubscription;

  EmployeePaymentFlowNotifier({
    required IPaymentAcknowledgementRepository repository,
    required String employeeId,
    required String employeeName,
  })  : _repository = repository,
        _employeeId = employeeId,
        _employeeName = employeeName,
        super(const EmployeePaymentFlowState());

  /// Atomically scan payment QR
  Future<void> scanQrToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final session = await _repository.scanPaymentQr(
        qrToken: cleanToken,
        employeeId: _employeeId,
        employeeName: _employeeName,
      );

      state = state.copyWith(
        isLoading: false,
        session: session,
        step: EmployeePaymentStep.enteringAmount,
      );
    } on PaymentQrAlreadyScannedException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } on PaymentSessionExpiredException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Scan failed: $e',
      );
    }
  }

  /// Submit positive INR amount
  Future<void> submitAmount(double amount) async {
    if (amount <= 0 || amount.isNaN) {
      state = state.copyWith(
        errorMessage: 'Amount must be a positive INR number greater than zero.',
      );
      return;
    }

    final current = state.session;
    if (current == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final updated = await _repository.submitPaymentAmount(
        sessionId: current.id,
        amount: amount,
      );

      state = state.copyWith(
        isLoading: false,
        session: updated,
        amount: amount,
        step: EmployeePaymentStep.awaitingConfirmation,
      );

      // Listen for real-time shopkeeper confirmation or rejection
      _sessionSubscription?.cancel();
      _sessionSubscription = _repository
          .watchPaymentSession(updated.id)
          .listen(_onSessionUpdated);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit amount: $e',
      );
    }
  }

  void _onSessionUpdated(PaymentSession session) {
    if (session.status == PaymentSessionStatus.confirmed) {
      final amt = session.amount != null ? session.amount!.toStringAsFixed(0) : '0';
      final owner = session.ownerName ?? 'shopkeeper';
      state = state.copyWith(
        session: session,
        step: EmployeePaymentStep.confirmed,
        confirmationMessage: '₹$amt paid successfully to $owner',
      );
      _sessionSubscription?.cancel();
    } else if (session.status == PaymentSessionStatus.rejected) {
      state = state.copyWith(
        session: session,
        step: EmployeePaymentStep.rejected,
        errorMessage:
            'Payment rejected by shopkeeper. Reason: ${session.rejectionReason ?? "Incorrect amount"}',
      );
      _sessionSubscription?.cancel();
    } else {
      state = state.copyWith(session: session);
    }
  }

  void reset() {
    _sessionSubscription?.cancel();
    state = const EmployeePaymentFlowState();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }
}

final employeePaymentFlowProvider = StateNotifierProvider.autoDispose<
    EmployeePaymentFlowNotifier, EmployeePaymentFlowState>((ref) {
  final repo = ref.watch(paymentAcknowledgementRepositoryProvider);
  final auth = ref.watch(employeeAuthProvider);
  final employee = auth.currentEmployee;

  return EmployeePaymentFlowNotifier(
    repository: repo,
    employeeId: employee?.id ?? 'emp-20001',
    employeeName: employee?.fullName ?? 'Field Employee',
  );
});

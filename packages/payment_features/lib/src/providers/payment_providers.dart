import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  final repo = ref.watch(paymentAcknowledgementRepositoryProvider);
  return PaymentService(logger: logger, repository: repo);
});

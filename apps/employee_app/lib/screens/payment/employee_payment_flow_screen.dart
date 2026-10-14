import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:payment_features/payment_features.dart';
import '../../providers/employee_payment_providers.dart';

class EmployeePaymentFlowScreen extends ConsumerStatefulWidget {
  const EmployeePaymentFlowScreen({super.key});

  @override
  ConsumerState<EmployeePaymentFlowScreen> createState() =>
      _EmployeePaymentFlowScreenState();
}

class _EmployeePaymentFlowScreenState
    extends ConsumerState<EmployeePaymentFlowScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _manualTokenController = TextEditingController();
  bool _showManualInput = false;

  @override
  void dispose() {
    _amountController.dispose();
    _manualTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeePaymentFlowProvider);
    final notifier = ref.read(employeePaymentFlowProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Done (Field Acknowledgement)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // System Disclaimer
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.neutral300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.neutral700),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Field Payment Acknowledgement only. Does not transfer money via UPI/card.',
                      style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Error Banner
            if (state.errorMessage != null &&
                state.step != EmployeePaymentStep.rejected) ...[
              AppCard(
                backgroundColor: AppColors.error.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // STEP 1: SCANNER
            if (state.step == EmployeePaymentStep.scanning) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      'Scan Shopkeeper QR Code',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scan the dynamic QR displayed on the shopkeeper device.',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 280,
                      child: QrScannerView(
                        onScanned: (token) {
                          if (!state.isLoading) {
                            notifier.scanQrToken(token);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      icon: Icon(
                        _showManualInput ? Icons.camera_alt : Icons.keyboard,
                        size: 16,
                      ),
                      label: Text(
                        _showManualInput
                            ? 'Use Camera Scanner'
                            : 'Enter / Paste Token Manually (Dev/Web)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _showManualInput = !_showManualInput;
                        });
                      },
                    ),
                    if (_showManualInput) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _manualTokenController,
                        decoration: const InputDecoration(
                          labelText: 'QR Token (e.g. PAYACK_...)',
                          hintText: 'Paste scanned opaque token',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Submit Scanned Token',
                        isLoading: state.isLoading,
                        onPressed: () {
                          final token = _manualTokenController.text.trim();
                          if (token.isNotEmpty) {
                            notifier.scanQrToken(token);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ]
            // STEP 2: ENTER POSITIVE INR AMOUNT
            else if (state.step == EmployeePaymentStep.enteringAmount &&
                state.session != null) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.success,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.session!.shopName ?? 'Verified Shop',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Owner: ${state.session!.ownerName ?? "Shopkeeper"} • Code: ${state.session!.shopCode ?? ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    const Text(
                      'Enter Acknowledged Amount',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter the exact positive cash/field amount acknowledged with the shopkeeper.',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        labelText: 'Amount (INR)',
                        hintText: 'e.g. 2500',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    AppButton(
                      label: 'Submit Payment Amount',
                      isLoading: state.isLoading,
                      onPressed: () {
                        final val = double.tryParse(_amountController.text.trim());
                        if (val != null && val > 0) {
                          notifier.submitAmount(val);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid positive INR amount greater than 0.',
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => notifier.reset(),
                    ),
                  ],
                ),
              ),
            ]
            // STEP 3: AWAITING SHOPKEEPER CONFIRMATION
            else if (state.step == EmployeePaymentStep.awaitingConfirmation &&
                state.session != null) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Awaiting shopkeeper confirmation',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submitted ₹${state.amount?.toStringAsFixed(0)} to ${state.session!.ownerName ?? "Shopkeeper"}.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.neutral800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shop',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.neutral600,
                                ),
                              ),
                              Text(
                                state.session!.shopName ?? 'Partner Shop',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Transaction Ref',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.neutral600,
                                ),
                              ),
                              Text(
                                state.session!.transactionReference ??
                                    'Pending...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Waiting for the shopkeeper to tap "Confirm amount received" on their screen...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.neutral600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ]
            // STEP 4: CONFIRMED - Exact Status Message: "₹[amount] paid successfully to [owner name]"
            else if (state.step == EmployeePaymentStep.confirmed &&
                state.session != null) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                backgroundColor: AppColors.success.withValues(alpha: 0.08),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.confirmationMessage ??
                          '₹${state.session!.amount?.toStringAsFixed(0)} paid successfully to ${state.session!.ownerName ?? "Shopkeeper"}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Payment acknowledgement verified and permanently recorded.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (state.session!.transactionReference != null)
                      Text(
                        'Ref: ${state.session!.transactionReference}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Record Another Payment',
                      onPressed: () {
                        _amountController.clear();
                        _manualTokenController.clear();
                        notifier.reset();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Return to Zone Map',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ),
            ]
            // STEP 5: REJECTED
            else if (state.step == EmployeePaymentStep.rejected) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                backgroundColor: AppColors.error.withValues(alpha: 0.08),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cancel_outlined,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Payment Rejected by Shopkeeper',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (state.errorMessage != null)
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.neutral700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'The transaction has been invalidated. Please ask the shopkeeper to display a fresh QR code.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Scan New QR',
                      onPressed: () {
                        _amountController.clear();
                        _manualTokenController.clear();
                        notifier.reset();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Return to Zone Map',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

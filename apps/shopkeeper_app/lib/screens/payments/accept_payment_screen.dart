import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/shopkeeper_payment_providers.dart';

class AcceptPaymentScreen extends ConsumerStatefulWidget {
  const AcceptPaymentScreen({super.key});

  @override
  ConsumerState<AcceptPaymentScreen> createState() => _AcceptPaymentScreenState();
}

class _AcceptPaymentScreenState extends ConsumerState<AcceptPaymentScreen> {
  final TextEditingController _rejectionController = TextEditingController();

  @override
  void dispose() {
    _rejectionController.dispose();
    super.dispose();
  }

  void _showRejectDialog(BuildContext context, AcceptPaymentNotifier notifier) {
    _rejectionController.clear();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please specify the reason for rejecting this payment (e.g. incorrect amount, unauthorized personnel).',
              style: TextStyle(fontSize: 13, color: AppColors.neutral700),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _rejectionController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Received cash does not match entered ₹2,500',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final reason = _rejectionController.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(dialogCtx).pop();
              notifier.rejectPayment(reason);
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(acceptPaymentProvider);
    final notifier = ref.read(acceptPaymentProvider.notifier);
    final theme = Theme.of(context);

    final session = state.session;
    final isCreated = session?.status == PaymentSessionStatus.created;
    final isScannedOrPending = session?.status == PaymentSessionStatus.scanned ||
        session?.status == PaymentSessionStatus.amountSubmitted ||
        session?.status == PaymentSessionStatus.awaitingConfirmation;
    final isConfirmed = session?.status == PaymentSessionStatus.confirmed;
    final isRejected = session?.status == PaymentSessionStatus.rejected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accept Payment'),
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
            // Prominent System Disclaimer Banner
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

            // Loading State
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text('Generating fresh secure QR token...'),
                    ],
                  ),
                ),
              )
            // Error State
            else if (state.errorMessage != null && session == null)
              AppCard(
                backgroundColor: AppColors.error.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: AppColors.error),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Try Again',
                      onPressed: () => notifier.createFreshSession(),
                    ),
                  ],
                ),
              )
            // 1. CREATED STATE: Display Opaque QR with 10s countdown
            else if (isCreated && session?.qrToken != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          'Scan to Acknowledge Payment',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Show this QR code to the field employee',
                          style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Opaque QR Code Container (Never contains secrets/amounts/phones)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: session!.qrToken!,
                            version: QrVersions.auto,
                            size: 220,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF001F24),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF001F24),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // 10-Second Auto-refresh countdown indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                value: state.countdownSeconds / 10.0,
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Fresh QR in ${state.countdownSeconds}s (Server expiry enforced)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Opaque token • Replay protected • No secrets exposed',
                          style: TextStyle(fontSize: 10, color: AppColors.neutral500),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            // 2. SCANNED / PENDING CONFIRMATION STATE: QR is immediately hidden!
            else if (isScannedOrPending && session != null)
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
                            color: AppColors.warning.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment pending confirmation',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'QR scanned. Verify the amount below before confirming.',
                                style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    // Amount Display
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Acknowledged Amount',
                            style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.amount != null
                                ? '₹${session.amount!.toStringAsFixed(0)}'
                                : 'Awaiting Amount Entry...',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: session.amount != null ? AppColors.primary : AppColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Details
                    _DetailRow(
                      label: 'Employee Name',
                      value: session.employeeName ?? 'Field Officer',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Scan Time',
                      value: session.scannedAt != null
                          ? '${session.scannedAt!.hour.toString().padLeft(2, '0')}:${session.scannedAt!.minute.toString().padLeft(2, '0')}:${session.scannedAt!.second.toString().padLeft(2, '0')}'
                          : 'Just now',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Transaction Ref',
                      value: session.transactionReference ?? 'Generating...',
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Action Buttons: Confirm & Reject
                    if (session.amount != null && session.amount! > 0) ...[
                      AppButton(
                        label: 'Confirm amount received',
                        variant: AppButtonVariant.primary,
                        isLoading: state.isSubmittingAction,
                        onPressed: () => notifier.confirmPayment(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Reject / Incorrect amount',
                        variant: AppButtonVariant.outlined,
                        onPressed: state.isSubmittingAction
                            ? null
                            : () => _showRejectDialog(context, notifier),
                      ),
                    ] else
                      const Center(
                        child: Text(
                          'Waiting for employee to enter amount on their device...',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.neutral600),
                        ),
                      ),
                  ],
                ),
              )
            // 3. CONFIRMED STATE: Status Message "Received ₹[amount]"
            else if (isConfirmed && session != null)
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
                      child: const Icon(Icons.check, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.successMessage ?? 'Received ₹${session.amount?.toStringAsFixed(0)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Field payment acknowledgement successfully recorded.',
                      style: TextStyle(fontSize: 13, color: AppColors.neutral700),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (session.transactionReference != null)
                      Text(
                        'Ref: ${session.transactionReference}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Accept Another Payment',
                      onPressed: () => notifier.createFreshSession(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Return to Dashboard',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              )
            // 4. REJECTED STATE: Invalidate transaction; new QR required
            else if (isRejected && session != null)
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
                      child: const Icon(Icons.cancel_outlined, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Payment Rejected',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (session.rejectionReason != null)
                      Text(
                        'Reason: ${session.rejectionReason}',
                        style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Transaction invalidated. A new QR code is required.',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Generate New QR',
                      onPressed: () => notifier.createFreshSession(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Return to Dashboard',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

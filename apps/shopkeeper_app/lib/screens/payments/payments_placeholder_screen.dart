import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/shopkeeper_state_providers.dart';

class PaymentsPlaceholderScreen extends ConsumerWidget {
  const PaymentsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentBoundShopProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Revenue & Payouts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payout Summary Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Partner Rent',
                        style: TextStyle(fontSize: 13, color: AppColors.neutral600),
                      ),
                      AppBadge(
                        label: 'Active Partner',
                        variant: AppBadgeVariant.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '₹${shop.monthlyRent.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payable monthly on 5th for ${shop.activeScreensCount} active display screen(s)',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ShopAd Pay Feature Placeholder Notice
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 36, color: AppColors.primary),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct UPI & QR Payouts (Coming Soon)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Automated bank account settlements and shopkeeper QR revenue collection modules will be enabled in the upcoming release.',
                          style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Past Payout Settlements',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),

            _PayoutHistoryTile(
              month: 'August 2026',
              amount: '₹${shop.monthlyRent.toStringAsFixed(0)}',
              status: 'Transferred via NEFT',
              date: '05 Aug 2026',
            ),
            const SizedBox(height: AppSpacing.xs),
            _PayoutHistoryTile(
              month: 'July 2026',
              amount: '₹${shop.monthlyRent.toStringAsFixed(0)}',
              status: 'Transferred via NEFT',
              date: '05 Jul 2026',
            ),

            const SizedBox(height: AppSpacing.xl),

            AppButton(
              label: 'Accept Field Payment (Dynamic QR)',
              icon: Icons.qr_code_2,
              variant: AppButtonVariant.primary,
              onPressed: () => context.push('/accept-payment'),
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
    );
  }
}

class _PayoutHistoryTile extends StatelessWidget {
  final String month;
  final String amount;
  final String status;
  final String date;

  const _PayoutHistoryTile({
    required this.month,
    required this.amount,
    required this.status,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    month,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '$status • $date',
                    style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                  ),
                ],
              ),
            ],
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.neutral900,
            ),
          ),
        ],
      ),
    );
  }
}

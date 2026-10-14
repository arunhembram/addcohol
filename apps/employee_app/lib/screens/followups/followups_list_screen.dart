import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/employee_state_providers.dart';

class FollowupsListScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const FollowupsListScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<FollowupsListScreen> createState() => _FollowupsListScreenState();
}

class _FollowupsListScreenState extends ConsumerState<FollowupsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _convertFollowupToAgreed(BuildContext context, Shop shop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 48),
        title: const Text('Convert to Agreed Shop'),
        content: Text(
          'Mark "${shop.shopName}" as an Agreed Shop?\n\n'
          'The system will generate an immutable 8-digit Shop Code and activate this shop in your assigned zone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Confirm & Activate',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final empId = ref.read(currentEmployeeIdProvider);
      final updated = await repo.updateFollowupToAgreed(
        employeeId: empId,
        shopId: shop.id,
      );

      ref.invalidate(assignedShopsProvider);
      ref.invalidate(followupsTodayProvider);
      ref.invalidate(overdueFollowupsProvider);

      if (!context.mounted) return;

      // Show Success Dialog with immutable 8-digit Shop Code
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 54),
          title: const Text('Shop Successfully Activated!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Server-Generated Immutable Shop Code for "${updated.shopName}":',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: SelectableText(
                  updated.shopCode ?? '10000001',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'This 8-digit Shop Code has been permanently stored.',
                style: TextStyle(fontSize: 11, color: AppColors.neutral600),
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Done',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert shop: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(followupsTodayProvider);
    final overdueAsync = ref.watch(overdueFollowupsProvider);
    final allShopsAsync = ref.watch(assignedShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Due Today'),
                  const SizedBox(width: 4),
                  todayAsync.maybeWhen(
                    data: (list) => _TabCounterBadge(count: list.length, color: AppColors.secondary),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Overdue'),
                  const SizedBox(width: 4),
                  overdueAsync.maybeWhen(
                    data: (list) => _TabCounterBadge(
                      count: list.length,
                      color: AppColors.error,
                      isAlert: list.isNotEmpty,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Tab(text: 'All Follow-ups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Due Today
          _buildShopsList(
            asyncValue: todayAsync,
            emptyMessage: 'No follow-ups due today in your assigned zones.',
            emptyIcon: Icons.event_available,
          ),

          // Tab 2: Overdue
          _buildShopsList(
            asyncValue: overdueAsync,
            emptyMessage: 'Great job! No overdue follow-ups pending.',
            emptyIcon: Icons.task_alt,
          ),

          // Tab 3: All Follow-ups
          allShopsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (shops) {
              final followups = shops.where((s) => s.isFollowup).toList();
              return _ShopCardsList(
                shops: followups,
                emptyMessage: 'No follow-up shops found in your assigned territory.',
                emptyIcon: Icons.assignment_outlined,
                onConvertToAgreed: (shop) => _convertFollowupToAgreed(context, shop),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopsList({
    required AsyncValue<List<Shop>> asyncValue,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading follow-ups: $err')),
      data: (shops) => _ShopCardsList(
        shops: shops,
        emptyMessage: emptyMessage,
        emptyIcon: emptyIcon,
        onConvertToAgreed: (shop) => _convertFollowupToAgreed(context, shop),
      ),
    );
  }
}

class _TabCounterBadge extends StatelessWidget {
  final int count;
  final Color color;
  final bool isAlert;

  const _TabCounterBadge({
    required this.count,
    required this.color,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.error : color,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ShopCardsList extends StatelessWidget {
  final List<Shop> shops;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(Shop shop) onConvertToAgreed;

  const _ShopCardsList({
    required this.shops,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onConvertToAgreed,
  });

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 56, color: AppColors.neutral400),
            const SizedBox(height: AppSpacing.sm),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.neutral600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: shops.length,
      separatorBuilder: (ctx, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final shop = shops[index];
        final category = ShopCategory.fromString(shop.category);
        final isOverdue = shop.isOverdue;

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? AppColors.error.withValues(alpha: 0.12)
                                : AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Icon(
                            category.icon,
                            size: 18,
                            color: isOverdue ? AppColors.error : AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop.shopName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${category.displayName} • ${shop.ownerName ?? "Unknown Owner"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Countdown or Overdue tag
                  _LiveCountdownTag(
                    nextFollowupDate: shop.nextFollowupDate,
                    isOverdue: isOverdue,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Reason box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: isOverdue
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.neutral300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: isOverdue ? AppColors.error : AppColors.neutral700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Reason: ${shop.followupReason ?? "No reason specified"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOverdue ? AppColors.error : AppColors.neutral800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // Details row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phone: ${shop.phoneNumber ?? "N/A"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.neutral700),
                  ),
                  Text(
                    'Scheduled: ${shop.nextFollowupDate?.toLocal().toString().substring(0, 16) ?? "N/A"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Convert to Agreed Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Convert to Agreed Shop (Generate Code)',
                  variant: AppButtonVariant.primary,
                  icon: Icons.check_circle_outline,
                  onPressed: () => onConvertToAgreed(shop),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveCountdownTag extends StatelessWidget {
  final DateTime? nextFollowupDate;
  final bool isOverdue;

  const _LiveCountdownTag({
    required this.nextFollowupDate,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    if (nextFollowupDate == null) {
      return AppBadge(label: 'Pending', variant: AppBadgeVariant.neutral);
    }

    final diff = nextFollowupDate!.difference(DateTime.now());

    if (diff.isNegative || isOverdue) {
      final hoursOver = diff.inHours.abs();
      final text = hoursOver >= 24
          ? 'OVERDUE: ${(hoursOver / 24).floor()}d ago'
          : 'OVERDUE: ${hoursOver}h ago';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    String countdownStr;
    if (diff.inDays > 0) {
      countdownStr = '${diff.inDays}d ${diff.inHours % 24}h remaining';
    } else if (diff.inHours > 0) {
      countdownStr = '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    } else {
      countdownStr = '${diff.inMinutes}m remaining';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Text(
        countdownStr,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}

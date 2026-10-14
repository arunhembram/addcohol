import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/company_state_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(companyAuthProvider);
    final theme = Theme.of(context);

    // If company is unauthenticated or pending approval, redirect to login
    if (!authState.isAuthenticated || authState.isPendingApproval) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final company = authState.company!;
    final summariesAsync = ref.watch(companyZoneSummariesProvider);
    final canViewDailyProof = company.canViewDailyProof;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company.tradeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              company.legalName,
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/landing'),
            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
            label: const Text('Public Showcase'),
          ),
          IconButton(
            tooltip: 'Account & Sign Out',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _showAccountSheet(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Public Showcase Quick-Access Banner
            InkWell(
              onTap: () => context.push('/landing'),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tabletop QR Stand Showcase: "No more competing for prime locations..."',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Explore live 1st-person mockups with dynamic brand customization & pain point comparisons',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'View Showcase ➔',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Company Welcome Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withAlpha(220)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Portal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                        Text(
                          company.tradeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AppBadge(
                              label: '${company.assignedZoneIds.length} Assigned Zones',
                              variant: AppBadgeVariant.neutral,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            AppBadge(
                              label: canViewDailyProof ? 'Proof Enabled' : 'Proof Hidden',
                              variant: canViewDailyProof
                                  ? AppBadgeVariant.success
                                  : AppBadgeVariant.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Live Network Highlights
            summariesAsync.when(
              data: (summaries) {
                int totalAgreedShops = 0;
                int totalScreens = 0;
                for (final s in summaries) {
                  totalAgreedShops += s.totalAgreedShops;
                  totalScreens += s.totalScreens;
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.map_rounded,
                        color: AppColors.primary,
                        title: 'Assigned Zones',
                        value: summaries.length.toString(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.storefront_rounded,
                        color: AppColors.success,
                        title: 'Agreed Shops',
                        value: totalAgreedShops.toString(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.tv_rounded,
                        color: Colors.deepPurple,
                        title: 'Active Screens',
                        value: totalScreens.toString(),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Navigation Feature Cards
            Text(
              'Territory & Campaign Views',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildNavCard(
              context: context,
              icon: Icons.map_outlined,
              iconColor: AppColors.primary,
              title: 'Assigned Territory Map (Read-Only)',
              subtitle: 'View boundaries and active partner shop pins in your assigned zones',
              route: '/map',
            ),
            _buildNavCard(
              context: context,
              icon: Icons.storefront_outlined,
              iconColor: AppColors.success,
              title: 'Agreed & Active Shops Directory',
              subtitle: 'Search and inspect partner shops, categories, and installed screens',
              route: '/shops',
            ),
            _buildNavCard(
              context: context,
              icon: Icons.bar_chart_rounded,
              iconColor: Colors.deepPurple,
              title: 'Zone Summaries & Category Breakdown',
              subtitle: 'Active shop metrics, screen counts, and optional proof status per zone',
              route: '/summary',
            ),
            _buildNavCard(
              context: context,
              icon: Icons.assessment_outlined,
              iconColor: Colors.teal,
              title: 'Campaign Performance & Audit Reports',
              subtitle: 'Cross-zone distribution table, category reach, and compliance audits',
              route: '/reports',
            ),
            const SizedBox(height: AppSpacing.md),

            // Privacy Assurance Footer
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.neutral300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.shield_outlined, size: 20, color: AppColors.neutral700),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Company Security & Privacy Rules:\n'
                      '• Only agreed & active partner shops inside assigned zones are accessible.\n'
                      '• Leads, follow-ups, employee IDs, Aadhaar records, and private storage paths are completely excluded by RLS.',
                      style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.neutral700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.neutral200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(4),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountSheet(BuildContext context, WidgetRef ref) {
    final company = ref.read(companyAuthProvider).company;
    if (company == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Company Account Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.domain_rounded),
                title: Text(company.tradeName),
                subtitle: Text('Legal: ${company.legalName}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android_rounded),
                title: Text(company.contactPhone ?? 'N/A'),
                subtitle: Text('Email: ${company.contactEmail}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text('Account ID: ${company.id}'),
                subtitle: Text(
                  'Feature Flag: can_view_daily_proof = ${company.canViewDailyProof}',
                  style: TextStyle(
                    color: company.canViewDailyProof ? AppColors.success : AppColors.neutral600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Sign Out',
                variant: AppButtonVariant.secondary,
                icon: Icons.logout_rounded,
                onPressed: () {
                  ref.read(companyAuthProvider.notifier).logout();
                  Navigator.of(ctx).pop();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

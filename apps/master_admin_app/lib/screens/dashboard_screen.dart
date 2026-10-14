import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/master_admin_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(adminAuthProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Master Admin Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'প্রধান প্রশাসন ড্যাশবোর্ড',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Light/Dark Theme',
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(adminAuthProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Master Admin Identity Banner
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.shield, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.fullName ?? 'Master Controller',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${authState.user?.email ?? "master@shopad.com"} • ID: ${authState.user?.displayId ?? "10000"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge(label: 'Master Admin', variant: AppBadgeVariant.success),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Metrics Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'System Overview / সিস্টেম পরিসংখ্যান',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Live Database Status',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Metrics Grid (6 required KPI counters)
            statsAsync.when(
              data: (stats) => GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.45,
                children: [
                  _MetricCard(
                    title: 'Total Zones',
                    subTitle: 'মোট জোন',
                    value: stats.totalZones.toString(),
                    icon: Icons.map,
                    color: Colors.blue,
                    onTap: () => context.push('/zones'),
                  ),
                  _MetricCard(
                    title: 'Total Admins',
                    subTitle: 'মোট অ্যাডমিন',
                    value: stats.totalAdmins.toString(),
                    icon: Icons.manage_accounts,
                    color: Colors.purple,
                    onTap: () => context.push('/admins/assign'),
                  ),
                  _MetricCard(
                    title: 'Total Employees',
                    subTitle: 'ফিল্ড কর্মী',
                    value: stats.totalEmployees.toString(),
                    icon: Icons.badge_outlined,
                    color: Colors.indigo,
                    onTap: null, // Employee creation not allowed in Master Admin
                  ),
                  _MetricCard(
                    title: 'Total Shops',
                    subTitle: 'নিবন্ধিত দোকান',
                    value: stats.totalShops.toString(),
                    icon: Icons.storefront,
                    color: Colors.teal,
                    onTap: () => context.push('/zones'),
                  ),
                  _MetricCard(
                    title: 'Follow-ups Today',
                    subTitle: 'আজকের ফলো-আপ',
                    value: stats.followupsDueToday.toString(),
                    icon: Icons.event_available,
                    color: Colors.orange,
                    onTap: () => context.push('/audit'),
                  ),
                  _MetricCard(
                    title: 'Payments Awaiting',
                    subTitle: 'অপেক্ষমাণ পেমেন্ট',
                    value: stats.paymentsAwaitingConfirmation.toString(),
                    icon: Icons.pending_actions,
                    color: Colors.deepOrange,
                    onTap: () => context.push('/audit'),
                  ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: AppLoadingIndicator(),
                ),
              ),
              error: (err, _) => AppErrorView(
                title: 'Error loading stats',
                message: err.toString(),
                onRetry: () => ref.refresh(dashboardStatsProvider),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Management Quick Action Cards
            Text(
              'Master Controls / প্রধান নিয়ন্ত্রণসমূহ',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Zone Management & Maps / জোন ব্যবস্থাপনা ও মানচিত্র',
              subtitle: 'Create polygons, edit vertices, inspect active zones',
              icon: Icons.layers_outlined,
              iconColor: Colors.blue,
              onTap: () => context.push('/zones'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Interactive Zones Map / মানচিত্রে জোন পরিদর্শন',
              subtitle: 'LOD zoom, dynamic zone tracking, shop pins & boundaries',
              icon: Icons.map_rounded,
              iconColor: Colors.indigo,
              onTap: () => context.push('/zones/map'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Admin Directory & Codes / অ্যাডমিন তালিকা ও অ্যাক্সেস কোড',
              subtitle: 'Generate 5-digit login codes, manage unpaired/active admins & call directly',
              icon: Icons.badge_outlined,
              iconColor: Colors.deepPurple,
              onTap: () => context.push('/admins'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Create Admin / নতুন অ্যাডমিন তৈরি',
              subtitle: 'Aadhaar KYC capture, consent record, 5-digit Display ID',
              icon: Icons.person_add_alt_1,
              iconColor: Colors.green,
              onTap: () => context.push('/admins/create'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Assign Admin to Zones / অ্যাডমিন জোন বণ্টন',
              subtitle: 'Allocate controlled geographical zones to Admin accounts',
              icon: Icons.assignment_ind_outlined,
              iconColor: Colors.purple,
              onTap: () => context.push('/admins/assign'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Company Partnerships / কোম্পানি ও বিজ্ঞাপন পার্টনার',
              subtitle: 'Manage advertising companies & assign entire zones',
              icon: Icons.business_outlined,
              iconColor: Colors.teal,
              onTap: () => context.push('/companies'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Weekly Bookings & Campaign Slots / সমস্ত উইকলি বুকিং ও অগ্রগতি',
              subtitle: 'View booked weekly slots, zone cards, task proofs & admin escalation',
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF0284C7),
              onTap: () => context.push('/bookings'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Distribution Materials Catalog / বিতরণ সামগ্রী ক্যাটালগ',
              subtitle: 'Manage central supplies (Cello Tape, Marker Pen, Stand) for all zones',
              icon: Icons.inventory_2_outlined,
              iconColor: Colors.deepOrange,
              onTap: () => context.push('/distribution/materials'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'Audit Logs & Reporting / অডিট লগ ও রিপোর্ট',
              subtitle: 'Full immutable compliance trail, system activities & stats',
              icon: Icons.history_edu,
              iconColor: Colors.amber.shade800,
              onTap: () => context.push('/audit'),
            ),
            const SizedBox(height: AppSpacing.sm),

            _ActionTile(
              title: 'System Health Diagnostics / সিস্টেম স্বাস্থ্য',
              subtitle: 'Inspect database connectivity, env variables & latency',
              icon: Icons.health_and_safety_outlined,
              iconColor: Colors.redAccent,
              onTap: () => context.push('/health'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String subTitle;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.subTitle,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.radiusMd,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.radiusMd,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
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
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

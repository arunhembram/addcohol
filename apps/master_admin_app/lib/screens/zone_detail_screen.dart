import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/master_admin_providers.dart';

class ZoneDetailScreen extends ConsumerWidget {
  final String zoneId;

  const ZoneDetailScreen({super.key, required this.zoneId});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _toggleArchive(BuildContext context, WidgetRef ref, Zone zone) async {
    final newStatus = !zone.isArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus ? 'Archive Zone?' : 'Unarchive Zone?'),
        content: Text(
          newStatus
              ? 'Archiving will hide this zone from active operations and disable new shop creation.'
              : 'This zone will be restored to active operational status.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(masterAdminRepositoryProvider);
      await repo.archiveZone(zone.id, newStatus);
      ref.invalidate(zonesListProvider);
      ref.invalidate(zoneDetailProvider(zone.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zone ${newStatus ? 'archived' : 'restored'} successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final zoneAsync = ref.watch(zoneDetailProvider(zoneId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Details / জোনের বিবরণ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(zoneDetailProvider(zoneId)),
          ),
        ],
      ),
      body: zoneAsync.when(
        data: (zone) {
          if (zone == null) {
            return AppErrorView(
              title: 'Zone Not Found',
              message: 'The requested zone could not be located in database.',
              retryLabel: 'Return to Zone List',
              onRetry: () => context.go('/zones'),
            );
          }

          final zoneColor = _parseColor(zone.colorHex);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Header Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(color: zoneColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            zone.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (zone.isArchived)
                          AppBadge(label: 'Archived', variant: AppBadgeVariant.neutral)
                        else if (zone.isActive)
                          AppBadge(label: 'Active', variant: AppBadgeVariant.success)
                        else
                          AppBadge(label: 'Inactive', variant: AppBadgeVariant.warning),
                      ],
                    ),
                    if (zone.description != null && zone.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        zone.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),

                    // Quick Specs
                    _SpecRow(icon: Icons.fingerprint, label: 'Zone ID:', value: zone.id),
                    const SizedBox(height: 6),
                    _SpecRow(
                      icon: Icons.manage_accounts,
                      label: 'Assigned Admin:',
                      value: zone.assignedAdminName ?? 'None (Unassigned)',
                      highlight: zone.assignedAdminName != null,
                    ),
                    const SizedBox(height: 6),
                    _SpecRow(
                      icon: Icons.business,
                      label: 'Assigned Company:',
                      value: zone.assignedCompanyName ?? 'None (Unassigned)',
                    ),
                    const SizedBox(height: 6),
                    _SpecRow(
                      icon: Icons.storefront,
                      label: 'Active Shops:',
                      value: '${zone.shopCount} registered shop(s)',
                    ),
                    const SizedBox(height: 6),
                    _SpecRow(
                      icon: Icons.timeline,
                      label: 'Polygon Vertices:',
                      value: '${zone.vertices.length} boundary points',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Edit Zone Map / সম্পাদনা',
                      icon: Icons.edit_location_alt,
                      onPressed: () => context.push('/zones/${zone.id}/edit'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _toggleArchive(context, ref, zone),
                    icon: Icon(
                      zone.isArchived ? Icons.unarchive : Icons.archive,
                      color: zone.isArchived ? Colors.green : Colors.red,
                    ),
                    label: Text(zone.isArchived ? 'Restore' : 'Archive'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Polygon Vertices List Card
              Text(
                'Boundary Polygon Vertices / বহুভুজ শীর্ষবিন্দুর স্থানাঙ্ক',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'At least 3 vertices required. All vertices are server-validated before zone save.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: zone.vertices.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final v = zone.vertices[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: zoneColor.withAlpha(40),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: zoneColor,
                          ),
                        ),
                      ),
                      title: Text(
                        'Latitude: ${v.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Longitude: ${v.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      trailing: Text(
                        'Order #${v.sequenceOrder}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (err, _) => AppErrorView(
          title: 'Error loading zone',
          message: err.toString(),
          onRetry: () => ref.refresh(zoneDetailProvider(zoneId)),
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

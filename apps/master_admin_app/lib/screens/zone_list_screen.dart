import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/master_admin_providers.dart';

class ZoneListScreen extends ConsumerStatefulWidget {
  const ZoneListScreen({super.key});

  @override
  ConsumerState<ZoneListScreen> createState() => _ZoneListScreenState();
}

class _ZoneListScreenState extends ConsumerState<ZoneListScreen> {
  String _filter = 'active'; // 'all', 'active', 'archived'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zonesAsync = ref.watch(zonesListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Map / মানচিত্রে ফিরুন',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Zone Management / জোন তালিকা'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Interactive Map View / মানচিত্র পরিদর্শন',
            onPressed: () => context.push('/zones/map'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(zonesListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/zones/create'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Create Zone / নতুন জোন'),
      ),
      body: Column(
        children: [
          // Filter Chips and Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search zones by name or admin...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Active / সক্রিয়'),
                      selected: _filter == 'active',
                      onSelected: (_) => setState(() => _filter = 'active'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilterChip(
                      label: const Text('All / সমস্ত'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilterChip(
                      label: const Text('Archived / সংরক্ষিত'),
                      selected: _filter == 'archived',
                      onSelected: (_) => setState(() => _filter = 'archived'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: zonesAsync.when(
              data: (zones) {
                final filtered = zones.where((z) {
                  if (_filter == 'active' && (z.isArchived || !z.isActive)) return false;
                  if (_filter == 'archived' && !z.isArchived) return false;
                  if (_searchQuery.isNotEmpty) {
                    final matchName = z.name.toLowerCase().contains(_searchQuery);
                    final matchAdmin =
                        z.assignedAdminName?.toLowerCase().contains(_searchQuery) ?? false;
                    return matchName || matchAdmin;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No zones found / কোনো জোন পাওয়া যায়নি',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Tap the button below to draw and create your first zone polygon.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final zone = filtered[index];
                    return _ZoneListItem(zone: zone);
                  },
                );
              },
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (err, _) => AppErrorView(
                title: 'Failed to load zones',
                message: err.toString(),
                onRetry: () => ref.refresh(zonesListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneListItem extends StatelessWidget {
  final Zone zone;

  const _ZoneListItem({required this.zone});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zoneColor = _parseColor(zone.colorHex);

    return InkWell(
      onTap: () => context.push('/zones/${zone.id}'),
      borderRadius: AppRadii.radiusMd,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: zoneColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    zone.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (zone.isArchived)
                  AppBadge(label: 'Archived', variant: AppBadgeVariant.neutral)
                else if (zone.isActive)
                  AppBadge(label: 'Active', variant: AppBadgeVariant.success)
                else
                  AppBadge(label: 'Inactive', variant: AppBadgeVariant.warning),
                const SizedBox(width: 8),
                const Icon(Icons.map_outlined, color: Colors.blue, size: 20),
              ],
            ),
            if (zone.description != null && zone.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                zone.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      zone.assignedAdminName ?? 'Unassigned Admin',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: zone.assignedAdminName != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: zone.assignedAdminName != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.storefront, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${zone.shopCount} shops',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.polyline, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text('${zone.vertices.length} vertices', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            if (zone.assignedCompanyName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Company: ${zone.assignedCompanyName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

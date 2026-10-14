import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_state_providers.dart';


class ShopsOverviewScreen extends ConsumerStatefulWidget {
  const ShopsOverviewScreen({super.key});

  @override
  ConsumerState<ShopsOverviewScreen> createState() => _ShopsOverviewScreenState();
}

class _ShopsOverviewScreenState extends ConsumerState<ShopsOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedZoneId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(controlledShopsProvider);
    final followupsAsync = ref.watch(controlledFollowupsProvider);
    final controlledZonesAsync = ref.watch(controlledZonesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controlled Shops & Follow-ups'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.storefront_outlined),
              text: 'Shops (${shopsAsync.maybeWhen(data: (l) => l.length, orElse: () => 0)})',
            ),
            Tab(
              icon: const Icon(Icons.calendar_today_outlined),
              text: 'Follow-ups (${followupsAsync.maybeWhen(data: (l) => l.length, orElse: () => 0)})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search shops, codes, notes...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 8,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                controlledZonesAsync.maybeWhen(
                  data: (zones) => DropdownButton<String?>(
                    value: _selectedZoneId,
                    hint: const Text('All Zones'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Zones')),
                      ...zones.map(
                        (z) => DropdownMenuItem(value: z.id, child: Text(z.name)),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedZoneId = val),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Shops Tab
                shopsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (allShops) {
                    final filtered = allShops.where((s) {
                      if (_selectedZoneId != null && s.zoneId != _selectedZoneId) {
                        return false;
                      }
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final nameMatch = s.shopName.toLowerCase().contains(q);
                        final codeMatch = s.shopCode?.contains(q) ?? false;
                        final catMatch = s.category.toLowerCase().contains(q);
                        if (!nameMatch && !codeMatch && !catMatch) return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No shops found in controlled zones.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, idx) {
                        final shop = filtered[idx];
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              shop.shopName,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.xs),
                                            AppBadge(
                                              label: 'Code: ${shop.shopCode ?? "N/A"}',
                                              variant: AppBadgeVariant.neutral,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${shop.category} • ${shop.address}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.neutral600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppBadge(
                                    label: shop.status.toUpperCase(),
                                    variant: shop.status == 'active'
                                        ? AppBadgeVariant.success
                                        : AppBadgeVariant.warning,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Zone: ${shop.zoneName ?? shop.zoneId ?? "Unknown"}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Screens: ${shop.activeScreensCount} • Rent: ₹${shop.monthlyRent.toStringAsFixed(0)}/mo',
                                    style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                // 2. Follow-ups Tab
                followupsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (allFollowups) {
                    final filtered = allFollowups.where((f) {
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final shopMatch = f.shopName.toLowerCase().contains(q);
                        final empMatch = f.employeeName.toLowerCase().contains(q);
                        final notesMatch = f.notes.toLowerCase().contains(q);
                        if (!shopMatch && !empMatch && !notesMatch) return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No follow-ups recorded in controlled zones.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, idx) {
                        final fup = filtered[idx];
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.assignment_outlined, size: 20, color: AppColors.primary),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      fup.shopName,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  AppBadge(
                                    label: fup.outcome,
                                    variant: fup.outcome.toLowerCase().contains('completed')
                                        ? AppBadgeVariant.success
                                        : AppBadgeVariant.info,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Logged by: ${fup.employeeName}',
                                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                fup.notes,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (fup.nextFollowupDate != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    const Icon(Icons.event, size: 14, color: AppColors.neutral500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Next Due: ${fup.nextFollowupDate!.toLocal().toString().split(" ")[0]}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

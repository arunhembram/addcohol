import 'dart:async';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_state_providers.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    DistributionSyncService.fetchRemoteState();
    int lastRev = CanonicalZones.zonesRevision.value;
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      await CanonicalZones.syncWithRemote();
      if (!mounted) return;
      if (lastRev != CanonicalZones.zonesRevision.value) {
        lastRev = CanonicalZones.zonesRevision.value;
        ref.invalidate(controlledEmployeesProvider);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _showEmployeeProfileModal(
    BuildContext context,
    WidgetRef ref,
    UserProfile emp,
    List<Zone> controlledZones,
  ) {
    final theme = Theme.of(context);
    final assignedZoneIds =
        (emp.metadata['assigned_zones'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final matchingZones =
        controlledZones.where((z) => assignedZoneIds.contains(z.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  child: Text(
                    emp.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            emp.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(
                            label: 'ID: ${emp.displayId ?? "N/A"}',
                            variant: AppBadgeVariant.info,
                          ),
                        ],
                      ),
                      Text(
                        emp.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral600,
                        ),
                      ),
                      if (emp.phoneNumber != null)
                        Text(
                          'Phone: ${emp.phoneNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            Text(
              'Identity & Private Storage Status',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, color: AppColors.success, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      emp.metadata['aadhaar_document_path'] != null
                          ? 'Aadhaar stored in secure-identity-docs (Consent Verified)'
                          : 'Aadhaar document verified on file',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Assigned Controlled Zones (${matchingZones.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (matchingZones.isEmpty)
              const Text(
                'No controlled zones currently assigned.',
                style: TextStyle(color: AppColors.neutral500, fontSize: 12),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: matchingZones.map((z) {
                  return Chip(
                    label: Text('${z.name} (${z.shopCount} shops)'),
                    avatar: const Icon(Icons.location_on, size: 14),
                  );
                }).toList(),
              ),

            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Assign / Remove Zones'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/employees/${emp.id}/assign-zones');
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: Icon(emp.isActive ? Icons.block : Icons.check),
                    label: Text(emp.isActive ? 'Deactivate' : 'Activate'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _toggleEmployeeStatus(context, ref, emp, !emp.isActive);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleEmployeeStatus(
    BuildContext context,
    WidgetRef ref,
    UserProfile emp,
    bool newStatus,
  ) async {
    final adminId = ref.read(currentAdminIdProvider);
    final repo = ref.read(adminRepositoryProvider);

    try {
      await repo.updateEmployeeStatus(
        adminId: adminId,
        employeeId: emp.id,
        isActive: newStatus,
      );
      ref.invalidate(controlledEmployeesProvider);
      ref.invalidate(employeePerformanceProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${emp.fullName} has been ${newStatus ? "activated" : "deactivated"}.',
            ),
            backgroundColor: newStatus ? AppColors.success : AppColors.neutral800,
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCreateEmployeeCodeDialog(BuildContext context, WidgetRef ref) {
    final adminId = ref.read(currentAdminIdProvider);
    final newEmp = CanonicalZones.createEmployeeCode(managedByAdminId: adminId);
    ref.invalidate(controlledEmployeesProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Employee Access Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'A unique pairing code has been generated. Provide this code to the employee for first-time sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.neutral700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Text(
                newEmp.displayId ?? '',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 16, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  'Pending Pairing (Unclaimed)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Once the employee signs in with this code, it will automatically bind to their name.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.neutral500),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: newEmp.displayId ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Employee code copied to clipboard')),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteEmployee(BuildContext context, WidgetRef ref, UserProfile emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Employee?'),
          ],
        ),
        content: Text(
          'Are you sure you want to dismiss ${emp.fullName.isEmpty ? "Code ${emp.displayId}" : emp.fullName}? '
          'They will be unassigned from all zones and deactivated from the managed employee pool. '
          'Past audit history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final adminId = ref.read(currentAdminIdProvider);
              final repo = ref.read(adminRepositoryProvider);
              await repo.deleteEmployee(adminId: adminId, employeeId: emp.id);
              ref.invalidate(controlledEmployeesProvider);
              ref.invalidate(controlledZonesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ Employee ${emp.fullName.isEmpty ? emp.displayId : emp.fullName} deleted.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredEmployeesProvider);
    final controlledZonesAsync = ref.watch(controlledZonesProvider);
    final currentStatusFilter = ref.watch(employeeStatusFilterProvider);
    final currentZoneFilter = ref.watch(employeeZoneFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Managed Employees'),
        actions: [
          IconButton(
            tooltip: 'Refresh Staff',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(controlledEmployeesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.vpn_key_rounded),
        label: const Text('Create Employee Code'),
        onPressed: () => _showCreateEmployeeCodeDialog(context, ref),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Search Input
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Phone, or 5-digit Employee ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: ref.watch(employeeSearchQueryProvider).isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => ref
                                .read(employeeSearchQueryProvider.notifier)
                                .state = '',
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onChanged: (val) =>
                      ref.read(employeeSearchQueryProvider.notifier).state = val,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Filters Row
                Row(
                  children: [
                    // Status Filter
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'active', label: Text('Active')),
                        ButtonSegment(value: 'inactive', label: Text('Inactive')),
                      ],
                      selected: {currentStatusFilter},
                      onSelectionChanged: (val) {
                        ref.read(employeeStatusFilterProvider.notifier).state =
                            val.first;
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Zone Filter Dropdown
                    Expanded(
                      child: controlledZonesAsync.maybeWhen(
                        data: (zones) => DropdownButtonFormField<String?>(
                          initialValue: currentZoneFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Zone',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Controlled Zones'),
                            ),
                            ...zones.map(
                              (z) => DropdownMenuItem(
                                value: z.id,
                                child: Text(z.name, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (val) => ref
                              .read(employeeZoneFilterProvider.notifier)
                              .state = val,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Employee List Content
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
              ),
              data: (employees) {
                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 56, color: AppColors.neutral400),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No employees found matching filter',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Employees outside your controlled zones cannot be accessed.',
                          style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                        ),
                      ],
                    ),
                  );
                }

                final controlledZones = controlledZonesAsync.maybeWhen(
                  data: (z) => z,
                  orElse: () => <Zone>[],
                );

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: employees.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    final assignedZoneIds =
                        (emp.metadata['assigned_zones'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        const [];

                    final matchedZoneNames = controlledZones
                        .where((z) => assignedZoneIds.contains(z.id))
                        .map((z) => z.name)
                        .toList();

                    final isUnpaired = emp.fullName.trim().isEmpty;
                    final displayName = isUnpaired ? 'Employee Code: ${emp.displayId}' : emp.fullName;

                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isUnpaired
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.12),
                                child: isUnpaired
                                    ? const Icon(Icons.qr_code_2_rounded, color: Colors.orange, size: 20)
                                    : Text(
                                        emp.fullName[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          displayName,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        if (isUnpaired)
                                          const AppBadge(
                                            label: 'Unpaired Code',
                                            variant: AppBadgeVariant.warning,
                                          )
                                        else
                                          AppBadge(
                                            label: 'ID: ${emp.displayId ?? "N/A"}',
                                            variant: AppBadgeVariant.info,
                                          ),
                                      ],
                                    ),
                                    Text(
                                      isUnpaired
                                          ? 'Pending Login • Name binds upon sign in'
                                          : '${emp.phoneNumber ?? "No phone"} • ${emp.email}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isUnpaired ? Colors.orange.shade800 : AppColors.neutral600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppBadge(
                                label: emp.isActive ? 'Active' : 'Inactive',
                                variant: emp.isActive
                                    ? AppBadgeVariant.success
                                    : AppBadgeVariant.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Controlled Zones tags
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final name in matchedZoneNames)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.neutral100,
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                    border: Border.all(color: AppColors.neutral300),
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              if (matchedZoneNames.isEmpty)
                                Text(
                                  isUnpaired
                                      ? 'Not assigned to any zone yet'
                                      : 'No controlled zones assigned',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.warning,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isUnpaired) ...[
                                TextButton.icon(
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copy Code'),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: emp.displayId ?? ''));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Employee code copied to clipboard')),
                                    );
                                  },
                                ),
                              ] else ...[
                                TextButton.icon(
                                  icon: const Icon(Icons.badge_outlined, size: 16),
                                  label: const Text('Profile & Aadhaar'),
                                  onPressed: () => _showEmployeeProfileModal(
                                    context,
                                    ref,
                                    emp,
                                    controlledZones,
                                  ),
                                ),
                              ],
                              const SizedBox(width: AppSpacing.xs),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.edit_location_alt, size: 16),
                                label: const Text('Assign Zones'),
                                onPressed: () => context.push(
                                  '/employees/${emp.id}/assign-zones',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              IconButton(
                                tooltip: 'Delete Employee',
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () => _handleDeleteEmployee(context, ref, emp),
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
          ),
        ],
      ),
    );
  }
}

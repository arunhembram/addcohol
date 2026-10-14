import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/master_admin_providers.dart';

class AssignAdminZonesScreen extends ConsumerStatefulWidget {
  final String? initialAdminId;

  const AssignAdminZonesScreen({super.key, this.initialAdminId});

  @override
  ConsumerState<AssignAdminZonesScreen> createState() => _AssignAdminZonesScreenState();
}

class _AssignAdminZonesScreenState extends ConsumerState<AssignAdminZonesScreen> {
  String? _selectedAdminId;
  final Set<String> _selectedZoneIds = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedAdminId = widget.initialAdminId;
    if (_selectedAdminId != null) {
      _loadAdminAssignments(_selectedAdminId!);
    }
  }

  Future<void> _loadAdminAssignments(String adminId) async {
    setState(() => _isLoading = true);
    final repo = ref.read(masterAdminRepositoryProvider);
    final assignedIds = await repo.getAssignedZoneIdsForAdmin(adminId);
    if (mounted) {
      setState(() {
        _selectedZoneIds.clear();
        _selectedZoneIds.addAll(assignedIds);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAssignments() async {
    if (_selectedAdminId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an Admin account first.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(masterAdminRepositoryProvider);
      await repo.assignAdminToZones(_selectedAdminId!, _selectedZoneIds.toList());

      ref.invalidate(zonesListProvider);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned ${_selectedZoneIds.length} zone(s) to Admin / অ্যাডমিনকে সফলভাবে জোন বণ্টন করা হয়েছে।',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save assignments: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminsAsync = ref.watch(adminsListProvider);
    final zonesAsync = ref.watch(zonesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Admin to Zones / অ্যাডমিন জোন বণ্টন'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save Assignments',
            onPressed: _isSaving ? null : _saveAssignments,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Admin Selection Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Admin / অ্যাডমিন নির্বাচন করুন',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                adminsAsync.when(
                  data: (admins) {
                    if (admins.isEmpty) {
                      return const Text('No Admins available. Please create an Admin first.');
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedAdminId,
                      decoration: const InputDecoration(
                        labelText: 'Administrator',
                        prefixIcon: Icon(Icons.manage_accounts),
                        border: OutlineInputBorder(),
                      ),
                      items: admins.map((a) {
                        return DropdownMenuItem<String>(
                          value: a.id,
                          child: Text('${a.fullName} (Display ID: ${a.displayId ?? "N/A"})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedAdminId = val);
                          _loadAdminAssignments(val);
                        }
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading admins: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Zone Selection Section
          Text(
            'Operational Zones / কার্যপরিচালনা জোন নির্বাচন',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Admins can only assign employees to zones allocated to them by Master Admin.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (_isLoading)
            const Center(
              child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: AppLoadingIndicator()),
            )
          else
            zonesAsync.when(
              data: (zones) {
                final activeZones = zones.where((z) => !z.isArchived).toList();
                if (activeZones.isEmpty) {
                  return const AppCard(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: Text('No active zones available to assign.')),
                  );
                }

                return AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeZones.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final zone = activeZones[index];
                      final isChecked = _selectedZoneIds.contains(zone.id);

                      return CheckboxListTile(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedZoneIds.add(zone.id);
                            } else {
                              _selectedZoneIds.remove(zone.id);
                            }
                          });
                        },
                        title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${zone.shopCount} shops • Current: ${zone.assignedAdminName ?? "Unassigned"}',
                          style: TextStyle(
                            color: zone.assignedAdminId == _selectedAdminId
                                ? Colors.green
                                : theme.colorScheme.outline,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => Text('Error loading zones: $e'),
            ),
          const SizedBox(height: AppSpacing.lg),

          AppButton(
            label: _isSaving ? 'Saving...' : 'Save Zone Allocation / বরাদ্দ নিশ্চিত করুন',
            icon: Icons.save,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _saveAssignments,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

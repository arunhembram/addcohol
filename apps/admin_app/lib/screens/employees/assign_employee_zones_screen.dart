import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_state_providers.dart';

class AssignEmployeeZonesScreen extends ConsumerStatefulWidget {
  final String employeeId;

  const AssignEmployeeZonesScreen({super.key, required this.employeeId});

  @override
  ConsumerState<AssignEmployeeZonesScreen> createState() =>
      _AssignEmployeeZonesScreenState();
}

class _AssignEmployeeZonesScreenState
    extends ConsumerState<AssignEmployeeZonesScreen> {
  final Set<String> _selectedZoneIds = {};
  bool _isLoaded = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(controlledEmployeesProvider);
    final controlledZonesAsync = ref.watch(controlledZonesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Controlled Zones'),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
        ),
        data: (employees) {
          final employee = employees.firstWhere(
            (e) => e.id == widget.employeeId,
            orElse: () => UserProfile(
              id: '',
              email: '',
              fullName: 'Unknown',
              role: UserRole.employee,
              createdAt: DateTime(2026, 1, 1),
            ),
          );

          if (employee.id.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gpp_bad, size: 56, color: AppColors.error),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Employee Outside Controlled Jurisdiction',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Admins cannot view, assign, or edit employees outside their controlled zones.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Back to Employee List',
                        icon: Icons.arrow_back,
                        onPressed: () => context.go('/employees'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Initialize selected zones once
          if (!_isLoaded) {
            final assigned = (employee.metadata['assigned_zones'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [];
            _selectedZoneIds.addAll(assigned);
            _isLoaded = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Details Header Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          employee.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Employee ID: ${employee.displayId ?? "N/A"} • ${employee.phoneNumber ?? ""}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppBadge(
                        label: employee.isActive ? 'Active' : 'Inactive',
                        variant: employee.isActive
                            ? AppBadgeVariant.success
                            : AppBadgeVariant.neutral,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Error Banner if forbidden zone violation occurs
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Jurisdiction Notice
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.info, size: 20),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Strict Policy: You can only assign or remove zones assigned to your Admin profile by the Master Admin. Unauthorized zone modifications will be rejected.',
                          style: TextStyle(fontSize: 12, color: AppColors.neutral800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Controlled Zones Checkboxes
                Text(
                  'Your Controlled Zones',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Check the zones this employee should be allowed to onboard shops into:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                controlledZonesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Error loading zones: $err'),
                  data: (zones) {
                    if (zones.isEmpty) {
                      return const Text('No controlled zones available.');
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: zones.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, idx) {
                        final zone = zones[idx];
                        final isChecked = _selectedZoneIds.contains(zone.id);

                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${zone.shopCount} shops • ${zone.description ?? ""}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                'FF${zone.colorHex.replaceAll('#', '')}',
                                radix: 16,
                              )),
                              shape: BoxShape.circle,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedZoneIds.add(zone.id);
                              } else {
                                _selectedZoneIds.remove(zone.id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Save Action Button
                AppButton(
                  label: _isSaving ? 'Updating Assignments...' : 'Save Zone Assignments',
                  icon: Icons.save_rounded,
                  onPressed: _isSaving ? null : () => _saveAssignments(employee),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveAssignments(UserProfile employee) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final adminId = ref.read(currentAdminIdProvider);
      final repo = ref.read(adminRepositoryProvider);

      await repo.assignEmployeeToZones(
        adminId: adminId,
        employeeId: employee.id,
        zoneIds: _selectedZoneIds.toList(),
      );

      ref.invalidate(controlledEmployeesProvider);
      ref.invalidate(employeePerformanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zone assignments updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } on ForbiddenZoneException catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } on AppException catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to update zone assignments: $e';
      });
    }
  }
}

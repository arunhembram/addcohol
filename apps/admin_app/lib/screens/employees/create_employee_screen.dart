import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_state_providers.dart';

class CreateEmployeeScreen extends ConsumerStatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  ConsumerState<CreateEmployeeScreen> createState() =>
      _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends ConsumerState<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _consentGiven = false;
  bool _isActive = true;
  String? _aadhaarPhotoPath;
  bool _isUploadingDoc = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  final Set<String> _selectedZoneIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _captureAadhaarDocument() async {
    setState(() {
      _isUploadingDoc = true;
      _errorMessage = null;
    });

    try {
      final adminId = ref.read(currentAdminIdProvider);
      final repo = ref.read(adminRepositoryProvider);

      // Simulated Aadhaar document bytes (in prod, image_picker or camera provides bytes)
      final dummyBytes = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13];
      final path = await repo.uploadAadhaarDocument(
        fileName: 'aadhaar_card_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: dummyBytes,
        adminId: adminId,
      );

      setState(() {
        _aadhaarPhotoPath = path;
        _isUploadingDoc = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aadhaar document captured and stored in private bucket (secure-identity-docs).',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingDoc = false;
        _errorMessage = 'Failed to upload Aadhaar document: $e';
      });
    }
  }

  Future<void> _onSubmit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (!_consentGiven) {
      setState(() => _errorMessage =
          'User consent is mandatory for collecting and storing identity documents.');
      return;
    }

    if (_aadhaarPhotoPath == null) {
      setState(() => _errorMessage =
          'Please capture or attach the Aadhaar-card photo (private storage required).');
      return;
    }

    if (_selectedZoneIds.isEmpty) {
      setState(() => _errorMessage =
          'Please select at least one controlled zone for this employee.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final adminId = ref.read(currentAdminIdProvider);
      final repo = ref.read(adminRepositoryProvider);

      final newEmployee = await repo.createEmployee(
        adminId: adminId,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        aadhaarDocumentPath: _aadhaarPhotoPath!,
        consentGiven: _consentGiven,
        isActive: _isActive,
        initialZoneIds: _selectedZoneIds.toList(),
      );

      // Refresh employee list
      ref.invalidate(controlledEmployeesProvider);
      ref.invalidate(employeePerformanceProvider);

      if (mounted) {
        // Show dialog with server-generated 5-digit Employee ID
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                const Text('Employee Created'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee "${newEmployee.fullName}" has been created successfully.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Server-Generated 5-Digit ID',
                            style: TextStyle(fontSize: 11, color: AppColors.neutral600),
                          ),
                          Text(
                            newEmployee.displayId ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Assigned to ${_selectedZoneIds.length} of your controlled zones.',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/employees');
                },
                child: const Text('Go to Employee List'),
              ),
            ],
          ),
        );
      }
    } on AppException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to create employee: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(controlledZonesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Employee'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error banner if any
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
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Basic Info Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal & Contact Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Employee Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter employee name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Phone Number *',
                        hintText: '+91 98765 43210',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 10) {
                          return 'Please enter a valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'employee@shopad.local',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || !val.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Account Active Status'),
                      subtitle: Text(
                        _isActive
                            ? 'Employee can log in and manage shops'
                            : 'Account is deactivated and access restricted',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Aadhaar Card Private Storage & Consent Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_person_outlined, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Aadhaar Photo & Identity Verification',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Aadhaar image is strictly stored in private encrypted bucket (secure-identity-docs). No raw Aadhaar number is stored.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (_aadhaarPhotoPath != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Aadhaar Document Attached (Private)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  Text(
                                    _aadhaarPhotoPath!,
                                    style: const TextStyle(fontSize: 11, color: AppColors.neutral700),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _captureAadhaarDocument,
                              child: const Text('Re-take'),
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: _isUploadingDoc
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt_outlined),
                        label: Text(
                          _isUploadingDoc
                              ? 'Saving to Private Storage...'
                              : 'Capture / Attach Aadhaar Photo *',
                        ),
                        onPressed: _isUploadingDoc ? null : _captureAadhaarDocument,
                      ),

                    const SizedBox(height: AppSpacing.md),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consentGiven,
                      onChanged: (val) => setState(() => _consentGiven = val ?? false),
                      title: const Text(
                        'Employee Consent Confirmed *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'The employee has formally given consent for identity document verification, field location tracking, and platform compliance.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Zone Assignment Card (Strictly Controlled Zones Only)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assign Controlled Zones *',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppBadge(
                          label: 'Strict Boundary Enforcement',
                          variant: AppBadgeVariant.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Admins can only assign employees to zones under their administrative control.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    zonesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error loading zones: $err'),
                      data: (zones) {
                        if (zones.isEmpty) {
                          return const Text(
                            'You do not have any assigned zones. Contact Master Admin first.',
                            style: TextStyle(color: AppColors.error),
                          );
                        }

                        return Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: zones.map((z) {
                            final isSelected = _selectedZoneIds.contains(z.id);
                            return FilterChip(
                              label: Text('${z.name} (${z.shopCount} Shops)'),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedZoneIds.add(z.id);
                                  } else {
                                    _selectedZoneIds.remove(z.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Button
              AppButton(
                label: _isSubmitting ? 'Creating Employee...' : 'Create Employee & Generate ID',
                icon: Icons.person_add_rounded,
                onPressed: _isSubmitting ? null : _onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

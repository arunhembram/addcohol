import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/company_state_providers.dart';

class CompanyLoginScreen extends ConsumerStatefulWidget {
  const CompanyLoginScreen({super.key});

  @override
  ConsumerState<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends ConsumerState<CompanyLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Alpha Media & Ads Pvt Ltd');
  final _phoneController = TextEditingController(text: '9876543210');
  final _otpController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _handleQuickFill({required String name, required String phone}) {
    _nameController.text = name;
    _phoneController.text = phone;
    _otpController.text = '123456';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(companyAuthProvider);
    final authNotifier = ref.read(companyAuthProvider.notifier);
    final theme = Theme.of(context);

    // If company is authenticated but has 0 assigned zones, show Pending-Approval Status screen
    if (authState.isAuthenticated && authState.isPendingApproval) {
      return _buildPendingApprovalScreen(context, authState, authNotifier);
    }

    // If company is authenticated and approved, button or auto-redirect to dashboard
    if (authState.isAuthenticated && authState.hasAssignedZones) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Welcome, ${authState.company!.tradeName}',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'You have ${authState.company!.assignedZoneIds.length} assigned advertising zones ready to view.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.neutral700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Go to Company Dashboard',
                    icon: Icons.dashboard_rounded,
                    width: double.infinity,
                    onPressed: () => context.go('/dashboard'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => authNotifier.logout(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.business_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ShopAd Company Portal',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      authState.otpSent
                          ? 'Enter the 6-digit OTP sent to your registered phone'
                          : 'Company Onboarding & Verification',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.error.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    if (!authState.otpSent) ...[
                      // Step 1: Company Name & Phone
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Company / Advertiser Name',
                          hintText: 'e.g. Alpha Media & Ads Pvt Ltd',
                          prefixIcon: Icon(Icons.domain_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your registered company name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Registered Phone Number',
                          hintText: '10-digit mobile number',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                        validator: (val) {
                          final clean = val?.replaceAll(RegExp(r'\D'), '') ?? '';
                          if (clean.length < 10) {
                            return 'Enter a valid 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Sandbox helper presets
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.neutral300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Test Accounts (Sandbox):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    onPressed: () => _handleQuickFill(
                                      name: 'Alpha Media & Ads Pvt Ltd',
                                      phone: '9876543210',
                                    ),
                                    child: const Text('Approved (2 Zones)', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    onPressed: () => _handleQuickFill(
                                      name: 'Beta Outdoor Promotions LLP',
                                      phone: '9876543211',
                                    ),
                                    child: const Text('Pending (0 Zones)', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppButton(
                        label: 'Send Verification OTP',
                        icon: Icons.send_rounded,
                        isLoading: authState.isLoading,
                        width: double.infinity,
                        onPressed: () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            await authNotifier.requestOtp(
                              companyName: _nameController.text,
                              phoneNumber: _phoneController.text,
                            );
                          }
                        },
                      ),
                    ] else ...[
                      // Step 2: OTP Verification
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha(20),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'OTP sent to ${_phoneController.text}. (Sandbox test OTP: 123456)',
                                style: const TextStyle(fontSize: 12, color: AppColors.neutral900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '123456',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_clock_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.length != 6) {
                            return 'Enter the 6-digit OTP';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Verify & Sign In',
                        icon: Icons.verified_user_rounded,
                        isLoading: authState.isLoading,
                        width: double.infinity,
                        onPressed: () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            final ok = await authNotifier.verifyOtp(
                              otp: _otpController.text,
                            );
                            if (!context.mounted) return;
                            if (ok) {
                              final updatedState = ref.read(companyAuthProvider);
                              if (updatedState.hasAssignedZones) {
                                context.go('/dashboard');
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () => authNotifier.resetOtp(),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Change Phone Number'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApprovalScreen(
    BuildContext context,
    CompanyAuthState authState,
    CompanyAuthNotifier authNotifier,
  ) {
    final theme = Theme.of(context);
    final company = authState.company!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Onboarding Status'),
        actions: [
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout),
            onPressed: () => authNotifier.logout(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 56,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Pending Master Admin Approval',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppBadge(
                    label: '0 Assigned Zones',
                    variant: AppBadgeVariant.warning,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Strict Policy Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.neutral300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.shield_outlined, size: 20, color: AppColors.neutral800),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              'Zone Access Policy',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          '• A Company gains access only after Master Admin assigns one or more Zones.\n'
                          '• A Company cannot select or grant itself Zone access.\n'
                          '• Once Master Admin confirms and maps your advertising territory, this screen will automatically grant access to assigned maps, shops, and summaries.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.neutral800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Company Profile Summary Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.neutral200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Company Name', company.legalName),
                        const Divider(height: 16),
                        _buildInfoRow('Trade Name', company.tradeName),
                        const Divider(height: 16),
                        _buildInfoRow('Registered Phone', company.contactPhone ?? 'N/A'),
                        const Divider(height: 16),
                        _buildInfoRow('Company ID', company.id),
                        const Divider(height: 16),
                        _buildInfoRow('Status', 'Pending Assignment', isStatus: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppButton(
                    label: 'Check Zone Assignment Status',
                    icon: Icons.refresh_rounded,
                    isLoading: authState.isLoading,
                    width: double.infinity,
                    onPressed: () async {
                      await authNotifier.refreshCompanyStatus();
                      if (context.mounted) {
                        final current = ref.read(companyAuthProvider);
                        if (current.hasAssignedZones) {
                          context.go('/dashboard');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Zone assignment still pending with Master Admin.'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => authNotifier.logout(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Sign in with another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (isStatus)
          AppBadge(label: value, variant: AppBadgeVariant.warning)
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

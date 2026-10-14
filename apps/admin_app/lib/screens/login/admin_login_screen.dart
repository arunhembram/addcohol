import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_state_providers.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _adminIdController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isPinMode = false;
  String? _localError;

  @override
  void dispose() {
    _adminIdController.disposeNullable();
    _otpController.disposeNullable();
    _pinController.disposeNullable();
    super.dispose();
  }

  void _onStep1Submit() async {
    setState(() => _localError = null);
    final id = _adminIdController.text.trim();
    if (id.length != 5 || int.tryParse(id) == null) {
      setState(() => _localError = 'Please enter a valid 5-digit Admin ID.');
      return;
    }

    final success = await ref
        .read(adminAuthProvider.notifier)
        .initiateAdminLogin(id);

    if (!success && mounted) {
      final err = ref.read(adminAuthProvider).errorMessage;
      setState(() => _localError = err ?? 'Admin verification failed.');
    }
  }

  void _onStep2Submit() async {
    setState(() => _localError = null);
    final code = _isPinMode ? _pinController.text.trim() : _otpController.text.trim();

    // STRICT CHECK: Never allow login with ID alone!
    if (code.isEmpty) {
      setState(() => _localError = _isPinMode
          ? 'Security PIN is mandatory. Login with ID alone is prohibited.'
          : 'Mobile OTP is mandatory. Login with ID alone is prohibited.');
      return;
    }

    final success = await ref
        .read(adminAuthProvider.notifier)
        .verifyOtpOrPin(code, isPin: _isPinMode);

    if (success && mounted) {
      context.go('/');
    } else if (mounted) {
      final err = ref.read(adminAuthProvider).errorMessage;
      setState(() => _localError = err ?? 'Verification code incorrect.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ShopAd Admin',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'অ্যাডমিন পোর্টাল • Zone Control',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Error Banner
                  if (_localError != null || authState.errorMessage != null)
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
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _localError ?? authState.errorMessage ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Step 1: Enter 5-digit Admin ID
                  if (!authState.isOtpSent) ...[
                    Text(
                      'Step 1 of 2: Admin Identification',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Enter your 5-digit Admin ID',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _adminIdController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '5-Digit Admin ID',
                        hintText: 'e.g. 10001',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _onStep1Submit(),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Demo Helper Pill
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(Icons.lightbulb_outline, size: 16),
                        label: const Text('Use Sandbox ID: 10001 (Kolkata Central)'),
                        onPressed: () {
                          _adminIdController.text = '10001';
                          _onStep1Submit();
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppButton(
                      label: authState.isLoading ? 'Verifying...' : 'Continue to Verification',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: authState.isLoading ? null : _onStep1Submit,
                    ),
                  ] else ...[
                    // Step 2: Mandatory OTP or PIN
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            ref.read(adminAuthProvider.notifier).logout();
                            setState(() => _localError = null);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Step 2 of 2: Multi-Factor Verification',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.neutral600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Admin ID: ${authState.enteredAdminId}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security, color: AppColors.info, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Security policy: Login with ID alone is prohibited. Enter the code sent to ${authState.maskedPhone}.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Verification Method Selector
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('SMS OTP'),
                          icon: Icon(Icons.sms_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Secure PIN'),
                          icon: Icon(Icons.pin_outlined),
                        ),
                      ],
                      selected: {_isPinMode},
                      onSelectionChanged: (val) {
                        setState(() {
                          _isPinMode = val.first;
                          _localError = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (!_isPinMode) ...[
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '6-Digit Mobile OTP',
                          hintText: '123456',
                          prefixIcon: Icon(Icons.lock_clock_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _onStep2Submit(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.vpn_key, size: 16),
                          label: const Text('Auto-fill Sandbox OTP (123456)'),
                          onPressed: () => _otpController.text = '123456',
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '4-Digit Security PIN',
                          hintText: '••••',
                          prefixIcon: Icon(Icons.password_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _onStep2Submit(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.vpn_key, size: 16),
                          label: const Text('Auto-fill Sandbox PIN (1234)'),
                          onPressed: () => _pinController.text = '1234',
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: authState.isLoading ? 'Verifying...' : 'Verify & Enter Dashboard',
                      icon: Icons.check_circle_outline,
                      onPressed: authState.isLoading ? null : _onStep2Submit,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on TextEditingController? {
  void disposeNullable() {
    this?.dispose();
  }
}

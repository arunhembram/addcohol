import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/shopkeeper_state_providers.dart';

class ShopkeeperLoginScreen extends ConsumerStatefulWidget {
  const ShopkeeperLoginScreen({super.key});

  @override
  ConsumerState<ShopkeeperLoginScreen> createState() => _ShopkeeperLoginScreenState();
}

class _ShopkeeperLoginScreenState extends ConsumerState<ShopkeeperLoginScreen> {
  final _shopCodeController = TextEditingController();
  final _otpController = TextEditingController();

  String? _localError;

  @override
  void dispose() {
    _shopCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onStep1Submit() async {
    setState(() => _localError = null);
    final code = _shopCodeController.text.trim();
    if (code.length != 8 || int.tryParse(code) == null) {
      setState(() => _localError = 'Please enter a valid 8-digit Shop Code.');
      return;
    }

    final success = await ref
        .read(shopkeeperAuthProvider.notifier)
        .initiateLogin(code);

    if (!success && mounted) {
      final err = ref.read(shopkeeperAuthProvider).errorMessage;
      setState(() => _localError = err ?? 'Shop verification failed.');
    }
  }

  void _onStep2Submit() async {
    setState(() => _localError = null);
    final otp = _otpController.text.trim();

    // STRICT CHECK: Never allow access using Shop Code alone!
    if (otp.isEmpty) {
      setState(() => _localError =
          'Registered phone OTP is mandatory. Access using Shop Code alone is strictly prohibited.');
      return;
    }

    final success = await ref
        .read(shopkeeperAuthProvider.notifier)
        .verifyOtpAndBind(otp);

    if (success && mounted) {
      context.go('/');
    } else if (mounted) {
      final err = ref.read(shopkeeperAuthProvider).errorMessage;
      setState(() => _localError = err ?? 'OTP verification failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(shopkeeperAuthProvider);
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
                          Icons.storefront_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ShopAd Partner',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Shopkeeper Portal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.neutral600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Step indicator
                  Row(
                    children: [
                      _StepBadge(
                        number: '1',
                        label: '8-Digit Shop Code',
                        isActive: !authState.isOtpSent,
                        isDone: authState.isOtpSent,
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: authState.isOtpSent
                              ? AppColors.primary
                              : AppColors.neutral300,
                        ),
                      ),
                      _StepBadge(
                        number: '2',
                        label: 'Phone OTP',
                        isActive: authState.isOtpSent,
                        isDone: authState.isAuthenticated,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Error Display
                  if (_localError != null || authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _localError ?? authState.errorMessage ?? '',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Step 1: Enter 8-digit Shop Code
                  if (!authState.isOtpSent) ...[
                    Text(
                      'First-Time Shopkeeper Access',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Please enter the immutable 8-digit Shop Code assigned to your registered shop during field onboarding.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _shopCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '8-Digit Shop Code',
                        hintText: 'e.g. 10000001',
                        prefixIcon: Icon(Icons.pin),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _onStep1Submit(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Verify Code & Send OTP',
                      icon: Icons.arrow_forward,
                      isLoading: authState.isLoading,
                      onPressed: _onStep1Submit,
                    ),
                  ] else ...[
                    // Step 2: Verify OTP and Bind Shop
                    Text(
                      'Verify Registered Phone OTP',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'An OTP has been dispatched to your shop\'s registered mobile (${authState.maskedPhone ?? "registered mobile"}).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '6-Digit Verification OTP',
                        hintText: 'Enter 123456 (Dev OTP)',
                        prefixIcon: Icon(Icons.phonelink_ring),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _onStep2Submit(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Verify & Bind My Shop',
                      icon: Icons.check_circle_outline,
                      isLoading: authState.isLoading,
                      onPressed: _onStep2Submit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        ref.read(shopkeeperAuthProvider.notifier).logout();
                        setState(() {
                          _otpController.clear();
                          _localError = null;
                        });
                      },
                      child: const Text('Change Shop Code'),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),

                  // Sandbox helper
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: AppColors.neutral700),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Test Shopkeeper Credentials',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neutral800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• Code: 10000001 (Maa Tara Electronic Hub)\n'
                          '• Code: 10000002 (Bengal Sweets & Bakery)\n'
                          '• OTP: 123456',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            InkWell(
                              onTap: () {
                                _shopCodeController.text = '10000001';
                                _onStep1Submit();
                              },
                              child: const Text(
                                'Quick-fill 10000001',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _shopCodeController.text = '10000002';
                                _onStep1Submit();
                              },
                              child: const Text(
                                'Quick-fill 10000002',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String number;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepBadge({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.neutral200;
    Color fg = AppColors.neutral700;

    if (isDone) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (isActive) {
      bg = AppColors.primary.withValues(alpha: 0.15);
      fg = AppColors.primary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  number,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isActive || isDone ? AppColors.neutral900 : AppColors.neutral600,
          ),
        ),
      ],
    );
  }
}

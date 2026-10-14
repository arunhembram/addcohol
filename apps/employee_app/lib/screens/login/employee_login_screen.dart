import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/employee_state_providers.dart';

class EmployeeLoginScreen extends ConsumerStatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  ConsumerState<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends ConsumerState<EmployeeLoginScreen> {
  final _employeeIdController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isPinMode = false;
  String? _localError;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onStep1Submit() async {
    setState(() => _localError = null);
    final id = _employeeIdController.text.trim();
    if (id.length != 5 || int.tryParse(id) == null) {
      setState(() => _localError = 'Please enter a valid 5-digit Employee ID.');
      return;
    }

    final success = await ref
        .read(employeeAuthProvider.notifier)
        .initiateEmployeeLogin(id);

    if (!success && mounted) {
      final err = ref.read(employeeAuthProvider).errorMessage;
      setState(() => _localError = err ?? 'Employee verification failed.');
    }
  }

  void _onStep2Submit() async {
    setState(() => _localError = null);
    final code = _isPinMode ? _pinController.text.trim() : _otpController.text.trim();

    // STRICT CHECK: Never allow login with ID alone!
    if (code.isEmpty) {
      setState(() => _localError = _isPinMode
          ? 'Security PIN is mandatory. Login with ID alone is strictly prohibited.'
          : 'Mobile OTP is mandatory. Login with ID alone is strictly prohibited.');
      return;
    }

    final success = await ref
        .read(employeeAuthProvider.notifier)
        .verifyOtpOrPin(code, isPin: _isPinMode);

    if (success && mounted) {
      // Automatically open Employee Profile and Assigned Zone Map
      context.go('/');
    } else if (mounted) {
      final err = ref.read(employeeAuthProvider).errorMessage;
      setState(() => _localError = err ?? 'Verification code incorrect.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(employeeAuthProvider);
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
                          Icons.badge_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ShopAd Field Pro',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Field Employee Portal',
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
                        label: 'Employee ID',
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
                        label: _isPinMode ? 'Secure PIN' : 'Phone OTP',
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

                  // Step 1: Enter 5-digit Employee ID
                  if (!authState.isOtpSent) ...[
                    Text(
                      'Enter Your Employee ID',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Please enter the 5-digit Employee ID issued by your Admin to access your assigned zones.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _employeeIdController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '5-Digit Employee ID',
                        hintText: 'e.g. 20001',
                        prefixIcon: Icon(Icons.pin),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _onStep1Submit(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Verify ID & Send OTP',
                      icon: Icons.arrow_forward,
                      isLoading: authState.isLoading,
                      onPressed: _onStep1Submit,
                    ),
                  ] else ...[
                    // Step 2: Verify OTP or PIN
                    Text(
                      _isPinMode ? 'Enter Secure PIN' : 'Verify Mobile OTP',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _isPinMode
                          ? 'Enter your 4-digit security PIN for ID ${authState.enteredEmployeeId}.'
                          : 'OTP has been dispatched to ${authState.maskedPhone ?? "registered mobile"}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (!_isPinMode)
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '6-Digit One-Time Password',
                          hintText: 'Enter 123456 (Dev OTP)',
                          prefixIcon: Icon(Icons.phonelink_ring),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _onStep2Submit(),
                      )
                    else
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '4-Digit Security PIN',
                          hintText: 'Enter 1234',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _onStep2Submit(),
                      ),

                    const SizedBox(height: AppSpacing.sm),

                    // Switch between OTP and PIN
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isPinMode = !_isPinMode;
                            _localError = null;
                          });
                        },
                        child: Text(
                          _isPinMode
                              ? 'Switch to Mobile OTP'
                              : 'Use Secure PIN instead',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppButton(
                      label: 'Verify & Open Zone Map',
                      icon: Icons.check_circle_outline,
                      isLoading: authState.isLoading,
                      onPressed: _onStep2Submit,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Change ID button
                    TextButton(
                      onPressed: () {
                        ref.read(employeeAuthProvider.notifier).logout();
                        setState(() {
                          _otpController.clear();
                          _pinController.clear();
                          _localError = null;
                        });
                      },
                      child: const Text('Change Employee ID'),
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
                                'Test Field Employee Credentials',
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
                          '• Emp ID: 20001 (Rahul Das - Kolkata Central)\n'
                          '• Emp ID: 20002 (Ananya Roy - Kolkata Central & Salt Lake)\n'
                          '• OTP: 123456  |  PIN: 1234',
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
                                _employeeIdController.text = '20001';
                                _onStep1Submit();
                              },
                              child: const Text(
                                'Quick-fill 20001',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _employeeIdController.text = '20002';
                                _onStep1Submit();
                              },
                              child: const Text(
                                'Quick-fill 20002',
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

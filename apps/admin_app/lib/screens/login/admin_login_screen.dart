import 'package:data_repository/data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_state_providers.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  // Mode: 0 = Sign up, 1 = Log in
  int _selectedTab = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String _selectedCountryCode = '+91';
  String? _localError;
  bool _submitted = false;

  final List<String> _countryCodes = [
    '+91',
    '+880',
    '+977',
    '+94',
    '+971',
    '+44',
    '+1',
  ];

  @override
  void initState() {
    super.initState();
    DistributionSyncService.fetchRemoteState();
    _codeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // Auto-format Indian numbers as 5 digits + space + 5 digits
  void _onPhoneChanged(String val) {
    if (_selectedCountryCode == '+91') {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      if (digits.length <= 10) {
        String formatted = digits;
        if (digits.length > 5) {
          formatted = '${digits.substring(0, 5)} ${digits.substring(5)}';
        }
        if (formatted != val) {
          _phoneController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      }
    }
    if (_submitted) setState(() {});
  }

  String? _validateFirstName() {
    if (_selectedTab == 1) return null; // Not needed in login mode
    final val = _firstNameController.text.trim();
    if (val.isEmpty) return 'First name is required';
    if (val.replaceAll(RegExp(r'[^a-zA-Z]'), '').length < 2) {
      return 'At least 2 letters required';
    }
    return null;
  }

  String? _validateLastName() {
    if (_selectedTab == 1) return null; // Not needed in login mode
    final val = _lastNameController.text.trim();
    if (val.isEmpty) return 'Last name is required';
    return null;
  }

  String? _validatePhone() {
    if (_selectedTab == 1) return null; // Not needed in login mode
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (_selectedCountryCode == '+91') {
      if (!RegExp(r'^[6-9]').hasMatch(digits)) {
        return 'Indian numbers must start with 6, 7, 8 or 9';
      }
      if (digits.length != 10) {
        return 'Exactly 10 digits required (${digits.length}/10)';
      }
    } else {
      if (digits.length < 6 || digits.length > 14) {
        return 'Must be 6 to 14 digits (${digits.length})';
      }
    }
    return null;
  }

  String? _validateCode() {
    final digits = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '5-digit admin code is required';
    if (digits.length != 5) return 'Code must be exactly 5 digits (${digits.length}/5)';
    return null;
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _submitted = true;
      _localError = null;
    });

    final firstErr = _validateFirstName();
    final lastErr = _validateLastName();
    final phoneErr = _validatePhone();
    final codeErr = _validateCode();

    if (_selectedTab == 0) {
      // --- SIGN UP ---
      if (firstErr != null || lastErr != null || phoneErr != null || codeErr != null) {
        return;
      }

      final fName = _firstNameController.text.trim();
      final lName = _lastNameController.text.trim();
      final fullPhone = '$_selectedCountryCode ${_phoneController.text.trim()}';
      final code = _codeController.text.trim();

      final success = await ref.read(adminAuthProvider.notifier).signupWithDetails(
            firstName: fName,
            lastName: lName,
            phoneNumber: fullPhone,
            code: code,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, $fName! Admin Dashboard is ready.'),
            backgroundColor: const Color(0xFF0B6E5B),
          ),
        );
        context.go('/');
      } else if (mounted) {
        final err = ref.read(adminAuthProvider).errorMessage;
        setState(() => _localError = err ?? 'Sign up failed.');
      }
    } else {
      // --- LOG IN (5-DIGIT CODE ONLY) ---
      if (codeErr != null) return;

      final code = _codeController.text.trim();
      final success = await ref.read(adminAuthProvider.notifier).loginWithCode(code);

      if (success && mounted) {
        final currentAdmin = ref.read(adminAuthProvider).currentAdmin;
        final fName = currentAdmin?.fullName.split(' ').first ?? 'Admin';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hello, $fName! 🛡️ Opening Admin Dashboard...'),
            backgroundColor: const Color(0xFF0B6E5B),
          ),
        );
        context.go('/');
      } else if (mounted) {
        final err = ref.read(adminAuthProvider).errorMessage;
        setState(() => _localError = err ?? 'Login failed. Please verify your admin code.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(adminAuthProvider);

    // Exact Design System & HTML matched colors
    final bgPage = isDark ? const Color(0xFF0B1319) : const Color(0xFFEDF2F7);
    final bgCard = isDark ? const Color(0xFF121D26) : Colors.white;
    final borderCard = isDark ? const Color(0xFF1C2E3D) : const Color(0xFFD8E2EC);
    final accent = isDark ? const Color(0xFF4FD1B0) : const Color(0xFF0B6E5B);
    final accentText = isDark ? const Color(0xFF091A16) : Colors.white;

    final textTitle = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0E1724);
    final textSub = isDark ? const Color(0xFF8DA2B5) : const Color(0xFF526071);
    final textLabel = isDark ? const Color(0xFF8BA1B4) : const Color(0xFF5A6E82);
    final bgInput = isDark ? const Color(0xFF0D161E) : const Color(0xFFF8FAFC);
    final borderInput = isDark ? const Color(0xFF213545) : const Color(0xFFCFDCE8);

    final codeDigits = _codeController.text.replaceAll(RegExp(r'\D'), '');

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTab == 0 ? 'Admin Sign up' : 'Admin Log in',
                          style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: textTitle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedTab == 0
                              ? 'Enter your name, phone number and 5 digit admin code.'
                              : 'Enter your 5 digit code to access the admin dashboard.',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: textSub,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Switch Tabs: [Sign up | Log in]
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderInput),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = 0;
                                _localError = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? bgCard : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: _selectedTab == 0 ? Border.all(color: borderCard) : null,
                                boxShadow: _selectedTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 14.5,
                                    color: _selectedTab == 0 ? accent : textSub,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = 1;
                                _localError = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? bgCard : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: _selectedTab == 1 ? Border.all(color: borderCard) : null,
                                boxShadow: _selectedTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Log in',
                                  style: TextStyle(
                                    fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 14.5,
                                    color: _selectedTab == 1 ? accent : textSub,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderCard),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0x140B1E30),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error banner if any
                        if (_localError != null || authState.errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _localError ?? authState.errorMessage ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // SIGN UP ONLY FIELDS: First Name & Last Name
                        if (_selectedTab == 0) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FIRST NAME',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: textLabel,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _firstNameController,
                                      style: TextStyle(color: textTitle, fontSize: 14.5),
                                      decoration: InputDecoration(
                                        hintText: 'First name',
                                        hintStyle: TextStyle(color: textSub.withValues(alpha: 0.6)),
                                        filled: true,
                                        fillColor: bgInput,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: borderInput),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: borderInput),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: accent, width: 1.8),
                                        ),
                                      ),
                                      onChanged: (_) {
                                        if (_submitted) setState(() {});
                                      },
                                    ),
                                    if (_submitted && _validateFirstName() != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _validateFirstName()!,
                                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Last Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LAST NAME',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: textLabel,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _lastNameController,
                                      style: TextStyle(color: textTitle, fontSize: 14.5),
                                      decoration: InputDecoration(
                                        hintText: 'Last name',
                                        hintStyle: TextStyle(color: textSub.withValues(alpha: 0.6)),
                                        filled: true,
                                        fillColor: bgInput,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: borderInput),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: borderInput),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: accent, width: 1.8),
                                        ),
                                      ),
                                      onChanged: (_) {
                                        if (_submitted) setState(() {});
                                      },
                                    ),
                                    if (_submitted && _validateLastName() != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _validateLastName()!,
                                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Phone Number with Country Code Dropdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PHONE NUMBER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: textLabel,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: bgInput,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _submitted && _validatePhone() != null ? const Color(0xFFDC2626) : borderInput,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Country Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: borderInput),
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCountryCode,
                                          dropdownColor: bgCard,
                                          style: TextStyle(
                                            color: textTitle,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                          icon: Icon(Icons.arrow_drop_down, color: textSub, size: 20),
                                          items: _countryCodes.map((c) {
                                            return DropdownMenuItem(
                                              value: c,
                                              child: Text(c == '+91' ? 'IN +91' : c),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _selectedCountryCode = val;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    // Phone Input
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textTitle,
                                          fontFamily: 'monospace',
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _selectedCountryCode == '+91' ? '98765 43210' : 'Phone number',
                                          hintStyle: TextStyle(color: textSub.withValues(alpha: 0.5), letterSpacing: 1.2),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                        onChanged: _onPhoneChanged,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_submitted && _validatePhone() != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _validatePhone()!,
                                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 5-DIGIT CODE FIELD (Always Visible in both Sign up & Log in)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedTab == 0 ? 'ADMIN CODE' : 'ENTER YOUR 5-DIGIT CODE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: textLabel,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: bgInput,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: borderInput),
                                  ),
                                  child: Text(
                                    '${codeDigits.length}/5',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: textSub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 5,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(
                                color: textTitle,
                                fontFamily: 'monospace',
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 5.0,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '_ _ _ _ _',
                                hintStyle: TextStyle(
                                  color: textSub.withValues(alpha: 0.5),
                                  fontFamily: 'monospace',
                                  letterSpacing: 5.0,
                                ),
                                filled: true,
                                fillColor: bgInput,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: _submitted && _validateCode() != null ? const Color(0xFFDC2626) : borderInput,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: _submitted && _validateCode() != null ? const Color(0xFFDC2626) : borderInput,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: accent, width: 1.8),
                                ),
                              ),
                              onChanged: (_) {
                                if (_submitted) setState(() {});
                              },
                            ),
                            if (_submitted && _validateCode() != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _validateCode()!,
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // Submit Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: accentText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                  )
                                : Text(
                                    _selectedTab == 0 ? 'Sign up' : 'Log in',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Switch Hint
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _selectedTab == 0 ? 'Already an administrator? ' : "Need a new admin profile? ",
                                style: TextStyle(fontSize: 13, color: textSub),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = _selectedTab == 0 ? 1 : 0;
                                    _localError = null;
                                  });
                                },
                                child: Text(
                                  _selectedTab == 0 ? 'Log in' : 'Sign up',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Quick Test Code Hint
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTab == 0 ? 'Demo code:' : 'Quick test login:',
                                style: TextStyle(fontSize: 12, color: textSub),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _codeController.text = '10001';
                                    if (_selectedTab == 0) {
                                      _firstNameController.text = 'Subhasis';
                                      _lastNameController.text = 'Ghosh';
                                      _phoneController.text = '98765 43210';
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: bgCard,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: borderCard),
                                  ),
                                  child: Text(
                                    '10001',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

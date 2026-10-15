import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/phone_auth_service.dart';
import '../../../services/user_session_service.dart';

/// Fullscreen blur gateway presented to first-time visitors:
/// - Blurs the landing page background with [ImageFilter.blur].
/// - Asks for 1. Brand/Company Name, 2. Phone Number, 3. 6-digit SMS OTP.
/// - Verifies OTP via Firebase Phone Auth and persistently saves the session.
/// - Once verified, the blur gate unlocks and will NOT be shown on revisit!
class BrandEntryBlurGate extends StatefulWidget {
  final void Function(String brandName, String phoneNumber) onVerified;

  const BrandEntryBlurGate({
    super.key,
    required this.onVerified,
  });

  @override
  State<BrandEntryBlurGate> createState() => _BrandEntryBlurGateState();
}

class _BrandEntryBlurGateState extends State<BrandEntryBlurGate> {
  static const Color colorNavy = Color(0xFF0E1624);
  static const Color colorYellow = Color(0xFFFFD43B);

  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _successMessage;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _brandController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final brand = _brandController.text.trim();
    if (brand.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Brand / Company Name first');
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      _phoneFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await PhoneAuthService.instance.sendOtp(
        fullPhoneNumber: '+91$phone',
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _isSendingOtp = false;
            _otpSent = true;
            _errorMessage = null;
            _successMessage = 'SMS OTP sent to +91 $phone! Check your phone.';
          });
          _otpController.clear();
          _otpFocusNode.requestFocus();
          _startCooldown();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isSendingOtp = false;
            _errorMessage = error;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleVerifyAndEnter() async {
    final brand = _brandController.text.trim();
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (brand.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Brand / Company Name');
      return;
    }

    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    if (!_otpSent) {
      // User tapped button before sending OTP: trigger Send OTP
      await _handleSendOtp();
      return;
    }

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP code');
      _otpFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify OTP with Firebase
      await PhoneAuthService.instance.verifyOtp(smsCode: otp);

      // 2. Save session persistently to browser localStorage
      await UserSessionService.instance.saveSession(
        brandName: brand,
        phoneNumber: '+91 $phone',
      );

      // 3. Notify parent to unlock landing page
      if (mounted) {
        widget.onVerified(brand, '+91 $phone');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Positioned.fill(
      child: Stack(
        children: [
          // 1. BLUR BACKDROP FILTER
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              color: const Color(0xD10E1624), // Dark navy veil
            ),
          ),

          // 2. CENTERED ONBOARDING CARD
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 24.0,
                vertical: 24.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 24.0 : 36.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 40,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorYellow,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: colorNavy,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ADDCOHOL PARTNER ACCESS',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: colorNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          'Enter Your Brand Name',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: isMobile ? 26 : 30,
                            fontWeight: FontWeight.w800,
                            color: colorNavy,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Verify your brand and mobile number to unlock live retail scanner ad spaces & daily photo proof.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF4A5568),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // FIELD 1: BRAND / COMPANY NAME
                        Text(
                          '1. Brand / Company Name',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _brandController,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorNavy,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Maloye, Puma, Zomato',
                            hintStyle: GoogleFonts.dmSans(
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.storefront_rounded,
                              color: colorNavy,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: colorNavy, width: 2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // FIELD 2: MOBILE NUMBER
                        Text(
                          '2. Mobile Number (for Verification)',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // +91 Prefix Box
                            Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+91',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: colorNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Phone Input
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colorNavy,
                                  letterSpacing: 1.2,
                                ),
                                decoration: InputDecoration(
                                  hintText: '10-digit number',
                                  hintStyle: GoogleFonts.dmSans(
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: colorNavy, width: 2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Send OTP Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSendingOtp || _resendCooldown > 0
                                    ? null
                                    : _handleSendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorNavy,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF94A3B8),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSendingOtp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _resendCooldown > 0
                                            ? '${_resendCooldown}s'
                                            : (_otpSent ? 'Resend' : 'Send OTP'),
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),

                        // FIELD 3: OTP CODE (SHOWS AFTER SEND OTP OR WHEN READY)
                        if (_otpSent) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '3. 6-Digit OTP Code',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colorNavy,
                                ),
                              ),
                              if (_resendCooldown > 0)
                                Text(
                                  'Resend in ${_resendCooldown}s',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _otpController,
                            focusNode: _otpFocusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: GoogleFonts.dmSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                              color: colorNavy,
                            ),
                            decoration: InputDecoration(
                              hintText: '••••••',
                              hintStyle: GoogleFonts.dmSans(
                                letterSpacing: 8,
                                color: const Color(0xFFCBD5E1),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFFFBEB), // Gentle yellow tint
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFFD43B)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFFD43B), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: colorNavy, width: 2),
                              ),
                            ),
                          ),
                        ],

                        // ERROR MESSAGE BANNER
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // SUCCESS MESSAGE BANNER
                        if (_successMessage != null && _errorMessage == null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // SUBMIT ACTION BUTTON
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isVerifyingOtp || _isSendingOtp
                                ? null
                                : _handleVerifyAndEnter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorYellow,
                              foregroundColor: colorNavy,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isVerifyingOtp
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(colorNavy),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _otpSent
                                            ? 'Verify & Enter Website'
                                            : 'Send OTP & Continue',
                                        style: GoogleFonts.bricolageGrotesque(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // FOOTNOTE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Secured by Google Firebase • Session saved on your device',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

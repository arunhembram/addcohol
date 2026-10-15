import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/phone_auth_service.dart';

/// Modal dialog shown after tapping "CONFIRM BOOKING":
/// 1. Business name input box
/// 2. Phone number with "+91 IND" default selected + 10-digit numeric only input + "SEND OTP" trigger
/// 3. 6-digit Google SMS OTP boxes (PIN boxes with auto-advance & countdown timer)
class BookingVerificationDialog extends StatefulWidget {
  final String initialBusinessName;
  final String? initialPhone;
  final String zoneName;
  final int weeksCount;
  final double totalAmount;
  final Future<void> Function({
    required String businessName,
    required String phoneNumber,
    required String otp,
  }) onConfirm;

  const BookingVerificationDialog({
    super.key,
    required this.initialBusinessName,
    this.initialPhone,
    required this.zoneName,
    required this.weeksCount,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  State<BookingVerificationDialog> createState() =>
      _BookingVerificationDialogState();
}

class _BookingVerificationDialogState extends State<BookingVerificationDialog> {
  static const Color colorNavy = Color(0xFF0F2A43);
  static const Color colorTeal = Color(0xFF0F9D8A);

  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final List<TextEditingController> _otpCtrls;
  late final List<FocusNode> _otpFocusNodes;

  String? _errorMessage;
  String? _successMessage;
  bool _isSubmitting = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl =
        TextEditingController(text: widget.initialBusinessName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _otpCtrls = List.generate(6, (_) => TextEditingController());
    _otpFocusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _businessNameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpCtrls.map((c) => c.text.trim()).join();


  void _startCooldownTimer() {
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
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number first');
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
            _successMessage = 'Real SMS OTP sent to +91 $phone! Check your phone.';
          });
          for (final c in _otpCtrls) {
            c.clear();
          }
          _otpFocusNodes[0].requestFocus();
          _startCooldownTimer();
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

  Future<void> _handleSubmit() async {
    final bName = _businessNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final otp = _otpValue;

    if (bName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Business Name');
      return;
    }

    if (phone.length != 10) {
      setState(
          () => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit OTP');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      // Verify OTP via Firebase Phone Auth
      await PhoneAuthService.instance.verifyOtp(smsCode: otp);

      await widget.onConfirm(
        businessName: bName,
        phoneNumber: '+91 $phone',
        otp: otp,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row with Title and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: colorTeal.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: colorTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Text(
                            'Booking Verification',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: colorNavy,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF64748B), size: 20),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Booking Context Summary Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.zoneName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colorNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${widget.weeksCount} Wk(s) • ${formatIndianCurrency(widget.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: colorTeal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 1. Business Name Input Box
              const Text(
                'Business Name',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colorNavy,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _businessNameCtrl,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter Business Name',
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: colorTeal, width: 1.8),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Phone Number with "+91 IND" default selected + 10-digit numeric only box
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colorNavy,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Default selected Country Badge (+91 IND)
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('🇮🇳', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          '+91 IND',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colorNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 10-digit Numeric Only Input Box
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '10-digit mobile number',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0,
                          ),
                          prefixIcon: const Icon(
                            Icons.phone_android_rounded,
                            color: Color(0xFF64748B),
                            size: 19,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: colorTeal, width: 1.8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send OTP Button
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: (_isSendingOtp || _resendCooldown > 0)
                          ? null
                          : _handleSendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: _isSendingOtp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? '${_resendCooldown}s'
                                  : (_otpSent ? 'Resend' : 'Send OTP'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              // Success message pill
              if (_successMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 15, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // 3. 6-digit OTP Box
              const Text(
                'Enter 6-Digit Google OTP',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colorNavy,
                ),
              ),
              const SizedBox(height: 8),

              // 6 Individual OTP Digit Cells
              LayoutBuilder(builder: (context, constraints) {
                final double cellWidth =
                    ((constraints.maxWidth - (5 * 6)) / 6).clamp(38.0, 52.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: cellWidth,
                      height: 52,
                      child: TextFormField(
                        controller: _otpCtrls[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: colorNavy,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        onChanged: (val) {
                          if (val.isNotEmpty && index < 5) {
                            _otpFocusNodes[index + 1].requestFocus();
                          } else if (val.isEmpty && index > 0) {
                            _otpFocusNodes[index - 1].requestFocus();
                          }
                          setState(() => _errorMessage = null);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: colorTeal, width: 1.8),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),

              // Error display
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Confirm and Book Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'CONFIRM & BOOK SLOTS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 10),

              // Safe and secure badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.lock_outline_rounded,
                      size: 13, color: Color(0xFF94A3B8)),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Secured by Google Firebase Authentication',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

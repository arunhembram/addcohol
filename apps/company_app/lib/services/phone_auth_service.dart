import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';

/// Service managing REAL SMS OTP delivery to physical mobile via Fast2SMS Indian SMS Gateway (Zero reCAPTCHA).
class PhoneAuthService {
  PhoneAuthService._();
  static final PhoneAuthService instance = PhoneAuthService._();

  static const String _fast2SmsApiKey =
      'wEuyTRFipcx7oQfCIdW03vLZNXbgjPASGm952HzJlMkaeshqBUef8zLArFKs50abp47lhJxvwO2BEoVX';

  bool _initialized = false;
  FirebaseAuth? _auth;
  String? _verificationId;
  String? _activeOtp;

  /// Ensures Firebase is initialized once.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _auth = FirebaseAuth.instance;
      _initialized = true;
      debugPrint('[PhoneAuthService] Firebase initialized successfully.');
    } catch (e) {
      debugPrint('[PhoneAuthService] Initialization error: $e');
    }
  }

  /// Sends a REAL telecom SMS OTP code to [fullPhoneNumber] via Fast2SMS Indian SMS Gateway (Zero reCAPTCHA).
  Future<void> sendOtp({
    required String fullPhoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
  }) async {
    try {
      // 1. Generate clean 6-digit random OTP
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();
      _activeOtp = otp;
      _verificationId = 'fast2sms_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Extract clean 10-digit Indian mobile number
      final cleanNumber = fullPhoneNumber
          .replaceAll(RegExp(r'\D'), '')
          .replaceFirst(RegExp(r'^91'), '');

      debugPrint('[PhoneAuthService] Sending real SMS to $cleanNumber via Fast2SMS (OTP: $otp)...');

      // 3. Make HTTP request to Fast2SMS Bulk V2 API
      final url = Uri.parse('https://www.fast2sms.com/dev/bulkV2');
      final response = await http.post(
        url,
        headers: {
          'authorization': _fast2SmsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'route': 'q',
          'message': 'Your Addcohol booking verification code is $otp',
          'language': 'english',
          'flash': 0,
          'numbers': cleanNumber,
        }),
      );

      debugPrint('[PhoneAuthService] Fast2SMS status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['return'] == true || data['status_code'] == 200) {
          debugPrint('[PhoneAuthService] Real SMS delivered successfully to $cleanNumber!');
          onCodeSent(_verificationId!);
          return;
        } else {
          final msg = data['message']?.toString() ?? 'Failed to send SMS.';
          onError(msg);
          return;
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          final statusCode = data['status_code'];
          final msg = data['message']?.toString() ?? 'Fast2SMS error';

          if (statusCode == 999 || msg.contains('100 INR')) {
            onError('Fast2SMS activation: Please click "ADD CREDIT" on your Fast2SMS dashboard to add ₹100 recharge to unlock API SMS delivery.');
          } else {
            onError(msg);
          }
        } catch (_) {
          onError('Fast2SMS returned error code: ${response.statusCode}');
        }
        return;
      }
    } catch (e) {
      debugPrint('[PhoneAuthService] Fast2SMS error: $e');
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Verifies the 6-digit [smsCode] entered by the user.
  Future<bool> verifyOtp({
    required String smsCode,
  }) async {
    final cleanCode = smsCode.trim();

    // Verify entered OTP with the sent OTP code (or universal demo 123456)
    if (cleanCode == _activeOtp || cleanCode == '123456') {
      debugPrint('[PhoneAuthService] OTP $cleanCode successfully verified.');
      return true;
    }

    throw Exception('Invalid OTP code. Please enter the 6-digit code sent to your phone.');
  }

  /// The active OTP in memory (for debugging or inspection).
  String? get activeOtp => _activeOtp;
}

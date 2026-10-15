import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing persistent customer session and profile state.
///
/// Ensures that once a customer enters their Brand Name, Phone, and verifies OTP,
/// their session is saved in local browser storage indefinitely. When they revisit
/// after 10 days or months, they automatically bypass the entry blur gate and remain logged in.
class UserSessionService {
  UserSessionService._();
  static final UserSessionService instance = UserSessionService._();

  static const String _keyBrandName = 'customer_brand_name';
  static const String _keyPhoneNumber = 'customer_phone_number';
  static const String _keyIsLoggedIn = 'customer_is_logged_in';
  static const String _keyLastLoginAt = 'customer_last_login_at';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Checks if customer has an active persistent session.
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await _getPrefs();
      final hasLocalSession = prefs.getBool(_keyIsLoggedIn) ?? false;
      final brand = prefs.getString(_keyBrandName);
      
      // Also check Firebase current user if available
      final firebaseUser = FirebaseAuth.instance.currentUser;

      return hasLocalSession && brand != null && brand.trim().isNotEmpty || (firebaseUser != null && brand != null);
    } catch (e) {
      debugPrint('[UserSessionService] Error checking login status: $e');
      return false;
    }
  }

  /// Retrieves the saved Brand / Company Name.
  Future<String?> getSavedBrandName() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(_keyBrandName);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the saved Phone Number.
  Future<String?> getSavedPhoneNumber() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(_keyPhoneNumber);
    } catch (_) {
      return null;
    }
  }

  /// Saves the customer profile & persistent session upon successful OTP verification.
  Future<void> saveSession({
    required String brandName,
    required String phoneNumber,
  }) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyBrandName, brandName.trim());
      await prefs.setString(_keyPhoneNumber, phoneNumber.trim());
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyLastLoginAt, DateTime.now().toIso8601String());
      debugPrint('[UserSessionService] Session saved for brand: $brandName, phone: $phoneNumber');
    } catch (e) {
      debugPrint('[UserSessionService] Error saving session: $e');
    }
  }

  /// Updates only the brand name in session.
  Future<void> updateBrandName(String brandName) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyBrandName, brandName.trim());
    } catch (e) {
      debugPrint('[UserSessionService] Error updating brand name: $e');
    }
  }

  /// Clears session (Log Out).
  Future<void> clearSession() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyBrandName);
      await prefs.remove(_keyPhoneNumber);
      await prefs.setBool(_keyIsLoggedIn, false);
      await FirebaseAuth.instance.signOut();
      debugPrint('[UserSessionService] Customer session cleared.');
    } catch (e) {
      debugPrint('[UserSessionService] Error clearing session: $e');
    }
  }
}

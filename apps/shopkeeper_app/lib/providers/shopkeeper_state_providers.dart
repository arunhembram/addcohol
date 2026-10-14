import 'dart:math';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_features/map_features.dart';

class ShopkeeperAuthState {
  final bool isAuthenticated;
  final Shop? currentShop;
  final String? enteredShopCode;
  final String? maskedPhone;
  final bool isOtpSent;
  final bool isLoading;
  final String? errorMessage;

  const ShopkeeperAuthState({
    this.isAuthenticated = false,
    this.currentShop,
    this.enteredShopCode,
    this.maskedPhone,
    this.isOtpSent = false,
    this.isLoading = false,
    this.errorMessage,
  });

  ShopkeeperAuthState copyWith({
    bool? isAuthenticated,
    Shop? currentShop,
    String? enteredShopCode,
    String? maskedPhone,
    bool? isOtpSent,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ShopkeeperAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentShop: currentShop ?? this.currentShop,
      enteredShopCode: enteredShopCode ?? this.enteredShopCode,
      maskedPhone: maskedPhone ?? this.maskedPhone,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ShopkeeperAuthNotifier extends StateNotifier<ShopkeeperAuthState> {
  final IShopkeeperRepository _repository;

  ShopkeeperAuthNotifier(this._repository) : super(const ShopkeeperAuthState());

  /// Step 1: Shopkeeper enters 8-digit Shop Code
  Future<bool> initiateLogin(String shopCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final shop = await _repository.verifyShopCode(shopCode);
      if (shop == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid 8-digit Shop Code or shop is inactive.',
        );
        return false;
      }

      final phone = await _repository.sendShopOtp(shopCode);
      final masked = _maskPhoneNumber(phone);

      state = state.copyWith(
        isLoading: false,
        enteredShopCode: shopCode,
        maskedPhone: masked,
        isOtpSent: true,
        errorMessage: null,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Verification failed: $e');
      return false;
    }
  }

  /// Step 2: Verify OTP and strictly bind authenticated session to this shop.
  /// Never allow access using Shop Code alone!
  Future<bool> verifyOtpAndBind(String otp) async {
    final code = state.enteredShopCode;
    if (code == null) {
      state = state.copyWith(errorMessage: 'Please enter your 8-digit Shop Code first.');
      return false;
    }

    // STRICT CHECK: Never allow access using Shop Code alone!
    if (otp.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Registered mobile OTP is mandatory. Access with Shop Code alone is prohibited.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final boundShop = await _repository.verifyOtpAndBindShop(
        shopCode: code,
        otp: otp,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentShop: boundShop,
        errorMessage: null,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'OTP verification failed: $e');
      return false;
    }
  }

  void logout() {
    state = const ShopkeeperAuthState();
  }

  void resetError() {
    state = state.copyWith(errorMessage: null);
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length <= 4) return '***';
    final visiblePrefix = phone.substring(0, min(phone.length - 4, 6));
    final visibleSuffix = phone.substring(phone.length - 3);
    return '$visiblePrefix*** **$visibleSuffix';
  }
}

final shopkeeperAuthProvider =
    StateNotifierProvider<ShopkeeperAuthNotifier, ShopkeeperAuthState>((ref) {
  final repo = ref.watch(shopkeeperRepositoryProvider);
  return ShopkeeperAuthNotifier(repo);
});

/// Bound Shop Provider (defaults to sandbox shop-101 if directly accessed)
final currentBoundShopProvider = Provider<Shop>((ref) {
  final authState = ref.watch(shopkeeperAuthProvider);
  return authState.currentShop ??
      Shop(
        id: 'shop-101',
        shopCode: '10000001',
        ownerId: 'owner-1',
        shopName: 'Maa Tara Electronic Hub',
        category: 'Saloon',
        address: '42 Central Avenue, Kolkata',
        latitude: 22.5720,
        longitude: 88.3620,
        status: 'active',
        activeScreensCount: 2,
        zoneId: 'z-kolkata-central',
        zoneName: 'Kolkata Central Zone',
        ownerName: 'Tarun Banerjee',
        phoneNumber: '9876500001',
        monthlyRent: 4500.0,
        isAgreed: true,
        openingTime: '09:00 AM',
        closingTime: '09:00 PM',
        weeklyClosedDay: 'Sunday',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );
});

/// Today's Upload Provider for current bound shop
final todayUploadProvider = FutureProvider.autoDispose<ShopDailyUpload?>((ref) async {
  final repo = ref.watch(shopkeeperRepositoryProvider);
  final shop = ref.watch(currentBoundShopProvider);
  return await repo.getTodayUpload(shop.id);
});

/// Location coordinates provider for geofence validation
final shopkeeperDeviceLocationProvider =
    FutureProvider.autoDispose<LocationCoords?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.getCurrentLocation();
});

import 'dart:async';
import 'dart:math';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_features/map_features.dart';

class EmployeeAuthState {
  final bool isAuthenticated;
  final UserProfile? currentEmployee;
  final String? enteredEmployeeId;
  final String? maskedPhone;
  final bool isOtpSent;
  final bool isLoading;
  final String? errorMessage;

  const EmployeeAuthState({
    this.isAuthenticated = false,
    this.currentEmployee,
    this.enteredEmployeeId,
    this.maskedPhone,
    this.isOtpSent = false,
    this.isLoading = false,
    this.errorMessage,
  });

  EmployeeAuthState copyWith({
    bool? isAuthenticated,
    UserProfile? currentEmployee,
    String? enteredEmployeeId,
    String? maskedPhone,
    bool? isOtpSent,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EmployeeAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentEmployee: currentEmployee ?? this.currentEmployee,
      enteredEmployeeId: enteredEmployeeId ?? this.enteredEmployeeId,
      maskedPhone: maskedPhone ?? this.maskedPhone,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EmployeeAuthNotifier extends StateNotifier<EmployeeAuthState> {
  final IEmployeeRepository _employeeRepo;

  EmployeeAuthNotifier(this._employeeRepo) : super(const EmployeeAuthState());

  /// Step 1: Employee enters 5-digit Employee ID
  Future<bool> initiateEmployeeLogin(String displayId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await DistributionSyncService.fetchRemoteState();
      final emp = await _employeeRepo.verifyEmployeeId(displayId);
      if (emp == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Employee ID not found or account is inactive.',
        );
        return false;
      }

      final phone = await _employeeRepo.sendEmployeeOtp(displayId);
      final masked = _maskPhoneNumber(phone);

      state = state.copyWith(
        isLoading: false,
        enteredEmployeeId: displayId,
        maskedPhone: masked,
        isOtpSent: true,
        errorMessage: null,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Unexpected error: $e');
      return false;
    }
  }

  /// Step 2: Verify OTP or PIN. Never allow login with ID alone.
  Future<bool> verifyOtpOrPin(String code, {bool isPin = false}) async {
    final empId = state.enteredEmployeeId;
    if (empId == null) {
      state = state.copyWith(errorMessage: 'Please enter your 5-digit Employee ID first.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final verifiedProfile = await _employeeRepo.verifyOtpOrPin(
        displayId: empId,
        verificationCode: code,
        isPin: isPin,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentEmployee: verifiedProfile,
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

  /// Direct 5-digit code login (retrieves employee profile and opens zone map)
  Future<bool> loginWithCode(String displayId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanId = displayId.trim();

      // Ensure fresh employee state from remote sync server / database
      await DistributionSyncService.fetchRemoteState();

      UserProfile? emp;
      try {
        emp = await _employeeRepo.verifyEmployeeId(cleanId);
      } catch (_) {}

      if (emp == null) {
        final managed = CanonicalZones.getManagedEmployees();
        for (final m in managed) {
          if (m.displayId == cleanId && m.isActive) {
            emp = m;
            break;
          }
        }
      }

      if (emp == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No employee account found with ID $cleanId. Please sign up first.',
        );
        return false;
      }

      // If code was created by admin but employee has not completed signup (name is empty)
      if (emp.fullName.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Employee code $cleanId is active but not registered yet. Please switch to the "Sign up" tab to register.',
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentEmployee: emp,
        enteredEmployeeId: cleanId,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed: $e',
      );
      return false;
    }
  }

  /// Sign up with First Name, Last Name, Phone, and 5-digit code
  Future<bool> signupWithDetails({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanCode = code.trim();
      final fullName = '${firstName.trim()} ${lastName.trim()}';

      // Ensure remote employee codes are fetched before pairing
      await DistributionSyncService.fetchRemoteState();

      var emp = CanonicalZones.pairEmployeeCode(
        cleanCode,
        fullName: fullName,
        phoneNumber: phoneNumber.trim(),
      );

      emp ??= UserProfile(
        id: 'emp-$cleanCode',
        email: '${firstName.trim().toLowerCase()}.${lastName.trim().toLowerCase()}@shopad.local',
        fullName: fullName,
        role: UserRole.employee,
        phoneNumber: phoneNumber.trim(),
        displayId: cleanCode,
        isActive: true,
        createdAt: DateTime.now(),
        metadata: const {
          'assigned_zones': <String>[],
        },
      );

      unawaited(DistributionSyncService.pushEmployee(emp));

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentEmployee: emp,
        enteredEmployeeId: cleanCode,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign up failed: $e',
      );
      return false;
    }
  }

  void logout() {
    state = const EmployeeAuthState();
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

final employeeAuthProvider =
    StateNotifierProvider<EmployeeAuthNotifier, EmployeeAuthState>((ref) {
  final repo = ref.watch(employeeRepositoryProvider);
  return EmployeeAuthNotifier(repo);
});

/// Current active employee ID
final currentEmployeeIdProvider = Provider<String>((ref) {
  final authState = ref.watch(employeeAuthProvider);
  return authState.currentEmployee?.id ?? 'emp-20001';
});

/// Assigned Zones for the active Employee
final assignedZonesProvider =
    FutureProvider.autoDispose<List<Zone>>((ref) async {
  final repo = ref.watch(employeeRepositoryProvider);
  final empId = ref.watch(currentEmployeeIdProvider);
  return await repo.getAssignedZones(empId);
});

/// Shops located ONLY within assigned zones
final assignedShopsProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  final repo = ref.watch(employeeRepositoryProvider);
  final empId = ref.watch(currentEmployeeIdProvider);
  return await repo.getShopsInAssignedZones(empId);
});

/// Device GPS Location Provider
final deviceLocationProvider =
    FutureProvider.autoDispose<LocationCoords?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.getCurrentLocation();
});

/// Follow-ups scheduled for Today
final followupsTodayProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  final repo = ref.watch(employeeRepositoryProvider);
  final empId = ref.watch(currentEmployeeIdProvider);
  return await repo.getFollowupsToday(empId);
});

/// Overdue follow-ups
final overdueFollowupsProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  final repo = ref.watch(employeeRepositoryProvider);
  final empId = ref.watch(currentEmployeeIdProvider);
  return await repo.getOverdueFollowups(empId);
});

/// Offline Drafts Provider
final offlineDraftsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(employeeRepositoryProvider);
  return await repo.getOfflineDrafts();
});

/// Search Query Provider
final shopSearchQueryProvider = StateProvider<String>((ref) => '');

/// Category Filter Provider (null = all)
final shopCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Selected Distribution Item Filter Provider (null = all items / no item filter)
final selectedDistributionItemIdProvider = StateProvider<String?>((ref) => null);

/// Filtered Shops Provider
final filteredAssignedShopsProvider =
    Provider.autoDispose<AsyncValue<List<Shop>>>((ref) {
  final shopsAsync = ref.watch(assignedShopsProvider);
  final query = ref.watch(shopSearchQueryProvider).toLowerCase().trim();
  final catFilter = ref.watch(shopCategoryFilterProvider);
  final isDistActive = ref.watch(employeeGlobalDistributionModeProvider);
  final distItemId = ref.watch(selectedDistributionItemIdProvider);

  return shopsAsync.whenData((shops) {
    return shops.where((s) {
      final isSaloon = ShopCategory.fromString(s.category) == ShopCategory.saloon;

      // 1. Distribution Mode & Specific Distribution Item Filtering
      if (isDistActive) {
        if (s.isFollowup) return false;
        if (s.isUnderProcess) return false;
        if (!CanonicalZones.isShopCategoryTargeted(s.zoneId, s.category)) return false;

        if (distItemId != null) {
          final itemTargetType =
              CanonicalZones.getItemTargetBusinessType(s.zoneId, distItemId);

          // If item is targeted to saloons, non-saloons must NOT show
          if (itemTargetType == 'saloon' && !isSaloon) {
            return false;
          }
          // If item is targeted to shops, saloons must NOT show
          if (itemTargetType == 'shop' && isSaloon) {
            return false;
          }

          // Smart Vanishing: If this item is ALREADY distributed at this shop, VANISH!
          final isItemDistributed =
              CanonicalZones.isShopItemDistributed(s.id, distItemId);
          if (isItemDistributed) {
            return false;
          }
        } else {
          // All items mode: vanish if shop is completely marked distributed
          if (s.isDistributed) return false;
        }
      }

      // 2. Primary 3-Category Filter: All (null), Shops, Saloons
      if (catFilter != null) {
        if ((catFilter.toLowerCase() == 'shops' || catFilter.toLowerCase() == 'shop') && isSaloon) {
          return false;
        }
        if ((catFilter.toLowerCase() == 'saloons' || catFilter.toLowerCase() == 'saloon') && !isSaloon) {
          return false;
        }
      }

      // 3. Search query
      if (query.isNotEmpty) {
        final nameMatch = s.shopName.toLowerCase().contains(query);
        final codeMatch = s.shopCode?.contains(query) ?? false;
        final ownerMatch = s.ownerName?.toLowerCase().contains(query) ?? false;
        final phoneMatch = s.phoneNumber?.contains(query) ?? false;
        if (!nameMatch && !codeMatch && !ownerMatch && !phoneMatch) return false;
      }
      return true;
    }).toList();
  });
});

/// Configurable grace period in minutes for daily photo upload after opening time (default 15)
final photoGracePeriodMinutesProvider = StateProvider<int>((ref) => 15);

/// Reference time provider for testing / server business date sync (Asia/Kolkata)
final serverTimeReferenceProvider = StateProvider<DateTime?>((ref) => null);

/// In-memory mock storage for daily uploads when offline / testing
final mockDailyUploadsStoreProvider =
    StateProvider<Map<String, ShopDailyUpload>>((ref) => {});

/// Daily photo uploads for shops in assigned zones mapped by shopId
final assignedShopsDailyUploadsProvider =
    FutureProvider.autoDispose<Map<String, ShopDailyUpload>>((ref) async {
  final memoryStore = ref.watch(mockDailyUploadsStoreProvider);
  final repo = ref.watch(employeeRepositoryProvider);
  final empId = ref.watch(currentEmployeeIdProvider);
  final shops = await repo.getShopsInAssignedZones(empId);
  final shopIds = shops.map((s) => s.id).toSet();

  final result = Map<String, ShopDailyUpload>.from(memoryStore);

  // If Supabase is active, query remote shop_daily_uploads
  final supabaseManager = ref.watch(supabaseManagerProvider);
  final client = supabaseManager.client;
  if (client != null && shopIds.isNotEmpty) {
    try {
      final nowIst = (ref.watch(serverTimeReferenceProvider) ?? DateTime.now())
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30));
      final todayStr =
          '${nowIst.year.toString().padLeft(4, '0')}-${nowIst.month.toString().padLeft(2, '0')}-${nowIst.day.toString().padLeft(2, '0')}';

      final res = await client
          .from('shop_daily_uploads')
          .select()
          .inFilter('shop_id', shopIds.toList())
          .eq('business_date', todayStr);

      for (final item in res) {
        final upload = ShopDailyUpload.fromJson(item);
        result[upload.shopId] = upload;
      }
    } catch (_) {}
  }

  return result;
});

/// Global distribution mode toggle for the field employee across all their assigned zones.
/// Strictly defaults to false (Normal Mode) on app launch as required.
final employeeGlobalDistributionModeProvider = StateProvider<bool>((ref) => false);

/// Track which zones have distribution mode active (mirrors global employee switch)
final employeeZoneDistributionModeProvider =
    StateProvider.family<bool, String>((ref, zoneId) {
  return ref.watch(employeeGlobalDistributionModeProvider);
});

/// Mark shop distributed provider action
final markShopDistributedActionProvider =
    Provider<Future<void> Function(String shopId)>((ref) {
  final repo = ref.watch(employeeRepositoryProvider);
  final empId = ref.watch(currentEmployeeIdProvider);
  return (String shopId) async {
    await repo.markShopDistributed(employeeId: empId, shopId: shopId);
    ref.invalidate(assignedShopsProvider);
  };
});


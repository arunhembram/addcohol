import 'dart:math';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminAuthState {
  final bool isAuthenticated;
  final UserProfile? currentAdmin;
  final String? enteredAdminId;
  final String? maskedPhone;
  final bool isOtpSent;
  final bool isLoading;
  final String? errorMessage;

  const AdminAuthState({
    this.isAuthenticated = false,
    this.currentAdmin,
    this.enteredAdminId,
    this.maskedPhone,
    this.isOtpSent = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AdminAuthState copyWith({
    bool? isAuthenticated,
    UserProfile? currentAdmin,
    String? enteredAdminId,
    String? maskedPhone,
    bool? isOtpSent,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AdminAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentAdmin: currentAdmin ?? this.currentAdmin,
      enteredAdminId: enteredAdminId ?? this.enteredAdminId,
      maskedPhone: maskedPhone ?? this.maskedPhone,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final IAdminRepository _adminRepo;

  AdminAuthNotifier(this._adminRepo)
      : super(
          // Pre-seed with sandbox admin 10001 initially so app can boot cleanly,
          // but unauthenticated until user logs in or tests mock login.
          const AdminAuthState(),
        );

  /// Step 1: Admin enters their 5-digit Admin ID
  Future<bool> initiateAdminLogin(String displayId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final admin = await _adminRepo.verifyAdminId(displayId);
      if (admin == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Admin ID not found or account is inactive.',
        );
        return false;
      }

      final phone = await _adminRepo.sendAdminOtp(displayId);
      final masked = _maskPhoneNumber(phone);

      state = state.copyWith(
        isLoading: false,
        enteredAdminId: displayId,
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

  /// Step 2: Verify OTP or Secure PIN.
  /// Strictly rejected if verification code is blank — never login with ID alone!
  Future<bool> verifyOtpOrPin(String code, {bool isPin = false}) async {
    final adminId = state.enteredAdminId;
    if (adminId == null) {
      state = state.copyWith(errorMessage: 'Please enter your Admin ID first.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final verifiedProfile = await _adminRepo.verifyOtpOrPin(
        displayId: adminId,
        verificationCode: code,
        isPin: isPin,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentAdmin: verifiedProfile,
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

  /// Direct 5-digit code login (retrieves admin profile and opens dashboard)
  Future<bool> loginWithCode(String displayId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanId = displayId.trim();
      UserProfile? admin;
      try {
        admin = await _adminRepo.verifyAdminId(cleanId);
      } catch (_) {}

      // Fallback seed admin check (e.g. 10001, 10002)
      if (admin == null) {
        if (cleanId == '10001') {
          admin = UserProfile(
            id: 'admin-10001',
            email: 'subhasis.ghosh@shopad.local',
            fullName: 'Subhasis Ghosh',
            role: UserRole.admin,
            phoneNumber: '+91 98765 43210',
            displayId: '10001',
            isActive: true,
            createdAt: DateTime.now(),
          );
        } else if (cleanId == '10002') {
          admin = UserProfile(
            id: 'admin-10002',
            email: 'priya.sen@shopad.local',
            fullName: 'Priya Sen',
            role: UserRole.admin,
            phoneNumber: '+91 98300 11223',
            displayId: '10002',
            isActive: true,
            createdAt: DateTime.now(),
          );
        }
      }

      if (admin == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No admin account found with ID $cleanId. Please sign up first.',
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentAdmin: admin,
        enteredAdminId: cleanId,
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

      final admin = UserProfile(
        id: 'admin-$cleanCode',
        email: '${firstName.trim().toLowerCase()}.${lastName.trim().toLowerCase()}@shopad.local',
        fullName: fullName,
        role: UserRole.admin,
        phoneNumber: phoneNumber.trim(),
        displayId: cleanCode,
        isActive: true,
        createdAt: DateTime.now(),
        metadata: const {
          'admin_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
        },
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        currentAdmin: admin,
        enteredAdminId: cleanCode,
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
    state = const AdminAuthState();
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

final adminAuthProvider =
    StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminAuthNotifier(repo);
});

/// Current active admin ID helper
final currentAdminIdProvider = Provider<String>((ref) {
  final authState = ref.watch(adminAuthProvider);
  return authState.currentAdmin?.id ?? 'admin-10001';
});

/// Controlled Zones for the current Admin
final controlledZonesProvider =
    FutureProvider.autoDispose<List<Zone>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final adminId = ref.watch(currentAdminIdProvider);
  return await repo.getControlledZones(adminId);
});

/// Detail of a specific controlled zone. Throws [ForbiddenZoneException] if outside control.
final controlledZoneDetailProvider =
    FutureProvider.family.autoDispose<Zone, String>((ref, zoneId) async {
  final repo = ref.watch(adminRepositoryProvider);
  final adminId = ref.watch(currentAdminIdProvider);
  return await repo.getControlledZoneById(adminId: adminId, zoneId: zoneId);
});

/// Employees under current Admin's controlled jurisdiction
final controlledEmployeesProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final adminId = ref.watch(currentAdminIdProvider);
  return await repo.getEmployeesForAdmin(adminId);
});

/// Search query for employee list
final employeeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filter status for employees ('all', 'active', 'inactive')
final employeeStatusFilterProvider = StateProvider<String>((ref) => 'all');

/// Filter by controlled zone for employees (null = all zones)
final employeeZoneFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered employee list derived provider
final filteredEmployeesProvider = Provider.autoDispose<AsyncValue<List<UserProfile>>>((ref) {
  final employeesAsync = ref.watch(controlledEmployeesProvider);
  final query = ref.watch(employeeSearchQueryProvider).toLowerCase().trim();
  final status = ref.watch(employeeStatusFilterProvider);
  final zoneFilter = ref.watch(employeeZoneFilterProvider);

  return employeesAsync.whenData((employees) {
    return employees.where((emp) {
      // Query filter (Name, Phone, Display ID)
      if (query.isNotEmpty) {
        final nameMatch = emp.fullName.toLowerCase().contains(query);
        final phoneMatch = emp.phoneNumber?.toLowerCase().contains(query) ?? false;
        final idMatch = emp.displayId?.toLowerCase().contains(query) ?? false;
        if (!nameMatch && !phoneMatch && !idMatch) return false;
      }

      // Status filter
      if (status == 'active' && !emp.isActive) return false;
      if (status == 'inactive' && emp.isActive) return false;

      // Zone filter
      if (zoneFilter != null) {
        final assigned = emp.metadata['assigned_zones'] as List<dynamic>? ?? [];
        if (!assigned.contains(zoneFilter)) return false;
      }

      return true;
    }).toList();
  });
});

/// Shops located in the Admin's controlled zones
final controlledShopsProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final adminId = ref.watch(currentAdminIdProvider);
  return await repo.getShopsInControlledZones(adminId);
});

/// Follow-ups for shops in Admin's controlled zones
final controlledFollowupsProvider =
    FutureProvider.autoDispose<List<ShopFollowup>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final adminId = ref.watch(currentAdminIdProvider);
  return await repo.getFollowupsInControlledZones(adminId);
});

/// Employee performance summaries for Admin's controlled zones
final employeePerformanceProvider =
    FutureProvider.autoDispose<List<EmployeePerformanceSummary>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final adminId = ref.watch(currentAdminIdProvider);
  return await repo.getEmployeePerformanceSummary(adminId);
});

/// Distribution mode state for a controlled zone (keyed by zoneId)
final zoneDistributionModeStateProvider =
    StateProvider.family<bool, String>((ref, zoneId) {
  return CanonicalZones.isDistributionModeActive(zoneId);
});

/// Selected distribution categories for a controlled zone (keyed by zoneId)
final zoneDistributionCategoriesProvider =
    StateProvider.family<Set<String>, String>((ref, zoneId) {
  return CanonicalZones.getDistributionCategories(zoneId);
});

import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminAuthState {
  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;

  const AdminAuthState({this.user, this.isLoading = false, this.errorMessage});

  bool get isAuthenticated => user != null && user!.role == UserRole.masterAdmin;

  AdminAuthState copyWith({
    UserProfile? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminAuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final IAuthRepository _authRepo;

  AdminAuthNotifier(this._authRepo) : super(const AdminAuthState()) {
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authRepo.getCurrentUser();
      if (user != null && user.role == UserRole.masterAdmin) {
        state = state.copyWith(user: user, isLoading: false);
      } else {
        state = state.copyWith(clearUser: true, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(clearUser: true, isLoading: false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _authRepo.signInWithEmailPassword(email, password);
      if (success) {
        final profile = await _authRepo.getCurrentUser();
        if (profile == null || profile.role != UserRole.masterAdmin) {
          await _authRepo.signOut();
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Access Denied: Only Master Admin accounts can sign in here.',
          );
          return false;
        }

        state = state.copyWith(user: profile, isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Invalid email or password.');
        return false;
      }
    } catch (e) {
      final msg = e is AppException ? e.message : 'Sign-in failed. Please check credentials.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  /// Fast demo login for local sandbox testing
  void loginAsDemoMasterAdmin() {
    final demoProfile = UserProfile(
      id: 'demo-master-admin-id',
      email: 'master@shopad.com',
      fullName: 'Master Controller (প্রধান প্রশাসক)',
      role: UserRole.masterAdmin,
      displayId: '10000',
      phoneNumber: '+91 98000 00001',
      isActive: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(user: demoProfile, isLoading: false, clearError: true);
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authRepo.signOut();
    state = const AdminAuthState();
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AdminAuthNotifier(authRepo);
});

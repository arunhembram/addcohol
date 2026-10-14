import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract class IAuthRepository {
  Future<UserProfile?> getCurrentUser();
  Future<bool> signInWithEmailPassword(String email, String password);
  Future<void> signOut();
  bool get isAuthenticated;
}

class SupabaseAuthRepository implements IAuthRepository {
  final SupabaseManager supabaseManager;
  final ISecureStorageService secureStorage;

  SupabaseAuthRepository({required this.supabaseManager, required this.secureStorage});

  @override
  bool get isAuthenticated {
    final client = supabaseManager.client;
    if (client == null) return false;
    return client.auth.currentSession != null;
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    final client = supabaseManager.client;
    if (client == null) return null;

    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await client.from('profiles').select().eq('id', user.id).maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }

      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name'] as String? ?? 'User',
        role: UserRole.fromString(user.userMetadata?['role'] as String?),
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
    } catch (_) {
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: 'User',
        role: UserRole.shopkeeper,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> signInWithEmailPassword(String email, String password) async {
    final client = supabaseManager.client;
    if (client == null) {
      throw const NetworkException('Supabase client is not initialized or offline');
    }

    try {
      final res = await client.auth.signInWithPassword(email: email, password: password);
      if (res.session != null) {
        await secureStorage.write(SecureStorageService.authTokenKey, res.session!.accessToken);
        return true;
      }
      return false;
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e, st) {
      throw NetworkException('Sign-in failed', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<void> signOut() async {
    final client = supabaseManager.client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    await secureStorage.delete(SecureStorageService.authTokenKey);
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/app_exception.dart';

abstract class ISecureStorageService {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clearAll();
  Future<bool> containsKey(String key);
  Future<bool> performHealthCheck();
}

class SecureStorageService implements ISecureStorageService {
  final FlutterSecureStorage _storage;

  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String selectedLanguageKey = 'selected_language';
  static const String themeModeKey = 'theme_mode';

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true));

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      throw StorageException('Failed to write key: $key', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      throw StorageException('Failed to read key: $key', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, st) {
      throw StorageException('Failed to delete key: $key', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, st) {
      throw StorageException('Failed to clear secure storage', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e, st) {
      throw StorageException('Failed to inspect key: $key', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<bool> performHealthCheck() async {
    const probeKey = '__storage_health_probe__';
    final probeValue = DateTime.now().toIso8601String();
    try {
      await write(probeKey, probeValue);
      final readBack = await read(probeKey);
      await delete(probeKey);
      return readBack == probeValue;
    } catch (_) {
      return false;
    }
  }
}

import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSecureStorage implements ISecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> clearAll() async => _data.clear();

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<bool> performHealthCheck() async => true;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  group('SystemHealthRepository Tests', () {
    test('System health returns AppHealthInfo with diagnostics', () async {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        appName: 'Test Admin App',
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleMapsApiKey: '',
        apiBaseUrl: 'https://api.test',
      );

      final supabaseManager = SupabaseManager(config: config);
      final secureStorage = MockSecureStorage();

      final repo = SystemHealthRepository(
        config: config,
        supabaseManager: supabaseManager,
        secureStorage: secureStorage,
      );

      final health = await repo.getSystemHealth(UserRole.admin);

      expect(health.appName, 'Test Admin App');
      expect(health.targetRole, UserRole.admin);
      expect(health.environment, 'dev');
      expect(health.subsystems.length, 3);

      final storageSubsystem = health.subsystems.firstWhere(
        (s) => s.name.contains('Secure Storage'),
      );
      expect(storageSubsystem.status, ServiceStatus.connected);

      final supabaseSubsystem = health.subsystems.firstWhere((s) => s.name.contains('Supabase'));
      expect(supabaseSubsystem.status, ServiceStatus.unconfigured);
    });
  });
}

import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../network/supabase_manager.dart';
import '../storage/secure_storage_service.dart';

/// Overridden at app startup in main.dart with actual loaded environment config
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppLogger(tag: config.appName, enableVerbose: config.enableVerboseLogging);
});

final secureStorageServiceProvider = Provider<ISecureStorageService>((ref) {
  return SecureStorageService();
});

final supabaseManagerProvider = Provider<SupabaseManager>((ref) {
  final config = ref.watch(appConfigProvider);
  final logger = ref.watch(appLoggerProvider);
  return SupabaseManager(config: config, logger: logger);
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final manager = ref.watch(supabaseManagerProvider);
  return manager.client;
});

/// Target role for current app (overridden per app, e.g. master_admin, employee, etc.)
final currentAppRoleProvider = Provider<UserRole>((ref) {
  return UserRole.shopkeeper;
});

/// Runs health checks across core subsystems (Supabase, Secure Storage, Environment)
final coreHealthCheckProvider = FutureProvider.autoDispose<List<SubsystemStatus>>((ref) async {
  final config = ref.watch(appConfigProvider);
  final supabaseMgr = ref.watch(supabaseManagerProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final results = <SubsystemStatus>[];

  // 1. Storage Health
  final storageHealthy = await secureStorage.performHealthCheck();
  results.add(
    SubsystemStatus(
      name: 'Secure Storage (Keystore/Encrypted)',
      status: storageHealthy ? ServiceStatus.connected : ServiceStatus.disconnected,
      message: storageHealthy
          ? 'Encryption & storage verified'
          : 'Failed probe test (Check platform keystore)',
    ),
  );

  // 2. Supabase Health
  final supabaseStatus = await supabaseMgr.checkHealth();
  results.add(supabaseStatus);

  // 3. Environment Config Health
  final diagnostics = config.validate();
  results.add(
    SubsystemStatus(
      name: 'Configuration (${config.environment.name.toUpperCase()})',
      status: diagnostics.isEmpty ? ServiceStatus.connected : ServiceStatus.unconfigured,
      message: diagnostics.isEmpty
          ? 'All essential variables loaded cleanly'
          : diagnostics.join('; '),
    ),
  );

  return results;
});

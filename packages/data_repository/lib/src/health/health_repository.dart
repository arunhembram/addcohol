import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';

abstract class IHealthRepository {
  Future<AppHealthInfo> getSystemHealth(UserRole targetRole);
}

class SystemHealthRepository implements IHealthRepository {
  final AppConfig config;
  final SupabaseManager supabaseManager;
  final ISecureStorageService secureStorage;

  const SystemHealthRepository({
    required this.config,
    required this.supabaseManager,
    required this.secureStorage,
  });

  @override
  Future<AppHealthInfo> getSystemHealth(UserRole targetRole) async {
    final subsystems = <SubsystemStatus>[];

    // 1. Storage Health
    final storageOk = await secureStorage.performHealthCheck();
    subsystems.add(
      SubsystemStatus(
        name: 'Secure Storage (Keystore / SharedPreferences)',
        status: storageOk ? ServiceStatus.connected : ServiceStatus.disconnected,
        message: storageOk
            ? 'AES hardware-backed keystore operational'
            : 'Probe read/write cycle failed',
      ),
    );

    // 2. Supabase Backend Health
    final sbStatus = await supabaseManager.checkHealth();
    subsystems.add(sbStatus);

    // 3. Environment & Secrets Check
    final diagnostics = config.validate();
    subsystems.add(
      SubsystemStatus(
        name: 'Environment Secrets (${config.environment.name.toUpperCase()})',
        status: diagnostics.isEmpty ? ServiceStatus.connected : ServiceStatus.unconfigured,
        message: diagnostics.isEmpty
            ? 'Client environment variables verified'
            : diagnostics.join('\n'),
      ),
    );

    // Determine overall health
    final hasDisconnected = subsystems.any((s) => s.status == ServiceStatus.disconnected);
    final hasUnconfigured = subsystems.any((s) => s.status == ServiceStatus.unconfigured);

    AppHealthState overallState;
    if (hasDisconnected) {
      overallState = AppHealthState.unhealthy;
    } else if (hasUnconfigured) {
      overallState = AppHealthState.degraded;
    } else {
      overallState = AppHealthState.healthy;
    }

    return AppHealthInfo(
      appName: config.appName,
      targetRole: targetRole,
      environment: config.environment.name,
      overallState: overallState,
      checkTimestamp: DateTime.now(),
      subsystems: subsystems,
    );
  }
}

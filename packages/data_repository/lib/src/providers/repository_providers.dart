import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin/admin_repository.dart';
import '../auth/auth_repository.dart';
import '../campaign/campaign_repository.dart';
import '../employee/employee_repository.dart';
import '../health/health_repository.dart';
import '../master_admin/master_admin_repository.dart';
import '../shop/shop_repository.dart';
import '../shopkeeper/shopkeeper_repository.dart';
import '../payment/payment_acknowledgement_repository.dart';
import '../company/company_repository.dart';

final adminRepositoryProvider = Provider<IAdminRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseAdminRepository(supabaseManager: supabaseManager);
});

final employeeRepositoryProvider = Provider<IEmployeeRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseEmployeeRepository(supabaseManager: supabaseManager);
});

final shopkeeperRepositoryProvider = Provider<IShopkeeperRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseShopkeeperRepository(supabaseManager: supabaseManager);
});

final paymentAcknowledgementRepositoryProvider =
    Provider<IPaymentAcknowledgementRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabasePaymentAcknowledgementRepository(
    supabaseManager: supabaseManager,
  );
});

final companyRepositoryProvider = Provider<ICompanyRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseCompanyRepository(supabaseManager: supabaseManager);
});



final healthRepositoryProvider = Provider<IHealthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final supabaseManager = ref.watch(supabaseManagerProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  return SystemHealthRepository(
    config: config,
    supabaseManager: supabaseManager,
    secureStorage: secureStorage,
  );
});

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  return SupabaseAuthRepository(supabaseManager: supabaseManager, secureStorage: secureStorage);
});

final masterAdminRepositoryProvider = Provider<IMasterAdminRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseMasterAdminRepository(supabaseManager: supabaseManager);
});

final shopRepositoryProvider = Provider<IShopRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseShopRepository(supabaseManager: supabaseManager);
});

final campaignRepositoryProvider = Provider<ICampaignRepository>((ref) {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  return SupabaseCampaignRepository(supabaseManager: supabaseManager);
});

/// Runs comprehensive app health diagnostics for the current app's target role
final appHealthDiagnosticsProvider = FutureProvider.autoDispose<AppHealthInfo>((ref) async {
  final healthRepo = ref.watch(healthRepositoryProvider);
  final targetRole = ref.watch(currentAppRoleProvider);
  return await healthRepo.getSystemHealth(targetRole);
});

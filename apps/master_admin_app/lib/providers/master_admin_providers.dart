import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final repo = ref.watch(masterAdminRepositoryProvider);
  return await repo.getDashboardStats();
});

final zonesListProvider = FutureProvider.autoDispose<List<Zone>>((ref) async {
  final repo = ref.watch(masterAdminRepositoryProvider);
  return await repo.getZones(includeArchived: true);
});

final zoneDetailProvider = FutureProvider.autoDispose.family<Zone?, String>((ref, id) async {
  final repo = ref.watch(masterAdminRepositoryProvider);
  return await repo.getZoneById(id);
});

final adminsListProvider = FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final repo = ref.watch(masterAdminRepositoryProvider);
  return await repo.getAdmins();
});

final companiesListProvider = FutureProvider.autoDispose<List<Company>>((ref) async {
  final repo = ref.watch(masterAdminRepositoryProvider);
  return await repo.getCompanies();
});

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final repo = ref.watch(masterAdminRepositoryProvider);
  return await repo.getAuditLogs(limit: 50);
});

/// All registered retail shops across zones for interactive map inspection
final masterAdminShopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) async {
  final supabaseManager = ref.watch(supabaseManagerProvider);
  final client = supabaseManager.client;
  if (client != null) {
    try {
      final res = await client.from('shops').select();
      if (res.isNotEmpty) {
        return (res as List).map((s) => Shop.fromJson(s as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  // Canonical shops dataset fallback across system zones
  return CanonicalShops.all;
});

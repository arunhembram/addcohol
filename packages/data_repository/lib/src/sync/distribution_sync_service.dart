import 'dart:async';
import 'dart:convert';
import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../canonical_zones.dart';
import '../canonical_shops.dart';

/// Lightweight cross-port / cross-app sync service for Distribution Mode & Zone Pricing.
/// Synchronizes across local development ports (port 8081, 8083) via the local sync server,
/// and synchronizes live production deployments via Supabase Realtime (PostgreSQL CDC).
class DistributionSyncService {
  DistributionSyncService._();

  static const String _syncServerUrl = 'http://localhost:8089/distribution-state';
  static bool _isSyncing = false;
  static DateTime? _lastSyncTime;
  static bool isSyncEnabled = true;
  static RealtimeChannel? _supabasePricingChannel;

  static DateTime? get lastSyncTime => _lastSyncTime;

  static SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize Supabase Realtime subscription for live production synchronization.
  /// Automatically called whenever Supabase is configured and active.
  static void initSupabaseRealtimePricing() {
    final client = _supabaseClient;
    if (client == null || _supabasePricingChannel != null) return;
    try {
      _supabasePricingChannel = client
          .channel('public:zone_pricing')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'zone_pricing',
            callback: (payload) {
              final newRec = payload.newRecord;
              if (newRec.isNotEmpty) {
                final config = ZonePricingConfig.fromJson(newRec);
                CanonicalZones.syncRemoteZonePricings({config.zoneId: config});
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  /// Fetch remote distribution state from Supabase (production) or local sync server (development)
  static Future<bool> fetchRemoteState() async {
    // 0. Ensure Supabase Realtime channel is active when connected to Supabase
    initSupabaseRealtimePricing();

    // 0b. Fetch from Supabase zone_pricing table if Supabase is active
    final client = _supabaseClient;
    if (client != null) {
      try {
        final res = await client
            .from('zone_pricing')
            .select()
            .timeout(const Duration(seconds: 3));
        if (res.isNotEmpty) {
          final Map<String, ZonePricingConfig> configs = {};
          for (final row in res) {
            final config = ZonePricingConfig.fromJson(row);
            configs[config.zoneId] = config;
          }
          if (configs.isNotEmpty) {
            CanonicalZones.syncRemoteZonePricings(configs);
          }
        }
      } catch (_) {}
    }
    if (!isSyncEnabled) return false;
    if (_isSyncing) return false;
    _isSyncing = true;
    try {
      final response = await http
          .get(Uri.parse(_syncServerUrl))
          .timeout(const Duration(milliseconds: 1200));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // 1. Sync zones
        if (data['zones'] is Map<String, dynamic>) {
          final zones = data['zones'] as Map<String, dynamic>;
          for (final entry in zones.entries) {
            if (entry.value is bool) {
              final active = entry.value == true;
              CanonicalZones.setDistributionMode(entry.key, active, syncRemote: false);
            } else if (entry.value is Map<String, dynamic>) {
              final map = entry.value as Map<String, dynamic>;
              final active = map['enabled'] == true;
              final driveCompleted = map['driveCompleted'] == true;
              final startTimeStr = map['startTime'] as String?;
              final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) : null;
              final cats = (map['categories'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toSet();

              if (startTime != null) {
                CanonicalZones.setDistributionStartTime(entry.key, startTime);
              }
              CanonicalZones.setZoneDriveCompleted(entry.key, driveCompleted, syncRemote: false);
              CanonicalZones.setDistributionMode(
                entry.key,
                active,
                categories: cats,
                driveCompleted: driveCompleted,
                startTime: startTime,
                syncRemote: false,
              );
            }
          }
        }

        // 2. Sync shop states
        final distributed = (data['distributedShops'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final gone = (data['goneShops'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final closedToday = (data['closedTodayShops'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final crossed = (data['crossedShops'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

        CanonicalShops.syncRemoteShops(
          distributedShops: distributed,
          goneShops: gone,
          closedTodayShops: closedToday,
          crossedShops: crossed,
        );

        // 3. Sync materials
        if (data['materials'] is List) {
          final matsJson = data['materials'] as List;
          final mats = matsJson
              .whereType<Map<String, dynamic>>()
              .map((j) => DistributionMaterial.fromJson(j))
              .toList();
          if (mats.isNotEmpty) {
            CanonicalZones.syncRemoteMaterials(mats);
          }
        }

        // 4. Sync material run statuses
        if (data['materialRunStatuses'] is Map<String, dynamic>) {
          CanonicalZones.syncRemoteMaterialRunStatuses(
              data['materialRunStatuses'] as Map<String, dynamic>);
        }

        // 5. Sync custom zones created/updated by Master Admin
        if (data['customZones'] is List) {
          final zonesJson = data['customZones'] as List;
          final zones = zonesJson
              .whereType<Map<String, dynamic>>()
              .map((j) => Zone.fromJson(j))
              .toList();
          if (zones.isNotEmpty) {
            CanonicalZones.syncRemoteZones(zones);
          }
        }

        // 6. Sync zone pricing overrides configured by Master Admin
        if (data['zonePricings'] is Map<String, dynamic>) {
          final pricingsJson = data['zonePricings'] as Map<String, dynamic>;
          final Map<String, ZonePricingConfig> configs = {};
          for (final entry in pricingsJson.entries) {
            if (entry.value is Map<String, dynamic>) {
              configs[entry.key] = ZonePricingConfig.fromJson(
                entry.value as Map<String, dynamic>,
              );
            }
          }
          if (configs.isNotEmpty) {
            CanonicalZones.syncRemoteZonePricings(configs);
          }
        }

        // 7. Sync employee zone assignments
        if (data['employeeZoneAssignments'] is Map<String, dynamic>) {
          final assignJson = data['employeeZoneAssignments'] as Map<String, dynamic>;
          final Map<String, List<String>> assignments = {};
          for (final entry in assignJson.entries) {
            if (entry.value is List) {
              assignments[entry.key] =
                  (entry.value as List).map((e) => e.toString()).toList();
            }
          }
          if (assignments.isNotEmpty) {
            CanonicalZones.syncRemoteEmployeeAssignments(assignments);
          }
        }

        _lastSyncTime = DateTime.now();
        return true;
      }
    } catch (_) {
      // Local sync server offline or unreachable; fall back gracefully
    } finally {
      _isSyncing = false;
    }
    return false;
  }

  /// Push employee zone assignment to sync server and Supabase
  static Future<void> pushEmployeeZoneAssignment(
    String employeeId,
    List<String> zoneIds,
  ) async {
    final client = _supabaseClient;
    if (client != null) {
      try {
        await client
            .from('employee_zone_assignments')
            .delete()
            .eq('employee_id', employeeId);
        for (final zid in zoneIds) {
          await client.from('employee_zone_assignments').insert({
            'employee_id': employeeId,
            'zone_id': zid,
          });
        }
      } catch (_) {}
    }

    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'employeeZoneAssignment': {
                'employeeId': employeeId,
                'zoneIds': zoneIds,
              },
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Push zone distribution mode toggle, categories and drive status to sync server
  static Future<void> pushZoneMode(
    String zoneId,
    bool enabled, {
    List<String>? categories,
    bool? driveCompleted,
    String? startTime,
  }) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'zoneId': zoneId,
              'enabled': enabled,
              'categories': ?categories,
              'driveCompleted': ?driveCompleted,
              'startTime': ?startTime,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Silently fall back if sync server is offline
    }
  }

  /// Push marked distributed shop to sync server
  static Future<void> pushShopDistributed(String shopId) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'markDistributedShopId': shopId,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Silently fall back if sync server is offline
    }
  }

  /// Push permanently gone shop to sync server
  static Future<void> pushShopGone(String shopId) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'markGoneShopId': shopId,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Silently fall back if sync server is offline
    }
  }

  /// Push shop closed today to sync server
  static Future<void> pushShopClosedToday(String shopId) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'markClosedTodayShopId': shopId,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Silently fall back if sync server is offline
    }
  }

  /// Push reset of zone distribution drive to sync server
  static Future<void> pushResetZoneDrive(String zoneId) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'resetZoneDriveId': zoneId,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Silently fall back if sync server is offline
    }
  }

  /// Push newly added or updated material to sync server
  static Future<void> pushMaterial(DistributionMaterial material) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'material': material.toJson(),
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Push material removal to sync server
  static Future<void> pushRemoveMaterial(String materialId) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'removeMaterialId': materialId,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Push material run toggle status to sync server
  static Future<void> pushMaterialRunToggle(
    String zoneId,
    String materialId,
    String status,
  ) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'materialRunToggle': {
                'zoneId': zoneId,
                'materialId': materialId,
                'status': status,
              },
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Push custom zone created or updated by Master Admin to sync server
  static Future<void> pushCustomZone(Zone zone) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'customZone': zone.toJson(),
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Push removal of custom zone to sync server
  static Future<void> pushRemoveZone(String zoneId) async {
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'removeZoneId': zoneId,
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Push zone pricing override to Supabase (live production) and local sync server (development)
  static Future<void> pushZonePricing(
    String zoneId,
    ZonePricingConfig config,
  ) async {
    // 1. Live Supabase upsert
    final client = _supabaseClient;
    if (client != null) {
      try {
        await client
            .from('zone_pricing')
            .upsert(config.toJson())
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    // 2. Development sync server
    if (!isSyncEnabled) return;
    try {
      await http
          .post(
            Uri.parse(_syncServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'zoneId': zoneId,
              'zonePricing': config.toJson(),
            }),
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }
}

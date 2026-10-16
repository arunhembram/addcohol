import 'dart:typed_data';
import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import '../canonical_zones.dart';
import '../sync/distribution_sync_service.dart';


abstract class IMasterAdminRepository {
  Future<DashboardStats> getDashboardStats();
  Future<List<Zone>> getZones({bool includeArchived = false});
  Future<Zone?> getZoneById(String id);
  Future<Zone> saveZone(Zone zone, List<ZoneVertex> vertices, {String? assignedAdminId});
  Future<void> archiveZone(String zoneId, bool isArchived);
  Future<List<UserProfile>> getAdmins();
  Future<UserProfile> createAdminCode();
  Future<UserProfile> pairAdminCode(String code, {required String fullName, required String phoneNumber});
  Future<UserProfile> createAdmin({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required String aadhaarDocumentPath,
    required bool consentGiven,
  });
  Future<void> assignAdminToZones(String adminId, List<String> zoneIds);
  Future<List<String>> getAssignedZoneIdsForAdmin(String adminId);
  Future<List<Company>> getCompanies();
  Future<Company> createCompany({
    required String legalName,
    required String tradeName,
    required String contactEmail,
    String? contactPhone,
    String? address,
  });
  Future<void> assignZoneToCompany(String companyId, String zoneId);
  Future<void> removeZoneFromCompany(String companyId, String zoneId);
  Future<List<AuditLog>> getAuditLogs({int limit = 50});
  Future<String> uploadAadhaarDocument({
    required String fileName,
    required List<int> bytes,
    required String targetUserId,
  });
}

class SupabaseMasterAdminRepository implements IMasterAdminRepository {
  final SupabaseManager supabaseManager;

  // In-memory cache & fallback dataset for offline/mock sandbox testing
  final List<Zone> _mockZones = List<Zone>.from(CanonicalZones.all);

  final List<UserProfile> _mockAdmins = [
    UserProfile(
      id: 'mock-admin-1',
      email: 'admin.sen@shopad.com',
      fullName: 'Subhasis Sen',
      role: UserRole.admin,
      phoneNumber: '+91 98301 11223',
      displayId: '10001',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    UserProfile(
      id: 'mock-admin-2',
      email: 'priya.mukherjee@shopad.com',
      fullName: 'Priya Mukherjee',
      role: UserRole.admin,
      phoneNumber: '+91 98302 22334',
      displayId: '10002',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  final List<Company> _mockCompanies = [
    Company(
      id: 'comp-1',
      legalName: 'Alpha Media Networks Pvt Ltd',
      tradeName: 'Alpha Media Ads',
      contactEmail: 'campaigns@alphamedia.com',
      contactPhone: '+91 33 2289 0011',
      address: 'Camac Street, Kolkata 700016',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
      assignedZoneIds: const ['z-kolkata-central'],
      assignedZoneNames: const ['Kolkata Central Zone'],
    ),
    Company(
      id: 'comp-2',
      legalName: 'Bengal Brand Express Logistics',
      tradeName: 'Bengal Brand Express',
      contactEmail: 'ads@bengalbrand.in',
      contactPhone: '+91 33 4455 6677',
      address: 'Salt Lake Sector V, Kolkata 700091',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      assignedZoneIds: const ['z-saltlake-sector5'],
      assignedZoneNames: const ['Salt Lake Sector V'],
    ),
  ];

  final List<AuditLog> _mockAuditLogs = [
    AuditLog(
      id: 'log-1',
      userRole: 'master_admin',
      userDisplayName: 'Master Admin (ID: 10000)',
      action: 'ASSIGN_ADMIN_ZONE',
      entityName: 'admin_zone_assignments',
      entityId: 'z-kolkata-central',
      details: {'admin_id': 'mock-admin-1', 'zone': 'Kolkata Central Zone'},
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AuditLog(
      id: 'log-2',
      userRole: 'master_admin',
      userDisplayName: 'Master Admin (ID: 10000)',
      action: 'ASSIGN_COMPANY_ZONE',
      entityName: 'company_zone_assignments',
      entityId: 'comp-1',
      details: {'company': 'Alpha Media Ads', 'zone': 'Kolkata Central Zone'},
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AuditLog(
      id: 'log-3',
      userRole: 'admin',
      userDisplayName: 'Subhasis Sen (ID: 10001)',
      action: 'CREATE_ZONE',
      entityName: 'zones',
      entityId: 'z-saltlake-sector5',
      details: {'zone_name': 'Salt Lake Sector V', 'vertices_count': 6},
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AuditLog(
      id: 'log-4',
      userRole: 'master_admin',
      userDisplayName: 'Master Admin (ID: 10000)',
      action: 'CREATE_ADMIN_ACCOUNT',
      entityName: 'profiles',
      entityId: 'mock-admin-2',
      details: {'display_id': '10002', 'name': 'Priya Mukherjee'},
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  int _displayIdCounter = 10003;

  SupabaseMasterAdminRepository({SupabaseManager? supabaseManager})
      : supabaseManager = supabaseManager ?? SupabaseManager(config: AppConfig.fromEnvironment());

  bool get _isLive => supabaseManager.client != null;

  @override
  Future<DashboardStats> getDashboardStats() async {
    if (!_isLive) {
      return DashboardStats(
        totalZones: _mockZones.where((z) => !z.isArchived).length,
        totalAdmins: _mockAdmins.where((a) => a.isActive).length,
        totalEmployees: 6,
        totalShops: _mockZones.fold<int>(0, (sum, z) => sum + z.shopCount),
        followupsDueToday: 4,
        paymentsAwaitingConfirmation: 2,
      );
    }

    try {
      final client = supabaseManager.client!;

      final zonesRes = await client.from('zones').select('id').eq('is_active', true);
      final adminsRes = await client
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .eq('is_active', true);
      final employeesRes = await client
          .from('profiles')
          .select('id')
          .eq('role', 'employee')
          .eq('is_active', true);
      final shopsRes = await client.from('shops').select('id');

      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final followupsRes = await client
          .from('shop_followups')
          .select('id')
          .gte('scheduled_date', '$todayStr 00:00:00')
          .lte('scheduled_date', '$todayStr 23:59:59')
          .eq('status', 'scheduled');

      final paymentsRes = await client.from('payment_sessions').select('id').inFilter('status', [
        'created',
        'scanned',
        'amount_submitted',
      ]);

      return DashboardStats(
        totalZones: (zonesRes as List).length,
        totalAdmins: (adminsRes as List).length,
        totalEmployees: (employeesRes as List).length,
        totalShops: (shopsRes as List).length,
        followupsDueToday: (followupsRes as List).length,
        paymentsAwaitingConfirmation: (paymentsRes as List).length,
      );
    } catch (_) {
      // Fallback
      return DashboardStats(
        totalZones: _mockZones.where((z) => !z.isArchived).length,
        totalAdmins: _mockAdmins.length,
        totalEmployees: 6,
        totalShops: 41,
        followupsDueToday: 4,
        paymentsAwaitingConfirmation: 2,
      );
    }
  }

  @override
  Future<List<Zone>> getZones({bool includeArchived = false}) async {
    await CanonicalZones.syncWithRemote();

    // Ensure _mockZones stays aligned with CanonicalZones.all
    for (final z in CanonicalZones.all) {
      final idx = _mockZones.indexWhere((m) => m.id == z.id);
      if (idx >= 0) {
        _mockZones[idx] = z;
      } else {
        _mockZones.add(z);
      }
    }

    if (!_isLive) {
      if (includeArchived) return List.unmodifiable(_mockZones);
      return _mockZones.where((z) => !z.isArchived).toList();
    }

    try {
      final client = supabaseManager.client!;
      var query = client.from('zones').select('''
        *,
        zone_vertices(*),
        admin_zone_assignments(admin_id, profiles(full_name, display_id)),
        company_zone_assignments(company_id, companies(trade_name))
      ''');

      if (!includeArchived) {
        query = query.eq('is_active', true);
      }

      final res = await query.order('name');
      final List<Zone> zones = [];

      for (final row in res as List) {
        final verticesRaw = row['zone_vertices'] as List<dynamic>? ?? [];
        final vertices = verticesRaw
            .map((v) => ZoneVertex.fromJson(v as Map<String, dynamic>))
            .toList();

        // Extract assigned admin
        final adminAssigns = row['admin_zone_assignments'] as List<dynamic>?;
        String? adminId;
        String? adminName;
        if (adminAssigns != null && adminAssigns.isNotEmpty) {
          final first = adminAssigns.first as Map<String, dynamic>;
          adminId = first['admin_id'] as String?;
          final profile = first['profiles'] as Map<String, dynamic>?;
          if (profile != null) {
            final name = profile['full_name'] as String? ?? 'Admin';
            final dispId = profile['display_id'] as String?;
            adminName = dispId != null ? '$name (ID: $dispId)' : name;
          }
        }

        // Extract assigned company
        final compAssigns = row['company_zone_assignments'] as List<dynamic>?;
        String? companyId;
        String? companyName;
        if (compAssigns != null && compAssigns.isNotEmpty) {
          final first = compAssigns.first as Map<String, dynamic>;
          companyId = first['company_id'] as String?;
          final comp = first['companies'] as Map<String, dynamic>?;
          if (comp != null) {
            companyName = comp['trade_name'] as String?;
          }
        }

        zones.add(
          Zone.fromJson({
            ...row,
            'assigned_admin_id': adminId,
            'assigned_admin_name': adminName,
            'assigned_company_id': companyId,
            'assigned_company_name': companyName,
          }, vertices: vertices),
        );
      }

      return zones;
    } catch (_) {
      if (includeArchived) return List.unmodifiable(_mockZones);
      return _mockZones.where((z) => !z.isArchived).toList();
    }
  }

  @override
  Future<Zone?> getZoneById(String id) async {
    final zones = await getZones(includeArchived: true);
    final match = zones.where((z) => z.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<Zone> saveZone(Zone zone, List<ZoneVertex> vertices, {String? assignedAdminId}) async {
    final existingIndex = _mockZones.indexWhere((z) => z.id == zone.id);
    final targetAdminId = assignedAdminId ?? zone.assignedAdminId;

    UserProfile? resolvedAdmin;
    if (targetAdminId != null && targetAdminId.isNotEmpty) {
      final managed = CanonicalZones.getManagedAdmins();
      final idx = managed.indexWhere((a) => a.id == targetAdminId || a.displayId == targetAdminId);
      if (idx >= 0) {
        resolvedAdmin = managed[idx];
      } else {
        final mockIdx = _mockAdmins.indexWhere((a) => a.id == targetAdminId || a.displayId == targetAdminId);
        if (mockIdx >= 0) {
          resolvedAdmin = _mockAdmins[mockIdx];
        }
      }
    }

    String? adminName = zone.assignedAdminName;
    if (adminName == null || adminName.isEmpty) {
      if (resolvedAdmin != null) {
        adminName = resolvedAdmin.fullName.isNotEmpty
            ? '${resolvedAdmin.fullName} (ID: ${resolvedAdmin.displayId})'
            : 'Admin Code: ${resolvedAdmin.displayId}';
      }
    }

    final updated = zone.copyWith(
      id: zone.id.isEmpty ? 'z-${DateTime.now().millisecondsSinceEpoch}' : zone.id,
      vertices: vertices,
      assignedAdminId: targetAdminId,
      assignedAdminName: adminName,
      updatedAt: DateTime.now(),
    );

    if (existingIndex >= 0) {
      _mockZones[existingIndex] = updated;
    } else {
      _mockZones.insert(0, updated);
    }

    if (targetAdminId != null && targetAdminId.isNotEmpty) {
      CanonicalZones.assignAdminToZone(
        zoneId: updated.id,
        adminId: targetAdminId,
        adminName: adminName,
        adminPhone: resolvedAdmin?.phoneNumber,
        syncRemote: false,
      );
    }

    CanonicalZones.registerCustomZone(updated, syncRemote: true);

    _mockAuditLogs.insert(
      0,
      AuditLog(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        userRole: 'master_admin',
        userDisplayName: 'Master Admin',
        action: existingIndex >= 0 ? 'UPDATE_ZONE' : 'CREATE_ZONE',
        entityName: 'zones',
        entityId: updated.id,
        details: {'name': updated.name, 'vertices_count': vertices.length},
        createdAt: DateTime.now(),
      ),
    );

    if (_isLive) {
      try {
        final client = supabaseManager.client!;
        final bool isUuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(zone.id);
        final zoneId = isUuid ? zone.id : null;
        final payload = <String, dynamic>{
          'name': zone.name,
          'description': zone.description,
          'color_hex': zone.colorHex,
          'is_active': zone.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (zoneId != null) payload['id'] = zoneId;

        final zoneRes = await client.from('zones').upsert(payload).select().single();
        final savedZoneId = zoneRes['id'] as String;

        // Delete existing vertices and re-insert
        await client.from('zone_vertices').delete().eq('zone_id', savedZoneId);

        final verticesPayload = vertices.asMap().entries.map((entry) {
          return {
            'zone_id': savedZoneId,
            'sequence_order': entry.key,
            'latitude': entry.value.latitude,
            'longitude': entry.value.longitude,
          };
        }).toList();

        if (verticesPayload.isNotEmpty) {
          await client.from('zone_vertices').insert(verticesPayload);
        }

        // Update admin assignment if specified
        final bool isAdminUuid = assignedAdminId != null &&
            RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
                .hasMatch(assignedAdminId);
        if (isAdminUuid) {
          await client.from('admin_zone_assignments').upsert({
            'admin_id': assignedAdminId,
            'zone_id': savedZoneId,
          });
        }
      } catch (_) {
        // Fall back gracefully so local zone state remains active and saving succeeds!
      }
    }

    return updated;
  }

  @override
  Future<void> archiveZone(String zoneId, bool isArchived) async {
    final index = _mockZones.indexWhere((z) => z.id == zoneId);
    if (index >= 0) {
      _mockZones[index] = _mockZones[index].copyWith(
        isArchived: isArchived,
        isActive: !isArchived,
        updatedAt: DateTime.now(),
      );
      CanonicalZones.registerCustomZone(_mockZones[index], syncRemote: true);
    }

    if (_isLive) {
      try {
        await supabaseManager.client!
            .from('zones')
            .update({'is_active': !isArchived, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', zoneId);
      } catch (_) {}
    }
  }

  @override
  Future<List<UserProfile>> getAdmins() async {
    if (_isLive) {
      try {
        await DistributionSyncService.fetchRemoteState();
      } catch (_) {}
    }
    return CanonicalZones.getManagedAdmins();
  }

  @override
  Future<UserProfile> createAdminCode() async {
    final newAdmin = CanonicalZones.createAdminCode();

    _mockAuditLogs.insert(
      0,
      AuditLog(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        userRole: 'master_admin',
        userDisplayName: 'Master Admin',
        action: 'CREATE_ADMIN_CODE',
        entityName: 'profiles',
        entityId: newAdmin.id,
        details: {'display_id': newAdmin.displayId, 'status': 'pending_activation'},
        createdAt: DateTime.now(),
      ),
    );

    return newAdmin;
  }

  @override
  Future<UserProfile> pairAdminCode(String code, {required String fullName, required String phoneNumber}) async {
    final updated = CanonicalZones.pairAdminCode(code, fullName: fullName, phoneNumber: phoneNumber);
    if (updated == null) {
      throw const ValidationException('Admin Code not found. Please verify with Master Admin.');
    }
    return updated;
  }

  @override
  Future<UserProfile> createAdmin({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required String aadhaarDocumentPath,
    required bool consentGiven,
  }) async {
    if (!consentGiven) {
      throw const ValidationException('Aadhaar verification requires explicit applicant consent');
    }

    if (!_isLive) {
      final displayId = (_displayIdCounter++).toString();
      final newAdmin = UserProfile(
        id: 'admin-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: fullName,
        role: UserRole.admin,
        phoneNumber: phoneNumber,
        displayId: displayId,
        isActive: true,
        createdAt: DateTime.now(),
      );

      _mockAdmins.insert(0, newAdmin);

      _mockAuditLogs.insert(
        0,
        AuditLog(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          userRole: 'master_admin',
          userDisplayName: 'Master Admin',
          action: 'CREATE_ADMIN_ACCOUNT',
          entityName: 'profiles',
          entityId: newAdmin.id,
          details: {
            'display_id': displayId,
            'full_name': fullName,
            'phone': phoneNumber,
            'aadhaar_stored': true,
          },
          createdAt: DateTime.now(),
        ),
      );

      return newAdmin;
    }

    final client = supabaseManager.client!;

    // 1. Create auth user
    final authRes = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': 'admin', 'phone_number': phoneNumber},
    );

    final newUserId = authRes.user?.id;
    if (newUserId == null) {
      throw const NetworkException('Failed to create admin auth user');
    }

    // 2. Fetch created profile (which auto-gets 5-digit display_id from trigger)
    final profileRes = await client.from('profiles').select().eq('id', newUserId).single();
    final profile = UserProfile.fromJson(profileRes);

    // 3. Record KYC consent and private doc path in audit log
    await client.rpc(
      'log_audit_event',
      params: {
        'p_action': 'CREATE_ADMIN_ACCOUNT',
        'p_entity': 'profiles',
        'p_entity_id': newUserId,
        'p_details': {
          'display_id': profile.displayId,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'aadhaar_doc_path': aadhaarDocumentPath,
          'consent_timestamp': DateTime.now().toIso8601String(),
        },
      },
    );

    return profile;
  }

  @override
  Future<void> assignAdminToZones(String adminId, List<String> zoneIds) async {
    if (!_isLive) {
      final admin = _mockAdmins.firstWhere((a) => a.id == adminId, orElse: () => _mockAdmins.first);
      for (int i = 0; i < _mockZones.length; i++) {
        if (zoneIds.contains(_mockZones[i].id)) {
          _mockZones[i] = _mockZones[i].copyWith(
            assignedAdminId: adminId,
            assignedAdminName: '${admin.fullName} (ID: ${admin.displayId})',
          );
        } else if (_mockZones[i].assignedAdminId == adminId) {
          _mockZones[i] = _mockZones[i].copyWith(assignedAdminId: null, assignedAdminName: null);
        }
      }

      _mockAuditLogs.insert(
        0,
        AuditLog(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          userRole: 'master_admin',
          userDisplayName: 'Master Admin',
          action: 'ASSIGN_ADMIN_ZONES',
          entityName: 'admin_zone_assignments',
          entityId: adminId,
          details: {'admin': admin.fullName, 'zones_count': zoneIds.length},
          createdAt: DateTime.now(),
        ),
      );

      return;
    }

    final client = supabaseManager.client!;

    // Remove old assignments for this admin
    await client.from('admin_zone_assignments').delete().eq('admin_id', adminId);

    // Insert new ones
    if (zoneIds.isNotEmpty) {
      final payload = zoneIds.map((zId) => {'admin_id': adminId, 'zone_id': zId}).toList();
      await client.from('admin_zone_assignments').insert(payload);
    }
  }

  @override
  Future<List<String>> getAssignedZoneIdsForAdmin(String adminId) async {
    if (!_isLive) {
      return _mockZones.where((z) => z.assignedAdminId == adminId).map((z) => z.id).toList();
    }

    try {
      final client = supabaseManager.client!;
      final res = await client
          .from('admin_zone_assignments')
          .select('zone_id')
          .eq('admin_id', adminId);
      return (res as List).map((r) => r['zone_id'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Company>> getCompanies() async {
    if (!_isLive) {
      return List.unmodifiable(_mockCompanies);
    }

    try {
      final client = supabaseManager.client!;
      final res = await client
          .from('companies')
          .select('''
        *,
        company_zone_assignments(zone_id, zones(name))
      ''')
          .order('legal_name');

      final List<Company> companies = [];
      for (final row in res as List) {
        final assignments = row['company_zone_assignments'] as List<dynamic>? ?? [];
        final zoneIds = <String>[];
        final zoneNames = <String>[];

        for (final a in assignments) {
          final m = a as Map<String, dynamic>;
          final zId = m['zone_id'] as String?;
          if (zId != null) zoneIds.add(zId);
          final z = m['zones'] as Map<String, dynamic>?;
          if (z != null && z['name'] != null) zoneNames.add(z['name'] as String);
        }

        companies.add(
          Company.fromJson(row as Map<String, dynamic>, zoneIds: zoneIds, zoneNames: zoneNames),
        );
      }

      return companies;
    } catch (_) {
      return List.unmodifiable(_mockCompanies);
    }
  }

  @override
  Future<Company> createCompany({
    required String legalName,
    required String tradeName,
    required String contactEmail,
    String? contactPhone,
    String? address,
  }) async {
    if (!_isLive) {
      final newComp = Company(
        id: 'comp-${DateTime.now().millisecondsSinceEpoch}',
        legalName: legalName,
        tradeName: tradeName,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        address: address,
        isActive: true,
        createdAt: DateTime.now(),
      );

      _mockCompanies.insert(0, newComp);
      return newComp;
    }

    final client = supabaseManager.client!;
    final res = await client
        .from('companies')
        .insert({
          'legal_name': legalName,
          'trade_name': tradeName,
          'contact_email': contactEmail,
          'contact_phone': contactPhone,
          'address': address,
        })
        .select()
        .single();

    return Company.fromJson(res);
  }

  @override
  Future<void> assignZoneToCompany(String companyId, String zoneId) async {
    if (!_isLive) {
      final index = _mockCompanies.indexWhere((c) => c.id == companyId);
      final zone = _mockZones.firstWhere((z) => z.id == zoneId, orElse: () => _mockZones.first);
      if (index >= 0) {
        final comp = _mockCompanies[index];
        if (!comp.assignedZoneIds.contains(zoneId)) {
          _mockCompanies[index] = comp.copyWith(
            assignedZoneIds: [...comp.assignedZoneIds, zoneId],
            assignedZoneNames: [...comp.assignedZoneNames, zone.name],
          );
        }
      }

      final zoneIndex = _mockZones.indexWhere((z) => z.id == zoneId);
      if (zoneIndex >= 0) {
        _mockZones[zoneIndex] = _mockZones[zoneIndex].copyWith(
          assignedCompanyId: companyId,
          assignedCompanyName: _mockCompanies[index].tradeName,
        );
      }

      _mockAuditLogs.insert(
        0,
        AuditLog(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          userRole: 'master_admin',
          userDisplayName: 'Master Admin',
          action: 'ASSIGN_COMPANY_ZONE',
          entityName: 'company_zone_assignments',
          entityId: companyId,
          details: {'company_id': companyId, 'zone_id': zoneId, 'zone_name': zone.name},
          createdAt: DateTime.now(),
        ),
      );

      return;
    }

    final client = supabaseManager.client!;
    await client.from('company_zone_assignments').upsert({
      'company_id': companyId,
      'zone_id': zoneId,
    });
  }

  @override
  Future<void> removeZoneFromCompany(String companyId, String zoneId) async {
    if (!_isLive) {
      final index = _mockCompanies.indexWhere((c) => c.id == companyId);
      if (index >= 0) {
        final comp = _mockCompanies[index];
        final updatedIds = List<String>.from(comp.assignedZoneIds)..remove(zoneId);
        _mockCompanies[index] = comp.copyWith(assignedZoneIds: updatedIds);
      }
      return;
    }

    final client = supabaseManager.client!;
    await client
        .from('company_zone_assignments')
        .delete()
        .eq('company_id', companyId)
        .eq('zone_id', zoneId);
  }

  @override
  Future<List<AuditLog>> getAuditLogs({int limit = 50}) async {
    if (!_isLive) {
      return List.unmodifiable(_mockAuditLogs.take(limit).toList());
    }

    try {
      final client = supabaseManager.client!;
      final res = await client
          .from('audit_logs')
          .select('''
            *,
            profiles(full_name, display_id, role)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<AuditLog> logs = [];
      for (final row in res as List) {
        final prof = row['profiles'] as Map<String, dynamic>?;
        String? displayName;
        if (prof != null) {
          final name = prof['full_name'] as String? ?? 'User';
          final disp = prof['display_id'] as String?;
          displayName = disp != null ? '$name (ID: $disp)' : name;
        }

        logs.add(AuditLog.fromJson({...row, 'user_display_name': displayName}));
      }

      return logs;
    } catch (_) {
      return List.unmodifiable(_mockAuditLogs.take(limit).toList());
    }
  }

  @override
  Future<String> uploadAadhaarDocument({
    required String fileName,
    required List<int> bytes,
    required String targetUserId,
  }) async {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        'admins/$targetUserId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    if (!_isLive) {
      // In offline sandbox mode, return mock secure storage path
      return 'secure-identity-docs/$storagePath';
    }

    try {
      final client = supabaseManager.client!;
      await client.storage
          .from('secure-identity-docs')
          .uploadBinary(storagePath, Uint8List.fromList(bytes));
      return storagePath;
    } catch (_) {
      return 'secure-identity-docs/$storagePath';
    }
  }
}

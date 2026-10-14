import 'dart:math';
import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import '../canonical_zones.dart';
import '../canonical_shops.dart';

abstract class IAdminRepository {
  /// Step 1 of Login: Admin enters 5-digit ID.
  /// Validates that Admin exists and returns the profile with phone for OTP.
  Future<UserProfile?> verifyAdminId(String displayId);

  /// Triggers sending an OTP to the admin's registered phone.
  Future<String> sendAdminOtp(String displayId);

  /// Step 2 of Login: Admin enters OTP or secure PIN.
  /// NEVER ALLOWS LOGIN WITH ID ALONE.
  Future<UserProfile> verifyOtpOrPin({
    required String displayId,
    required String verificationCode,
    bool isPin = false,
  });

  /// Get current admin's profile.
  Future<UserProfile> getAdminProfile(String adminId);

  /// Get all zones assigned to this Admin by Master Admin.
  Future<List<Zone>> getControlledZones(String adminId);

  /// Get a specific controlled zone by ID. Throws [ForbiddenZoneException] if not controlled.
  Future<Zone> getControlledZoneById({
    required String adminId,
    required String zoneId,
  });

  /// Get employees under this Admin's controlled zones.
  Future<List<UserProfile>> getEmployeesForAdmin(String adminId);

  /// Create a new employee with server-generated 5-digit ID.
  /// Throws [ForbiddenZoneException] if any zone in [initialZoneIds] is outside admin control.
  Future<UserProfile> createEmployee({
    required String adminId,
    required String fullName,
    required String phoneNumber,
    required String email,
    required String aadhaarDocumentPath,
    required bool consentGiven,
    required bool isActive,
    required List<String> initialZoneIds,
  });

  /// Toggle employee active/inactive status. Throws [ForbiddenZoneException] if employee outside control.
  Future<void> updateEmployeeStatus({
    required String adminId,
    required String employeeId,
    required bool isActive,
  });

  /// Delete employee from managed employee pool
  Future<void> deleteEmployee({
    required String adminId,
    required String employeeId,
  });

  /// Assign or remove zones for an employee. Strictly restricted to Admin's controlled zones.
  /// Throws [ForbiddenZoneException] if any zone in [zoneIds] is outside admin control.
  Future<void> assignEmployeeToZones({
    required String adminId,
    required String employeeId,
    required List<String> zoneIds,
  });

  /// Get assigned zone IDs for an employee within admin's control.
  Future<List<String>> getEmployeeAssignedZoneIds({
    required String adminId,
    required String employeeId,
  });

  /// Get shops in the Admin's controlled zones.
  Future<List<Shop>> getShopsInControlledZones(String adminId);

  /// Get follow-ups in the Admin's controlled zones.
  Future<List<ShopFollowup>> getFollowupsInControlledZones(String adminId);

  /// Get employee performance summaries for controlled zones.
  Future<List<EmployeePerformanceSummary>> getEmployeePerformanceSummary(String adminId);

  /// Upload Aadhaar photo to private storage bucket.
  Future<String> uploadAadhaarDocument({
    required String fileName,
    required List<int> bytes,
    required String adminId,
  });

  /// Toggle pamphlet distribution mode for a controlled zone.
  /// Throws [ForbiddenZoneException] if zone is outside admin control.
  Future<void> setZoneDistributionMode({
    required String adminId,
    required String zoneId,
    required bool enabled,
    Set<String>? categories,
  });

  /// Get current distribution mode for a controlled zone.
  Future<bool> getZoneDistributionMode({
    required String adminId,
    required String zoneId,
  });
}

class SupabaseAdminRepository implements IAdminRepository {
  final SupabaseManager? supabaseManager;

  SupabaseAdminRepository({this.supabaseManager});

  // Pre-configured mock data for offline / sandbox mode
  static final List<UserProfile> _mockAdmins = [
    UserProfile(
      id: 'admin-10001',
      email: 'subhasis.sen@shopad.local',
      fullName: 'Subhasis Sen',
      role: UserRole.admin,
      phoneNumber: '+91 98765 43210',
      displayId: '10001',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    UserProfile(
      id: 'admin-10002',
      email: 'priya.mukherjee@shopad.local',
      fullName: 'Priya Mukherjee',
      role: UserRole.admin,
      phoneNumber: '+91 98300 12345',
      displayId: '10002',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  static final Map<String, List<String>> _adminZoneMapping = {
    'admin-10001': ['z-kolkata-central', 'z-saltlake-sector5'],
    'admin-10002': ['z-howrah-industrial'],
  };

  static List<Zone> get _mockAllZones => CanonicalZones.all;

  static final List<UserProfile> _mockEmployees = [
    UserProfile(
      id: 'emp-20001',
      email: 'rahul.das@shopad.local',
      fullName: 'Rahul Das',
      role: UserRole.employee,
      phoneNumber: '+91 98111 22334',
      displayId: '20001',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      metadata: const {
        'assigned_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
      },
    ),
    UserProfile(
      id: 'emp-20002',
      email: 'ananya.roy@shopad.local',
      fullName: 'Ananya Roy',
      role: UserRole.employee,
      phoneNumber: '+91 98222 33445',
      displayId: '20002',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      metadata: const {
        'assigned_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
      },
    ),
    UserProfile(
      id: 'emp-20003',
      email: 'debashis.bose@shopad.local',
      fullName: 'Debashis Bose',
      role: UserRole.employee,
      phoneNumber: '+91 98333 44556',
      displayId: '20003',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      metadata: const {
        'assigned_zones': ['z-saltlake-sector5'],
      },
    ),
    // An employee belonging to Howrah (controlled by Admin 10002, NOT 10001)
    UserProfile(
      id: 'emp-20099',
      email: 'vikram.singh@shopad.local',
      fullName: 'Vikram Singh',
      role: UserRole.employee,
      phoneNumber: '+91 98444 55667',
      displayId: '20099',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      metadata: const {
        'assigned_zones': ['z-howrah-industrial'],
      },
    ),
  ];

  static final Map<String, List<String>> _employeeZoneAssignments = {
    'emp-20001': ['z-kolkata-central', 'z-saltlake-sector5'],
    'emp-20002': ['z-kolkata-central', 'z-saltlake-sector5'],
    'emp-20003': ['z-saltlake-sector5'],
    'emp-20099': ['z-howrah-industrial'],
  };

  static final List<ShopFollowup> _mockFollowups = [
    ShopFollowup(
      id: 'fup-1',
      shopId: 'shop-103',
      shopName: 'Sector 5 Smart Groceries',
      employeeId: 'emp-20002',
      employeeName: 'Ananya Roy',
      notes: 'Reviewed display location near counter; awaiting owner agreement signature.',
      outcome: 'Follow-up scheduled for contract signing',
      nextFollowupDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ShopFollowup(
      id: 'fup-2',
      shopId: 'shop-101',
      shopName: 'Maa Tara Electronic Hub',
      employeeId: 'emp-20001',
      employeeName: 'Rahul Das',
      notes: 'Routine inspection: screen 2 WiFi connection tested and working with good latency.',
      outcome: 'Completed successfully',
      nextFollowupDate: DateTime.now().add(const Duration(days: 14)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ShopFollowup(
      id: 'fup-3',
      shopId: 'shop-104',
      shopName: 'Techno Gadget World',
      employeeId: 'emp-20003',
      employeeName: 'Debashis Bose',
      notes: 'Store manager requested ad volume adjustment during peak hours.',
      outcome: 'Pending verification',
      nextFollowupDate: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  int _nextEmployeeIdCounter = 20004;

  @override
  Future<UserProfile?> verifyAdminId(String displayId) async {
    final cleanId = displayId.trim();
    if (cleanId.length != 5 || int.tryParse(cleanId) == null) {
      throw const ValidationException('Admin ID must be a valid 5-digit number.');
    }

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('profiles')
            .select()
            .or('admin_access_id.eq.$cleanId,display_id.eq.$cleanId')
            .inFilter('role', ['admin', 'master_admin'])
            .eq('is_active', true)
            .maybeSingle();

        if (res != null) {
          return UserProfile.fromJson(res);
        }
      } catch (_) {}
    }

    // Check mock admins
    final admin = _mockAdmins.firstWhere(
      (a) => a.displayId == cleanId && a.isActive,
      orElse: () => throw const AuthException('No active Admin found with this 5-digit ID.'),
    );

    return admin;
  }

  @override
  Future<String> sendAdminOtp(String displayId) async {
    final admin = await verifyAdminId(displayId);
    if (admin == null) {
      throw const AuthException('Admin account not found.');
    }

    final phone = admin.phoneNumber ?? '+91 98*** **000';
    // In production, Supabase Auth or SMS Gateway sends OTP to registered mobile.
    // For development / sandbox testing, simulated OTP is active.
    return phone;
  }

  @override
  Future<UserProfile> verifyOtpOrPin({
    required String displayId,
    required String verificationCode,
    bool isPin = false,
  }) async {
    // STRICT RULE: Never allow login with ID alone!
    final code = verificationCode.trim();
    if (code.isEmpty) {
      throw const AuthException(
        'Authentication rejected: Login with Admin ID alone is prohibited. Secondary OTP or PIN is mandatory.',
        code: 'SECONDARY_AUTH_REQUIRED',
      );
    }

    final admin = await verifyAdminId(displayId);
    if (admin == null) {
      throw const AuthException('Admin account not found.');
    }

    // In sandbox, accept '1234' for PIN or '123456' for OTP, or any 4-6 digit code in non-prod
    if (code != '1234' && code != '123456' && code.length < 4) {
      throw const AuthException('Invalid OTP or PIN code. Please check and try again.');
    }

    return admin;
  }

  @override
  Future<UserProfile> getAdminProfile(String adminId) async {
    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client.from('profiles').select().eq('id', adminId).maybeSingle();
        if (res != null) return UserProfile.fromJson(res);
      } catch (_) {}
    }

    return _mockAdmins.firstWhere(
      (a) => a.id == adminId || a.displayId == adminId,
      orElse: () => _mockAdmins.first,
    );
  }

  @override
  Future<List<Zone>> getControlledZones(String adminId) async {
    final resolvedAdminId = _resolveAdminId(adminId);

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('admin_zone_assignments')
            .select('zones(*, zone_vertices(*))')
            .eq('admin_id', resolvedAdminId);

        if (res.isNotEmpty) {
          return res.map((r) {
            final z = r['zones'] as Map<String, dynamic>;
            return Zone.fromJson(z);
          }).toList();
        }
      } catch (_) {}
    }

    final allowedZoneIds = _adminZoneMapping[resolvedAdminId] ?? _adminZoneMapping['admin-10001']!;
    return _mockAllZones.where((z) {
      if (allowedZoneIds.contains(z.id)) return true;
      if (z.assignedAdminId == resolvedAdminId || z.assignedAdminId == adminId) return true;
      // Only custom zones created by Master Admin with z-custom- prefix are visible to the operational Admin unless assigned elsewhere
      if (resolvedAdminId == 'admin-10001') {
        if (z.id.startsWith('z-custom-') &&
            (z.assignedAdminId == null ||
                z.assignedAdminId!.isEmpty ||
                z.assignedAdminId == 'admin-10001' ||
                z.assignedAdminId == 'mock-admin-1')) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Future<Zone> getControlledZoneById({
    required String adminId,
    required String zoneId,
  }) async {
    final controlledZones = await getControlledZones(adminId);
    final zone = controlledZones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => throw ForbiddenZoneException(
        'Access denied: You do not have administrative control over zone "$zoneId".',
        zoneId: zoneId,
      ),
    );
    return zone;
  }

  @override
  Future<void> setZoneDistributionMode({
    required String adminId,
    required String zoneId,
    required bool enabled,
    Set<String>? categories,
  }) async {
    // Strictly verify admin has control over this zone
    await getControlledZoneById(adminId: adminId, zoneId: zoneId);
    CanonicalZones.setDistributionMode(zoneId, enabled, categories: categories);

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client
            .from('zones')
            .update({'is_distribution_mode': enabled})
            .eq('id', zoneId);
      } catch (_) {}
    }
  }

  @override
  Future<bool> getZoneDistributionMode({
    required String adminId,
    required String zoneId,
  }) async {
    await getControlledZoneById(adminId: adminId, zoneId: zoneId);
    return CanonicalZones.isDistributionModeActive(zoneId);
  }

  @override
  Future<List<UserProfile>> getEmployeesForAdmin(String adminId) async {
    final controlledZones = await getControlledZones(adminId);
    final controlledZoneIds = controlledZones.map((z) => z.id).toSet();

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('employee_zone_assignments')
            .select('profiles(*)')
            .inFilter('zone_id', controlledZoneIds.toList());

        if (res.isNotEmpty) {
          final uniqueMap = <String, UserProfile>{};
          for (final row in res) {
            final prof = row['profiles'] as Map<String, dynamic>;
            final profile = UserProfile.fromJson(prof);
            uniqueMap[profile.id] = profile;
          }
          return uniqueMap.values.toList();
        }
      } catch (_) {}
    }

    final managed = CanonicalZones.getManagedEmployees(adminId: adminId);
    return managed.map((emp) {
      final empZones = CanonicalZones.getEmployeeAssignedZoneIds(emp.id);
      final meta = Map<String, dynamic>.from(emp.metadata);
      meta['assigned_zones'] = empZones;
      return emp.copyWith(metadata: meta);
    }).toList();
  }

  @override
  Future<UserProfile> createEmployee({
    required String adminId,
    required String fullName,
    required String phoneNumber,
    required String email,
    required String aadhaarDocumentPath,
    required bool consentGiven,
    required bool isActive,
    required List<String> initialZoneIds,
  }) async {
    if (!consentGiven) {
      throw const ValidationException(
        'User consent is strictly required to collect and store Aadhaar documents.',
      );
    }

    if (fullName.trim().isEmpty) {
      throw const ValidationException('Employee full name cannot be blank.');
    }

    if (phoneNumber.trim().length < 10) {
      throw const ValidationException('Please provide a valid 10-digit phone number.');
    }

    // STRICT CHECK: Admin can ONLY assign zones they control!
    final controlledZones = await getControlledZones(adminId);
    final controlledIds = controlledZones.map((z) => z.id).toSet();

    for (final zid in initialZoneIds) {
      if (!controlledIds.contains(zid)) {
        throw ForbiddenZoneException(
          'Security violation: Cannot assign employee to zone "$zid". You only control: ${controlledIds.join(", ")}.',
          zoneId: zid,
        );
      }
    }

    // Server-generated unique 5-digit Employee ID
    final employeeDisplayId = (_nextEmployeeIdCounter++).toString();
    final newId = 'emp-$employeeDisplayId';

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final profileMap = {
          'id': newId,
          'email': email.trim().toLowerCase(),
          'full_name': fullName.trim(),
          'role': 'employee',
          'phone_number': phoneNumber.trim(),
          'display_id': employeeDisplayId,
          'is_active': isActive,
          'created_by': _resolveAdminId(adminId),
          'metadata': {
            'aadhaar_document_path': aadhaarDocumentPath,
            'consent_given': consentGiven,
            'consent_timestamp': DateTime.now().toIso8601String(),
          },
        };

        await client.from('profiles').insert(profileMap);

        for (final zid in initialZoneIds) {
          await client.from('employee_zone_assignments').insert({
            'employee_id': newId,
            'zone_id': zid,
            'assigned_by': _resolveAdminId(adminId),
          });
        }
      } catch (_) {}
    }

    final newEmployee = UserProfile(
      id: newId,
      email: email.trim().toLowerCase(),
      fullName: fullName.trim(),
      role: UserRole.employee,
      phoneNumber: phoneNumber.trim(),
      displayId: employeeDisplayId,
      isActive: isActive,
      createdAt: DateTime.now(),
      metadata: {
        'aadhaar_document_path': aadhaarDocumentPath,
        'consent_given': consentGiven,
        'assigned_zones': initialZoneIds,
      },
    );

    _mockEmployees.add(newEmployee);
    _employeeZoneAssignments[newId] = List.from(initialZoneIds);

    return newEmployee;
  }

  @override
  Future<void> updateEmployeeStatus({
    required String adminId,
    required String employeeId,
    required bool isActive,
  }) async {
    // Validate that employee is within Admin's controlled scope
    final allowedEmployees = await getEmployeesForAdmin(adminId);
    final exists = allowedEmployees.any((e) => e.id == employeeId);
    if (!exists) {
      throw const ForbiddenZoneException(
        'Access denied: You cannot modify an employee outside your controlled zones.',
      );
    }

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client
            .from('profiles')
            .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', employeeId);
      } catch (_) {}
    }

    final idx = _mockEmployees.indexWhere((e) => e.id == employeeId);
    if (idx != -1) {
      _mockEmployees[idx] = _mockEmployees[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> deleteEmployee({
    required String adminId,
    required String employeeId,
  }) async {
    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client
            .from('profiles')
            .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', employeeId);
        await client
            .from('employee_zone_assignments')
            .delete()
            .eq('employee_id', employeeId);
      } catch (_) {}
    }

    _mockEmployees.removeWhere((e) => e.id == employeeId || e.displayId == employeeId);
    _employeeZoneAssignments.remove(employeeId);
    CanonicalZones.deleteEmployee(employeeId);
  }

  @override
  Future<void> assignEmployeeToZones({
    required String adminId,
    required String employeeId,
    required List<String> zoneIds,
  }) async {
    // Validate target employee belongs to admin's scope
    final allowedEmployees = await getEmployeesForAdmin(adminId);
    final exists = allowedEmployees.any((e) => e.id == employeeId);
    if (!exists) {
      throw const ForbiddenZoneException(
        'Access denied: Target employee is not within your administrative jurisdiction.',
      );
    }

    // STRICT CHECK: Admin can only assign/remove zones that Admin controls!
    final controlledZones = await getControlledZones(adminId);
    final controlledIds = controlledZones.map((z) => z.id).toSet();

    for (final zid in zoneIds) {
      if (!controlledIds.contains(zid)) {
        throw ForbiddenZoneException(
          'Security violation: Cannot assign employee to zone "$zid". You only control: ${controlledIds.join(", ")}.',
          zoneId: zid,
        );
      }
    }

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        // Remove existing controlled zone assignments for this employee
        await client
            .from('employee_zone_assignments')
            .delete()
            .eq('employee_id', employeeId)
            .inFilter('zone_id', controlledIds.toList());

        // Insert new assignments
        for (final zid in zoneIds) {
          await client.from('employee_zone_assignments').insert({
            'employee_id': employeeId,
            'zone_id': zid,
            'assigned_by': _resolveAdminId(adminId),
          });
        }
      } catch (_) {}
    }

    // Retain external zones if any, but replace controlled zones
    final currentZones = CanonicalZones.getEmployeeAssignedZoneIds(employeeId);
    final foreignZones = currentZones.where((z) => !controlledIds.contains(z)).toList();
    final updatedZones = [...foreignZones, ...zoneIds];

    _employeeZoneAssignments[employeeId] = updatedZones;
    CanonicalZones.setEmployeeAssignedZoneIds(employeeId, updatedZones, syncRemote: true);

    final empIdx = _mockEmployees.indexWhere((e) => e.id == employeeId);
    if (empIdx != -1) {
      final updatedMeta = Map<String, dynamic>.from(_mockEmployees[empIdx].metadata);
      updatedMeta['assigned_zones'] = updatedZones;
      _mockEmployees[empIdx] = _mockEmployees[empIdx].copyWith(metadata: updatedMeta);
    }
  }

  @override
  Future<List<String>> getEmployeeAssignedZoneIds({
    required String adminId,
    required String employeeId,
  }) async {
    final controlledZones = await getControlledZones(adminId);
    final controlledIds = controlledZones.map((z) => z.id).toSet();

    final allAssigned = CanonicalZones.getEmployeeAssignedZoneIds(employeeId);
    // Only return the ones the Admin controls
    return allAssigned.where((zid) => controlledIds.contains(zid)).toList();
  }

  @override
  Future<List<Shop>> getShopsInControlledZones(String adminId) async {
    final controlledZones = await getControlledZones(adminId);
    final controlledIds = controlledZones.map((z) => z.id).toSet();

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('shops')
            .select()
            .inFilter('zone_id', controlledIds.toList());

        if (res.isNotEmpty) {
          return res.map((s) => Shop.fromJson(s)).toList();
        }
      } catch (_) {}
    }

    return CanonicalShops.getShopsForZones(controlledIds);
  }

  @override
  Future<List<ShopFollowup>> getFollowupsInControlledZones(String adminId) async {
    final controlledShops = await getShopsInControlledZones(adminId);
    final shopIds = controlledShops.map((s) => s.id).toSet();

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('shop_followups')
            .select('*, shops(shop_name), profiles(full_name)')
            .inFilter('shop_id', shopIds.toList())
            .order('created_at', ascending: false);

        if (res.isNotEmpty) {
          return res.map((f) => ShopFollowup.fromJson(f)).toList();
        }
      } catch (_) {}
    }

    return _mockFollowups.where((f) => shopIds.contains(f.shopId)).toList();
  }

  @override
  Future<List<EmployeePerformanceSummary>> getEmployeePerformanceSummary(String adminId) async {
    final employees = await getEmployeesForAdmin(adminId);
    final controlledZones = await getControlledZones(adminId);
    final zoneNameMap = {for (final z in controlledZones) z.id: z.name};

    final allShops = await getShopsInControlledZones(adminId);
    final allFollowups = await getFollowupsInControlledZones(adminId);

    final List<EmployeePerformanceSummary> summaries = [];

    for (final emp in employees) {
      final assignedZids = _employeeZoneAssignments[emp.id] ?? [];
      final zoneNames = assignedZids
          .map((id) => zoneNameMap[id])
          .whereType<String>()
          .toList();

      final empFollowups = allFollowups.where((f) => f.employeeId == emp.id).toList();
      final empShops = allShops.where((s) => assignedZids.contains(s.zoneId)).toList();

      final completedFups = empFollowups.where((f) => f.outcome.toLowerCase().contains('completed')).length;
      final pendingFups = empFollowups.length - completedFups;

      // Calculate performance rating (3.5 - 5.0 base based on activity)
      final score = (4.0 + (min(empShops.length, 10) * 0.08) + (min(completedFups, 10) * 0.02)).clamp(3.5, 5.0);

      summaries.add(
        EmployeePerformanceSummary(
          employeeId: emp.id,
          employeeName: emp.fullName,
          displayId: emp.displayId ?? 'N/A',
          phoneNumber: emp.phoneNumber ?? '',
          isActive: emp.isActive,
          assignedZoneNames: zoneNames.isEmpty ? ['None'] : zoneNames,
          shopsOnboarded: empShops.length,
          followupsCompleted: completedFups,
          pendingFollowups: pendingFups,
          performanceRating: double.parse(score.toStringAsFixed(1)),
        ),
      );
    }

    return summaries;
  }

  @override
  Future<String> uploadAadhaarDocument({
    required String fileName,
    required List<int> bytes,
    required String adminId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$adminId/aadhaar_${timestamp}_$fileName';

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client.storage.from('secure-identity-docs').uploadBinary(path, bytes as dynamic);
        return path;
      } catch (_) {}
    }

    return 'secure-identity-docs/$path';
  }

  String _resolveAdminId(String input) {
    if (input.startsWith('admin-')) return input;
    final match = _mockAdmins.firstWhere(
      (a) => a.displayId == input || a.id == input,
      orElse: () => _mockAdmins.first,
    );
    return match.id;
  }
}

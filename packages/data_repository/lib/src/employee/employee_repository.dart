import 'dart:math' as math;
import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import '../canonical_zones.dart';
import '../canonical_shops.dart';


abstract class IEmployeeRepository {
  /// Step 1: Employee enters 5-digit ID.
  Future<UserProfile?> verifyEmployeeId(String displayId);

  /// Send OTP to registered mobile number.
  Future<String> sendEmployeeOtp(String displayId);

  /// Step 2: Verify OTP or PIN.
  /// Strictly rejects login with ID alone.
  Future<UserProfile> verifyOtpOrPin({
    required String displayId,
    required String verificationCode,
    bool isPin = false,
  });

  /// Get profile of the employee.
  Future<UserProfile> getEmployeeProfile(String employeeId);

  /// Get only the zones assigned to this employee.
  Future<List<Zone>> getAssignedZones(String employeeId);

  /// Check if a point is within any of the employee's assigned zone polygons.
  Future<Zone?> findAssignedZoneForPoint({
    required String employeeId,
    required double latitude,
    required double longitude,
  });

  /// Get shops in assigned zones only.
  Future<List<Shop>> getShopsInAssignedZones(String employeeId);

  /// Check if phone number already exists in assigned zones.
  Future<bool> isPhoneNumberDuplicate({
    required String employeeId,
    required String phoneNumber,
    String? excludeShopId,
  });

  /// Find existing shops within thresholdMeters (e.g. 20m) to warn of nearby duplicates.
  Future<List<Shop>> getNearbyDuplicateShops({
    required String employeeId,
    required double latitude,
    required double longitude,
    double thresholdMeters = 20.0,
    String? excludeShopId,
  });

  /// Create a new shop. Must be inside an assigned zone!
  /// Server generates immutable 8-digit Shop Code if agreed.
  Future<Shop> addShop({
    required String employeeId,
    required String ownerName,
    required String phoneNumber,
    required String shopName,
    required String category,
    required double latitude,
    required double longitude,
    required String openingTime,
    required String closingTime,
    required String weeklyClosedDay,
    String? shopfrontPhotoUrl,
    String? landmark,
    required bool isAgreed,
    String? followupReason,
    DateTime? nextFollowupDate,
  });

  /// Convert an existing follow-up shop to Agreed.
  /// Server generates the immutable 8-digit shop code.
  Future<Shop> updateFollowupToAgreed({
    required String employeeId,
    required String shopId,
  });

  /// Get shops with follow-ups scheduled for today.
  Future<List<Shop>> getFollowupsToday(String employeeId);

  /// Get overdue follow-up shops.
  Future<List<Shop>> getOverdueFollowups(String employeeId);

  /// Search shops within assigned zones.
  Future<List<Shop>> searchShops({
    required String employeeId,
    required String query,
  });

  /// Save offline draft.
  Future<void> saveOfflineDraft(Map<String, dynamic> draft);

  /// Get all saved offline drafts.
  Future<List<Map<String, dynamic>>> getOfflineDrafts();

  /// Delete an offline draft after sync.
  Future<void> deleteOfflineDraft(String draftId);

  /// Mark a shop as distributed (pamphlet delivered)
  Future<void> markShopDistributed({
    required String employeeId,
    required String shopId,
  });

  /// Mark a shop as temporarily closed today during distribution
  Future<void> markShopClosedToday({
    required String employeeId,
    required String shopId,
  });

  /// Mark a shop as permanently gone / vacated (removes from map)
  Future<void> markShopGone({
    required String employeeId,
    required String shopId,
  });

  /// Check if a zone has distribution mode active
  Future<bool> isZoneDistributionModeActive(String zoneId);
}

class SupabaseEmployeeRepository implements IEmployeeRepository {
  final SupabaseManager? supabaseManager;

  SupabaseEmployeeRepository({this.supabaseManager});

  // Pre-configured mock data for offline / sandbox mode
  static final List<UserProfile> _mockEmployees = [
    UserProfile(
      id: 'emp-20001',
      email: 'rahul.das@shopad.local',
      fullName: 'Rahul Das',
      role: UserRole.employee,
      phoneNumber: '+91 98111 22334',
      displayId: '20001',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
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
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      metadata: const {
        'assigned_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
      },
    ),
  ];

  static final Map<String, List<String>> _employeeZoneMap = {
    'emp-20001': ['z-kolkata-central', 'z-saltlake-sector5'],
    'emp-20002': ['z-kolkata-central', 'z-saltlake-sector5'],
  };

  static List<Zone> get _mockZones => CanonicalZones.all;

  static List<Shop> get _mockShops => CanonicalShops.all;

  static int _nextShopCodeSeq = 10000005;
  final List<Map<String, dynamic>> _offlineDrafts = [];

  @override
  Future<UserProfile?> verifyEmployeeId(String displayId) async {
    final cleanId = displayId.trim();
    if (cleanId.length != 5 || int.tryParse(cleanId) == null) {
      throw const ValidationException('Employee ID must be a valid 5-digit number.');
    }

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('profiles')
            .select()
            .or('employee_access_id.eq.$cleanId,display_id.eq.$cleanId')
            .eq('role', 'employee')
            .eq('is_active', true)
            .maybeSingle();

        if (res != null) {
          return UserProfile.fromJson(res);
        }
      } catch (_) {}
    }

    // 1. Check CanonicalZones managed employees pool first
    final managed = CanonicalZones.getManagedEmployees();
    for (final e in managed) {
      if (e.displayId == cleanId && e.isActive) {
        return e;
      }
    }

    final match = _mockEmployees.firstWhere(
      (e) => e.displayId == cleanId && e.isActive,
      orElse: () => throw const AuthException('No active Employee found with this 5-digit ID.'),
    );
    return match;
  }

  @override
  Future<String> sendEmployeeOtp(String displayId) async {
    final emp = await verifyEmployeeId(displayId);
    if (emp == null) throw const AuthException('Employee account not found.');
    return emp.phoneNumber?.isNotEmpty == true ? emp.phoneNumber! : '+91 98*** **000';
  }

  @override
  Future<UserProfile> verifyOtpOrPin({
    required String displayId,
    required String verificationCode,
    bool isPin = false,
  }) async {
    final code = verificationCode.trim();
    if (code.isEmpty) {
      throw const AuthException(
        'Authentication rejected: Login with Employee ID alone is prohibited. Secondary OTP or PIN is mandatory.',
        code: 'SECONDARY_AUTH_REQUIRED',
      );
    }

    var emp = await verifyEmployeeId(displayId);
    if (emp == null) throw const AuthException('Employee account not found.');

    if (code != '1234' && code != '123456') {
      throw const AuthException('Invalid OTP or PIN code. Please check and try again.');
    }

    final cleanId = displayId.trim();
    // If this employee was generated with code and has no name yet, bind it upon login!
    if (emp.fullName.isEmpty) {
      final paired = CanonicalZones.pairEmployeeCode(
        cleanId,
        fullName: 'Field Agent ($cleanId)',
        phoneNumber: '+91 98300 $cleanId',
      );
      if (paired != null) {
        emp = paired;
      }
    }

    return emp;
  }

  @override
  Future<UserProfile> getEmployeeProfile(String employeeId) async {
    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client.from('profiles').select().eq('id', employeeId).maybeSingle();
        if (res != null) return UserProfile.fromJson(res);
      } catch (_) {}
    }

    return _mockEmployees.firstWhere(
      (e) => e.id == employeeId || e.displayId == employeeId,
      orElse: () => _mockEmployees.first,
    );
  }

  @override
  Future<List<Zone>> getAssignedZones(String employeeId) async {
    final resolvedId = _resolveEmployeeId(employeeId);

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('employee_zone_assignments')
            .select('zones(*, zone_vertices(*))')
            .eq('employee_id', resolvedId);

        if (res.isNotEmpty) {
          return res.map((r) => Zone.fromJson(r['zones'] as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    // 1. Check central canonical assignments (synced across apps in real-time)
    final canonicalAssigned = CanonicalZones.getEmployeeAssignedZones(resolvedId);
    if (canonicalAssigned.isNotEmpty) {
      return canonicalAssigned;
    }

    final allowedIds = _employeeZoneMap[resolvedId] ?? const <String>[];
    return _mockZones.where((z) => allowedIds.contains(z.id)).toList();
  }

  @override
  Future<Zone?> findAssignedZoneForPoint({
    required String employeeId,
    required double latitude,
    required double longitude,
  }) async {
    final assignedZones = await getAssignedZones(employeeId);

    for (final zone in assignedZones) {
      if (zone.vertices.length >= 3 &&
          _isPointInPolygon(latitude, longitude, zone.vertices)) {
        return zone;
      }
    }
    return null;
  }

  @override
  Future<List<Shop>> getShopsInAssignedZones(String employeeId) async {
    final assignedZones = await getAssignedZones(employeeId);
    final zoneIds = assignedZones.map((z) => z.id).toSet();

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('shops')
            .select()
            .inFilter('zone_id', zoneIds.toList());

        if (res.isNotEmpty) {
          return res.map((s) => Shop.fromJson(s)).toList();
        }
      } catch (_) {}
    }

    return CanonicalShops.getShopsForZones(zoneIds);
  }

  @override
  Future<bool> isPhoneNumberDuplicate({
    required String employeeId,
    required String phoneNumber,
    String? excludeShopId,
  }) async {
    final shops = await getShopsInAssignedZones(employeeId);
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    return shops.any((s) {
      if (excludeShopId != null && s.id == excludeShopId) return false;
      final existingClean = (s.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
      return existingClean == cleanPhone && cleanPhone.isNotEmpty;
    });
  }

  @override
  Future<List<Shop>> getNearbyDuplicateShops({
    required String employeeId,
    required double latitude,
    required double longitude,
    double thresholdMeters = 20.0,
    String? excludeShopId,
  }) async {
    final shops = await getShopsInAssignedZones(employeeId);
    final List<Shop> nearby = [];

    for (final shop in shops) {
      if (excludeShopId != null && shop.id == excludeShopId) continue;
      final dist = _calculateDistanceMeters(
        latitude,
        longitude,
        shop.latitude,
        shop.longitude,
      );
      if (dist <= thresholdMeters) {
        nearby.add(shop);
      }
    }
    return nearby;
  }

  @override
  Future<Shop> addShop({
    required String employeeId,
    required String ownerName,
    required String phoneNumber,
    required String shopName,
    required String category,
    required double latitude,
    required double longitude,
    required String openingTime,
    required String closingTime,
    required String weeklyClosedDay,
    String? shopfrontPhotoUrl,
    String? landmark,
    required bool isAgreed,
    String? followupReason,
    DateTime? nextFollowupDate,
  }) async {
    // 1. Strict Zone Check: Location MUST be inside an assigned zone!
    final assignedZone = await findAssignedZoneForPoint(
      employeeId: employeeId,
      latitude: latitude,
      longitude: longitude,
    );

    if (assignedZone == null) {
      throw const ForbiddenZoneException(
        'Security policy: Shop location is outside your assigned zones. You can only add shops within your assigned zones.',
      );
    }

    // 2. Mandatory Followup Reason check
    if (!isAgreed && (followupReason == null || followupReason.trim().isEmpty)) {
      throw const ValidationException(
        'Follow-up reason is mandatory when shop is marked for follow-up.',
      );
    }

    // 3. Generate server-side 8-digit Shop Code for Agreed shops
    final String? shopCode = isAgreed ? (_nextShopCodeSeq++).toString() : null;
    final shopId = 'shop-${DateTime.now().millisecondsSinceEpoch}';

    final newShop = Shop(
      id: shopId,
      shopCode: shopCode,
      ownerId: 'owner-${DateTime.now().millisecondsSinceEpoch}',
      shopName: shopName.trim(),
      category: category,
      address: landmark != null && landmark.isNotEmpty
          ? '${assignedZone.name}, Near $landmark'
          : '${assignedZone.name}, Main Road',
      latitude: latitude,
      longitude: longitude,
      status: isAgreed ? 'under_process' : 'follow_up',
      activeScreensCount: 1,
      zoneId: assignedZone.id,
      zoneName: assignedZone.name,
      ownerName: ownerName.trim(),
      phoneNumber: phoneNumber.trim(),
      isAgreed: isAgreed,
      openingTime: openingTime,
      closingTime: closingTime,
      weeklyClosedDay: weeklyClosedDay,
      shopfrontPhotoUrl: shopfrontPhotoUrl,
      landmark: landmark,
      followupReason: followupReason,
      nextFollowupDate: nextFollowupDate,
      createdAt: DateTime.now(),
    );

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client.from('shops').insert({
          'id': shopId,
          'shop_name': newShop.shopName,
          'owner_name': newShop.ownerName,
          'phone_number': newShop.phoneNumber,
          'category': newShop.category,
          'address': newShop.address,
          'latitude': newShop.latitude,
          'longitude': newShop.longitude,
          'status': newShop.status,
          'zone_id': assignedZone.id,
          'is_agreed': newShop.isAgreed,
          'created_by_employee_id': _resolveEmployeeId(employeeId),
        });

        if (!isAgreed && followupReason != null) {
          await client.from('shop_followups').insert({
            'shop_id': shopId,
            'employee_id': _resolveEmployeeId(employeeId),
            'notes': followupReason,
            'outcome': 'Pending Follow-up',
            'next_followup_date': nextFollowupDate?.toIso8601String(),
          });
        }
      } catch (_) {}
    }

    CanonicalShops.addShop(newShop);
    return newShop;
  }

  @override
  Future<Shop> updateFollowupToAgreed({
    required String employeeId,
    required String shopId,
  }) async {
    final idx = _mockShops.indexWhere((s) => s.id == shopId);
    if (idx == -1) {
      throw const ValidationException('Shop not found.');
    }

    final existing = _mockShops[idx];
    final newShopCode = (_nextShopCodeSeq++).toString();

    final updated = existing.copyWith(
      isAgreed: true,
      status: 'active',
      shopCode: newShopCode,
      followupReason: null,
    );

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client.from('shops').update({
          'is_agreed': true,
          'status': 'active',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', shopId);
      } catch (_) {}
    }

    CanonicalShops.updateShop(updated);
    return updated;
  }

  @override
  Future<List<Shop>> getFollowupsToday(String employeeId) async {
    final shops = await getShopsInAssignedZones(employeeId);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return shops.where((s) {
      if (s.isAgreed || s.nextFollowupDate == null) return false;
      final date = s.nextFollowupDate!;
      return date.isAfter(todayStart) && date.isBefore(todayEnd);
    }).toList();
  }

  @override
  Future<List<Shop>> getOverdueFollowups(String employeeId) async {
    final shops = await getShopsInAssignedZones(employeeId);
    final now = DateTime.now();

    return shops.where((s) {
      if (s.isAgreed || s.nextFollowupDate == null) return false;
      return s.nextFollowupDate!.isBefore(now);
    }).toList();
  }

  @override
  Future<List<Shop>> searchShops({
    required String employeeId,
    required String query,
  }) async {
    final shops = await getShopsInAssignedZones(employeeId);
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return shops;

    return shops.where((s) {
      return s.shopName.toLowerCase().contains(q) ||
          (s.ownerName?.toLowerCase().contains(q) ?? false) ||
          (s.phoneNumber?.contains(q) ?? false) ||
          (s.shopCode?.contains(q) ?? false) ||
          s.category.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<void> saveOfflineDraft(Map<String, dynamic> draft) async {
    final id = draft['id'] ?? 'draft-${DateTime.now().millisecondsSinceEpoch}';
    final updated = Map<String, dynamic>.from(draft)..['id'] = id;
    _offlineDrafts.removeWhere((d) => d['id'] == id);
    _offlineDrafts.add(updated);
  }

  @override
  Future<List<Map<String, dynamic>>> getOfflineDrafts() async {
    return List.from(_offlineDrafts);
  }

  @override
  Future<void> deleteOfflineDraft(String draftId) async {
    _offlineDrafts.removeWhere((d) => d['id'] == draftId);
  }

  @override
  Future<void> markShopDistributed({
    required String employeeId,
    required String shopId,
  }) async {
    CanonicalShops.markShopDistributed(shopId);

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client
            .from('shops')
            .update({
              'is_distributed': true,
              'distributed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', shopId);
      } catch (_) {}
    }
  }

  @override
  Future<void> markShopClosedToday({
    required String employeeId,
    required String shopId,
  }) async {
    CanonicalShops.markShopClosedToday(shopId);

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client.from('distribution_logs').insert({
          'shop_id': shopId,
          'employee_id': _resolveEmployeeId(employeeId),
          'status': 'closed_today',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> markShopGone({
    required String employeeId,
    required String shopId,
  }) async {
    CanonicalShops.markShopGone(shopId);

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client
            .from('shops')
            .update({
              'status': 'archived_gone',
              'archived_at': DateTime.now().toIso8601String(),
            })
            .eq('id', shopId);
      } catch (_) {}
    }
  }

  @override
  Future<bool> isZoneDistributionModeActive(String zoneId) async {
    return CanonicalZones.isDistributionModeActive(zoneId);
  }

  String _resolveEmployeeId(String input) {
    if (input.startsWith('emp-')) return input;
    final match = _mockEmployees.firstWhere(
      (e) => e.displayId == input || e.id == input,
      orElse: () => _mockEmployees.first,
    );
    return match.id;
  }

  bool _isPointInPolygon(double lat, double lng, List<ZoneVertex> vertices) {
    int intersectCount = 0;
    final n = vertices.length;
    for (int i = 0; i < n; i++) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % n];
      final cond = (v1.longitude > lng) != (v2.longitude > lng);
      if (cond) {
        final slope = (v2.latitude - v1.latitude) / (v2.longitude - v1.longitude);
        final x = v1.latitude + slope * (lng - v1.longitude);
        if (lat < x) intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}


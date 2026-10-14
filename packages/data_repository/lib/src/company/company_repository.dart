import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import '../canonical_zones.dart';
import '../canonical_shops.dart';

abstract class ICompanyRepository {
  /// Company onboarding: enters company name & phone number
  Future<Company> requestCompanyOtp({
    required String companyName,
    required String phoneNumber,
  });

  /// Verify OTP and return authenticated company
  Future<Company> verifyCompanyOtp({
    required String phoneNumber,
    required String otp,
  });

  /// Get currently authenticated company details
  Future<Company?> getCurrentCompany();

  /// Read-only map/list of assigned zones (Empty if pending Master Admin approval)
  Future<List<Zone>> getAssignedZones(String companyId);

  /// Read-only list/search of agreed and active shops inside assigned zones
  /// Strictly excludes leads, follow-ups, Aadhaar documents, and private URLs
  Future<List<CompanyVisibleShop>> getAssignedShops({
    required String companyId,
    String? zoneId,
    String? searchQuery,
    String? category,
  });

  /// Zone summary: active agreed shops, category counts, and optional proof status
  Future<CompanyZoneSummary> getZoneSummary({
    required String companyId,
    required String zoneId,
  });

  /// Summaries across all assigned zones
  Future<List<CompanyZoneSummary>> getAllZoneSummaries(String companyId);

  /// Read active advertisement pricing configuration (from Supabase or default admin matrix)
  Future<List<AdvertisementPricing>> getAdvertisementPricings();

  /// Register / create a new advertisement space booking
  Future<bool> createAdSpaceBooking(AdSpaceBooking booking);

  /// All active advertising zones across the platform (canonical + dynamically synced Master Admin zones)
  Future<List<Zone>> getAllActiveZones();
}

class SupabaseCompanyRepository implements ICompanyRepository {
  final SupabaseManager? _supabaseManager;

  // Pre-configured mock companies for sandbox/testing
  static final List<Company> _mockCompanies = [
    // Approved Company (Britannia) with booked/assigned zones (Kolkata Central & Salt Lake)
    Company(
      id: 'comp-alpha-101',
      legalName: 'Britannia Industries Ltd',
      tradeName: 'Britannia',
      contactEmail: 'campaigns@britannia.co.in',
      contactPhone: '9876543210',
      isActive: true,
      canViewDailyProof: false,
      assignedZoneIds: const ['z-kolkata-central', 'z-salt-lake'],
      assignedZoneNames: const ['Kolkata Central Zone', 'Salt Lake Sector V'],
      createdAt: DateTime(2026, 1, 15),
    ),
    // Pending Approval Company with 0 assigned zones (Awaiting Master Admin assignment)
    Company(
      id: 'comp-beta-pending',
      legalName: 'Beta Outdoor Promotions LLP',
      tradeName: 'Beta Outdoor',
      contactEmail: 'contact@betaoutdoor.com',
      contactPhone: '9876543211',
      isActive: true,
      canViewDailyProof: false,
      assignedZoneIds: const [], // Zero zones -> PENDING APPROVAL
      assignedZoneNames: const [],
      createdAt: DateTime(2026, 9, 20),
    ),
  ];

  static Company? _currentSessionCompany;

  SupabaseCompanyRepository({SupabaseManager? supabaseManager})
      : _supabaseManager = supabaseManager;

  bool get _isSupabaseActive => _supabaseManager?.client != null;

  @override
  Future<Company> requestCompanyOtp({
    required String companyName,
    required String phoneNumber,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final cleanName = companyName.trim();

    if (cleanName.isEmpty) {
      throw const ValidationException('Company name is required.');
    }
    if (cleanPhone.length < 10) {
      throw const ValidationException('Please enter a valid 10-digit phone number.');
    }

    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client
            .from('companies')
            .select('*, company_zone_assignments(zone_id, zones(name))')
            .eq('phone', cleanPhone)
            .maybeSingle();

        if (res != null) {
          final assignments = res['company_zone_assignments'] as List<dynamic>? ?? [];
          final zIds = assignments.map((a) => a['zone_id'].toString()).toList();
          final zNames = assignments
              .map((a) => a['zones']?['name']?.toString() ?? 'Zone')
              .toList();
          return Company.fromJson(res, zoneIds: zIds, zoneNames: zNames);
        }
      } catch (_) {}
    }

    // Mock search or create pending company
    final existing = _mockCompanies.firstWhere(
      (c) => c.contactPhone == cleanPhone,
      orElse: () {
        final newPending = Company(
          id: 'comp_${DateTime.now().millisecondsSinceEpoch}',
          legalName: cleanName,
          tradeName: cleanName,
          contactEmail: 'info@${cleanName.toLowerCase().replaceAll(' ', '')}.com',
          contactPhone: cleanPhone,
          isActive: true,
          canViewDailyProof: false,
          assignedZoneIds: const [],
          assignedZoneNames: const [],
          createdAt: DateTime.now(),
        );
        _mockCompanies.add(newPending);
        return newPending;
      },
    );

    return existing;
  }

  @override
  Future<Company> verifyCompanyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final cleanOtp = otp.trim();

    if (cleanOtp.length != 6) {
      throw const ValidationException('Please enter a valid 6-digit OTP.');
    }
    if (cleanOtp != '123456') {
      throw const AuthException('Invalid OTP. Please check and try again.');
    }

    final company = _mockCompanies.firstWhere(
      (c) => c.contactPhone == cleanPhone,
      orElse: () => throw const AuthException('No company record found for this phone number.'),
    );

    _currentSessionCompany = company;
    return company;
  }

  @override
  Future<Company?> getCurrentCompany() async {
    return _currentSessionCompany ?? _mockCompanies.first;
  }

  @override
  Future<List<Zone>> getAllActiveZones() async {
    await CanonicalZones.syncWithRemote();
    return CanonicalZones.all.where((z) => !z.isArchived).toList();
  }

  @override
  Future<List<Zone>> getAssignedZones(String companyId) async {
    await CanonicalZones.syncWithRemote();

    final company = _mockCompanies.firstWhere(
      (c) => c.id == companyId,
      orElse: () => throw const AuthException('Company not found'),
    );

    // If Master Admin has not assigned any zone, return empty list (Pending Approval)
    if (company.assignedZoneIds.isEmpty) {
      return [];
    }

    // Canonical active zones matching assigned IDs
    final allZones = [
      CanonicalZones.kolkataCentral,
      if (company.assignedZoneIds.contains(CanonicalZones.saltLakeAliasId))
        CanonicalZones.saltLakeSector5.copyWith(id: CanonicalZones.saltLakeAliasId)
      else
        CanonicalZones.saltLakeSector5,
      CanonicalZones.howrahIndustrial,
      ...CanonicalZones.all.where((z) =>
          !z.isArchived &&
          z.id != CanonicalZones.kolkataCentralId &&
          z.id != CanonicalZones.saltLakeSector5Id &&
          z.id != CanonicalZones.saltLakeAliasId &&
          z.id != CanonicalZones.howrahIndustrialId),
    ];

    // Return ONLY zones present in assignedZoneIds (allowing salt lake alias)
    return allZones.where((z) {
      if (company.assignedZoneIds.contains(z.id)) return true;
      if (z.id == CanonicalZones.saltLakeAliasId &&
          company.assignedZoneIds.contains(CanonicalZones.saltLakeSector5Id)) {
        return true;
      }
      if (z.id == CanonicalZones.saltLakeSector5Id &&
          company.assignedZoneIds.contains(CanonicalZones.saltLakeAliasId)) {
        return true;
      }
      return false;
    }).toList();
  }

  @override
  Future<List<CompanyVisibleShop>> getAssignedShops({
    required String companyId,
    String? zoneId,
    String? searchQuery,
    String? category,
  }) async {
    final company = _mockCompanies.firstWhere(
      (c) => c.id == companyId,
      orElse: () => throw const AuthException('Company not found'),
    );

    // If company has no assigned zones, strictly return 0 shops
    if (company.assignedZoneIds.isEmpty) {
      return [];
    }

    final allowedZoneIds = company.assignedZoneIds;

    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        var query = client
            .from('shops')
            .select()
            .eq('is_agreed', true)
            .eq('status', 'active')
            .inFilter('zone_id', allowedZoneIds);

        if (zoneId != null && zoneId.isNotEmpty) {
          query = query.eq('zone_id', zoneId);
        }
        if (category != null && category.isNotEmpty && category != 'All') {
          query = query.eq('category', category);
        }

        final res = await query;
        if (res.isNotEmpty) {
          var list = (res as List)
              .map((s) => CompanyVisibleShop.fromJson(
                    s as Map<String, dynamic>,
                    canViewDailyProof: company.canViewDailyProof,
                  ))
              .toList();

          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            list = list
                .where((s) =>
                    s.shopName.toLowerCase().contains(q) ||
                    s.shopCode.toLowerCase().contains(q) ||
                    s.address.toLowerCase().contains(q))
                .toList();
          }
          return list;
        }
      } catch (_) {}
    }

    // Canonical Fallback Dataset (strictly Agreed & Active shops in assigned zones)
    return CanonicalShops.getCompanyVisibleShops(
      assignedZoneIds: allowedZoneIds,
      zoneFilter: zoneId,
      categoryFilter: category,
      searchQuery: searchQuery,
      canViewDailyProof: company.canViewDailyProof,
    );
  }

  @override
  Future<CompanyZoneSummary> getZoneSummary({
    required String companyId,
    required String zoneId,
  }) async {
    final company = _mockCompanies.firstWhere(
      (c) => c.id == companyId,
      orElse: () => throw const AuthException('Company not found'),
    );

    final assignedZones = await getAssignedZones(companyId);
    final isAssigned = assignedZones.any((z) => z.id == zoneId) ||
        (zoneId == CanonicalZones.saltLakeAliasId &&
            assignedZones.any((z) => z.id == CanonicalZones.saltLakeSector5Id)) ||
        (zoneId == CanonicalZones.saltLakeSector5Id &&
            assignedZones.any((z) => z.id == CanonicalZones.saltLakeAliasId));

    if (!isAssigned) {
      throw const AuthException('Access denied: Zone is not assigned to this company.');
    }

    final shops = await getAssignedShops(companyId: companyId, zoneId: zoneId);
    final matchedZone = assignedZones.firstWhere((z) => z.id == zoneId, orElse: () => assignedZones.first);
    final zoneName = shops.isNotEmpty ? shops.first.zoneName : matchedZone.name;

    final categoryCounts = <String, int>{};
    int totalScreens = 0;
    int proofCount = 0;

    for (final s in shops) {
      categoryCounts[s.category] = (categoryCounts[s.category] ?? 0) + 1;
      totalScreens += s.screenCount;
      if (s.hasTodayProof == true) {
        proofCount++;
      }
    }

    return CompanyZoneSummary(
      zoneId: zoneId,
      zoneName: zoneName,
      totalAgreedShops: shops.length,
      totalScreens: totalScreens,
      categoryCounts: categoryCounts,
      proofVerifiedCount: company.canViewDailyProof ? proofCount : null,
    );
  }

  @override
  Future<List<CompanyZoneSummary>> getAllZoneSummaries(String companyId) async {
    final assignedZones = await getAssignedZones(companyId);
    final summaries = <CompanyZoneSummary>[];
    for (final zone in assignedZones) {
      final summary = await getZoneSummary(companyId: companyId, zoneId: zone.id);
      summaries.add(summary);
    }
    return summaries;
  }

  static final List<AdSpaceBooking> _mockBookings = [];

  @override
  Future<List<AdvertisementPricing>> getAdvertisementPricings() async {
    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        final res = await client
            .from('advertisement_pricing')
            .select()
            .eq('is_active', true);
        if (res.isNotEmpty) {
          return res
              .map((row) => AdvertisementPricing.fromJson(row))
              .toList();
        }
      } catch (_) {}
    }
    return AdvertisementPricing.defaultPricings;
  }

  @override
  Future<bool> createAdSpaceBooking(AdSpaceBooking booking) async {
    if (_isSupabaseActive) {
      try {
        final client = _supabaseManager!.client!;
        await client.from('ad_space_bookings').insert(booking.toJson());
        return true;
      } catch (_) {}
    }
    _mockBookings.add(booking);
    return true;
  }
}

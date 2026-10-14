import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:domain_models/domain_models.dart';
import 'canonical_zones.dart';
import 'sync/distribution_sync_service.dart';

/// Single Canonical Source of Truth for Shops across all applications
/// (Master Admin, Admin, Employee, Company, Shopkeeper).
/// Guarantees that whatever shop an employee signs up or updates in an assigned zone
/// is automatically tracked, shared, and visible to all authorized applications
/// while strictly enforcing role-based privacy boundaries.
class CanonicalShops {
  CanonicalShops._();

  static final List<Shop> _shops = [
    // --- Kolkata Central Zone (Agreed & Active) ---
    Shop(
      id: 'shop-101',
      shopCode: '10000001',
      ownerId: 'owner-1',
      shopName: 'Maa Tara Electronic Hub',
      category: 'Saloon',
      address: '42 Central Avenue, Kolkata',
      latitude: 22.5720,
      longitude: 88.3620,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Tarun Banerjee',
      phoneNumber: '9876500001',
      monthlyRent: 4500.0,
      isAgreed: true,
      openingTime: '09:00 AM',
      closingTime: '09:00 PM',
      weeklyClosedDay: 'Sunday',
      shopfrontPhotoUrl: 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=400',
      distributedAt: DateTime(2026, 10, 10),
      createdAt: DateTime(2026, 3, 15),
    ),
    Shop(
      id: 'shop-102',
      shopCode: '10000002',
      ownerId: 'owner-2',
      shopName: 'Bengal Sweets & Bakery',
      category: 'Bakery',
      address: '15 MG Road, Kolkata',
      latitude: 22.5740,
      longitude: 88.3680,
      status: 'active',
      activeScreensCount: 1,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Bikash Ghosh',
      phoneNumber: '9876500002',
      monthlyRent: 3200.0,
      isAgreed: true,
      openingTime: '07:30 AM',
      closingTime: '10:00 PM',
      weeklyClosedDay: 'None',
      shopfrontPhotoUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
      distributedAt: DateTime(2026, 10, 10),
      createdAt: DateTime(2026, 3, 20),
    ),
    Shop(
      id: 'shop-108',
      shopCode: '10000008',
      ownerId: 'owner-8',
      shopName: 'College Street Book Corner',
      category: 'Stationery',
      address: '77 College Street, Kolkata',
      latitude: 22.5745,
      longitude: 88.3635,
      status: 'active',
      activeScreensCount: 1,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Subir Chakraborty',
      phoneNumber: '9876500008',
      monthlyRent: 3800.0,
      isAgreed: true,
      openingTime: '10:00 AM',
      closingTime: '08:30 PM',
      weeklyClosedDay: 'Sunday',
      createdAt: DateTime(2026, 3, 25),
    ),
    Shop(
      id: 'shop-109',
      shopCode: '10000009',
      ownerId: 'owner-9',
      shopName: 'Central Men\'s Hair Lounge',
      category: 'Saloon',
      address: '19 Bowbazar Street, Kolkata',
      latitude: 22.5690,
      longitude: 88.3660,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Md. Shahid',
      phoneNumber: '9876500009',
      monthlyRent: 4200.0,
      isAgreed: true,
      openingTime: '08:30 AM',
      closingTime: '09:30 PM',
      weeklyClosedDay: 'Tuesday',
      createdAt: DateTime(2026, 3, 28),
    ),
    Shop(
      id: 'shop-110',
      shopCode: '10000010',
      ownerId: 'owner-10',
      shopName: 'New Bowbazar Jewellers',
      category: 'Jewellery',
      address: '52 Bowbazar, Kolkata',
      latitude: 22.5710,
      longitude: 88.3670,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Alok Roy',
      phoneNumber: '9876500010',
      monthlyRent: 7500.0,
      isAgreed: true,
      openingTime: '11:00 AM',
      closingTime: '08:00 PM',
      weeklyClosedDay: 'Sunday',
      createdAt: DateTime(2026, 4, 1),
    ),
    Shop(
      id: 'shop-111',
      shopCode: '10000011',
      ownerId: 'owner-11',
      shopName: 'Esplanade Mobile & Tech World',
      category: 'Electronics',
      address: '8 Esplanade East, Kolkata',
      latitude: 22.5670,
      longitude: 88.3630,
      status: 'active',
      activeScreensCount: 3,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Sunil Shaw',
      phoneNumber: '9876500011',
      monthlyRent: 6000.0,
      isAgreed: true,
      openingTime: '10:00 AM',
      closingTime: '09:00 PM',
      weeklyClosedDay: 'None',
      createdAt: DateTime(2026, 4, 5),
    ),
    Shop(
      id: 'shop-112',
      shopCode: '10000012',
      ownerId: 'owner-12',
      shopName: 'Kolkata Style Cuts & Spa',
      category: 'Saloon',
      address: '14 Ganesh Chandra Avenue, Kolkata',
      latitude: 22.5730,
      longitude: 88.3600,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Pritam Das',
      phoneNumber: '9876500012',
      monthlyRent: 4800.0,
      isAgreed: true,
      openingTime: '09:00 AM',
      closingTime: '09:00 PM',
      weeklyClosedDay: 'Monday',
      createdAt: DateTime(2026, 4, 10),
    ),
    Shop(
      id: 'shop-113',
      shopCode: '10000013',
      ownerId: 'owner-13',
      shopName: 'Chandni Hardware & Electric',
      category: 'Hardware',
      address: '3 Chandni Chowk Street, Kolkata',
      latitude: 22.5685,
      longitude: 88.3580,
      status: 'active',
      activeScreensCount: 1,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Ramesh Sen',
      phoneNumber: '9876500013',
      monthlyRent: 3500.0,
      isAgreed: true,
      openingTime: '09:30 AM',
      closingTime: '08:30 PM',
      weeklyClosedDay: 'Sunday',
      createdAt: DateTime(2026, 4, 12),
    ),

    // --- Kolkata Central Zone (Follow-ups: Internal to Employee & Admin ONLY) ---
    Shop(
      id: 'shop-103',
      ownerId: 'owner-3',
      shopName: 'Central Fresh Chicken Corner',
      category: 'Chicken',
      address: '28 New Market, Kolkata',
      latitude: 22.5680,
      longitude: 88.3650,
      status: 'follow_up',
      activeScreensCount: 1,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Imtiaz Ali',
      phoneNumber: '9876500003',
      monthlyRent: 3500.0,
      isAgreed: false,
      openingTime: '08:00 AM',
      closingTime: '08:00 PM',
      weeklyClosedDay: 'Thursday',
      followupReason: 'Owner requested contract revision for 6 months discount',
      nextFollowupDate: DateTime.now().add(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Shop(
      id: 'shop-104',
      ownerId: 'owner-4',
      shopName: 'Deshbandhu Chai & Fast Food',
      category: 'Tea Stall',
      address: '10 Esplanade East, Kolkata',
      latitude: 22.5695,
      longitude: 88.3610,
      status: 'follow_up',
      activeScreensCount: 1,
      zoneId: CanonicalZones.kolkataCentralId,
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Subhasish Roy',
      phoneNumber: '9876500004',
      monthlyRent: 2000.0,
      isAgreed: false,
      openingTime: '06:00 AM',
      closingTime: '11:00 PM',
      weeklyClosedDay: 'None',
      followupReason: 'Store manager was busy during peak morning tea hours',
      nextFollowupDate: DateTime.now().subtract(const Duration(hours: 26)),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),

    // --- Salt Lake Sector V (Agreed & Active) ---
    Shop(
      id: 'shop-105',
      shopCode: '10000004',
      ownerId: 'owner-5',
      shopName: 'Tech Bistro Cafe',
      category: 'Tea Stall',
      address: 'Webel More, Sector V, Salt Lake',
      latitude: 22.5780,
      longitude: 88.4320,
      status: 'active',
      activeScreensCount: 3,
      zoneId: CanonicalZones.saltLakeSector5Id,
      zoneName: 'Salt Lake Sector V',
      ownerName: 'Sneha Sen',
      phoneNumber: '9876500005',
      monthlyRent: 6500.0,
      isAgreed: true,
      openingTime: '08:30 AM',
      closingTime: '10:30 PM',
      weeklyClosedDay: 'Sunday',
      createdAt: DateTime(2026, 5, 5),
    ),
    Shop(
      id: 'shop-106',
      shopCode: '10000005',
      ownerId: 'owner-6',
      shopName: 'Modern Mart Groceries',
      category: 'Grocery',
      address: 'College More, Sector V, Salt Lake',
      latitude: 22.5810,
      longitude: 88.4350,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.saltLakeSector5Id,
      zoneName: 'Salt Lake Sector V',
      ownerName: 'Manish Agarwal',
      phoneNumber: '9876500006',
      monthlyRent: 5000.0,
      isAgreed: true,
      openingTime: '08:00 AM',
      closingTime: '09:30 PM',
      weeklyClosedDay: 'None',
      createdAt: DateTime(2026, 5, 18),
    ),
    Shop(
      id: 'shop-107',
      shopCode: '10000007',
      ownerId: 'owner-7',
      shopName: 'Envi Salon & Grooming Lounge',
      category: 'Saloon',
      address: 'Block EP, Sector V, Salt Lake',
      latitude: 22.5795,
      longitude: 88.4310,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.saltLakeSector5Id,
      zoneName: 'Salt Lake Sector V',
      ownerName: 'Ritika Sen',
      phoneNumber: '9876500007',
      monthlyRent: 5800.0,
      isAgreed: true,
      openingTime: '10:00 AM',
      closingTime: '08:30 PM',
      weeklyClosedDay: 'Tuesday',
      createdAt: DateTime(2026, 6, 1),
    ),

    // --- Howrah Industrial Area (Agreed & Active Territory) ---
    Shop(
      id: 'shop-howrah-chicken',
      shopCode: '10000091',
      ownerId: 'owner-howrah-1',
      shopName: 'Howrah Fresh Chicken & Meat Hub',
      category: 'Chicken',
      address: '12 GT Road South, Howrah Industrial Area',
      latitude: 22.5940,
      longitude: 88.2680,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.howrahIndustrialId,
      zoneName: 'Howrah Industrial Area',
      ownerName: 'Subir Mondal',
      phoneNumber: '9876500091',
      monthlyRent: 4200.0,
      isAgreed: true,
      openingTime: '08:00 AM',
      closingTime: '08:30 PM',
      weeklyClosedDay: 'Thursday',
      shopfrontPhotoUrl: 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?w=400',
      distributedAt: DateTime(2026, 10, 10),
      createdAt: DateTime(2026, 1, 5),
    ),
    Shop(
      id: 'shop-howrah-fastfood',
      shopCode: '10000092',
      ownerId: 'owner-howrah-2',
      shopName: 'Grand Howrah Fast Food Stall',
      category: 'Fast Food',
      address: '45 Foreshore Road, Howrah Industrial Area',
      latitude: 22.5980,
      longitude: 88.2720,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.howrahIndustrialId,
      zoneName: 'Howrah Industrial Area',
      ownerName: 'Debabrata Paul',
      phoneNumber: '9876500092',
      monthlyRent: 3800.0,
      isAgreed: true,
      openingTime: '11:00 AM',
      closingTime: '10:30 PM',
      weeklyClosedDay: 'Sunday',
      shopfrontPhotoUrl: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=400',
      distributedAt: DateTime(2026, 10, 10),
      createdAt: DateTime(2026, 1, 8),
    ),
    Shop(
      id: 'shop-howrah-grocery',
      shopCode: '10000093',
      ownerId: 'owner-howrah-3',
      shopName: 'Maa Durga Grocery & Provisions',
      category: 'Grocery',
      address: '8 Kadamtala Main Road, Howrah Industrial Area',
      latitude: 22.5910,
      longitude: 88.2660,
      status: 'active',
      activeScreensCount: 1,
      zoneId: CanonicalZones.howrahIndustrialId,
      zoneName: 'Howrah Industrial Area',
      ownerName: 'Ashok Kumar Shaw',
      phoneNumber: '9876500093',
      monthlyRent: 3500.0,
      isAgreed: true,
      openingTime: '07:30 AM',
      closingTime: '09:30 PM',
      weeklyClosedDay: 'Sunday',
      shopfrontPhotoUrl: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400',
      distributedAt: DateTime(2026, 10, 9),
      createdAt: DateTime(2026, 1, 10),
    ),
    Shop(
      id: 'shop-howrah-saloon',
      shopCode: '10000094',
      ownerId: 'owner-howrah-4',
      shopName: 'Howrah Royal Men\'s Saloon',
      category: 'Saloon',
      address: '33 Shibpur Road, Howrah Industrial Area',
      latitude: 22.5960,
      longitude: 88.2750,
      status: 'active',
      activeScreensCount: 2,
      zoneId: CanonicalZones.howrahIndustrialId,
      zoneName: 'Howrah Industrial Area',
      ownerName: 'Md. Firoz',
      phoneNumber: '9876500094',
      monthlyRent: 4000.0,
      isAgreed: true,
      openingTime: '09:00 AM',
      closingTime: '09:30 PM',
      weeklyClosedDay: 'Monday', // Closed on Monday - no photo yet!
      createdAt: DateTime(2026, 1, 12),
    ),
    Shop(
      id: 'shop-howrah-tea',
      shopCode: '10000095',
      ownerId: 'owner-howrah-5',
      shopName: 'Howrah Station Chai Stall',
      category: 'Tea Stall',
      address: 'Near Station Gate 3, Howrah Industrial Area',
      latitude: 22.5920,
      longitude: 88.2700,
      status: 'active',
      activeScreensCount: 1,
      zoneId: CanonicalZones.howrahIndustrialId,
      zoneName: 'Howrah Industrial Area',
      ownerName: 'Kailash Yadav',
      phoneNumber: '9876500095',
      monthlyRent: 2500.0,
      isAgreed: true,
      openingTime: '06:00 AM',
      closingTime: '10:00 PM',
      weeklyClosedDay: 'Monday', // Closed on Monday - no photo yet!
      createdAt: DateTime(2026, 1, 14),
    ),
    Shop(
      id: 'shop-999',
      shopCode: '10000099',
      ownerId: 'owner-99',
      shopName: 'Howrah Hardware Stores',
      category: 'Hardware',
      address: 'GT Road, Howrah Industrial Area',
      latitude: 22.5950,
      longitude: 88.2650,
      status: 'active',
      activeScreensCount: 1,
      zoneId: CanonicalZones.howrahIndustrialId,
      zoneName: 'Howrah Industrial Area',
      ownerName: 'Gopal Shaw',
      phoneNumber: '9876500099',
      monthlyRent: 2800.0,
      isAgreed: true,
      openingTime: '09:00 AM',
      closingTime: '07:30 PM',
      weeklyClosedDay: 'Sunday',
      createdAt: DateTime(2026, 1, 10),
    ),
  ];

  static final Set<String> _goneShopIds = <String>{};
  static final Set<String> _closedTodayShopIds = <String>{};
  static final Set<String> _crossedShopIds = <String>{};

  static bool isShopGone(String shopId) => _goneShopIds.contains(shopId);
  static bool isShopClosedToday(String shopId) => _closedTodayShopIds.contains(shopId);
  static bool isShopCrossed(String shopId) => _crossedShopIds.contains(shopId);

  static Set<String> get goneShopIds => Set.unmodifiable(_goneShopIds);
  static Set<String> get closedTodayShopIds => Set.unmodifiable(_closedTodayShopIds);
  static Set<String> get crossedShopIds => Set.unmodifiable(_crossedShopIds);

  /// Mark a shop as permanently gone / closed by owner
  static void markShopGone(String shopId, {bool syncRemote = true}) {
    _goneShopIds.add(shopId);
    _closedTodayShopIds.remove(shopId);
    _crossedShopIds.remove(shopId);
    if (syncRemote) {
      unawaited(DistributionSyncService.pushShopGone(shopId));
    }
  }

  /// Mark a shop as temporarily closed today
  static void markShopClosedToday(String shopId, {bool syncRemote = true}) {
    _closedTodayShopIds.add(shopId);
    _crossedShopIds.add(shopId);
    if (syncRemote) {
      unawaited(DistributionSyncService.pushShopClosedToday(shopId));
    }
  }

  /// Mark a shop as crossed (past midnight without delivery)
  static void markShopCrossed(String shopId) {
    if (!_goneShopIds.contains(shopId)) {
      _crossedShopIds.add(shopId);
    }
  }

  /// Find shop by ID
  static Shop? getShopById(String shopId) {
    try {
      return _shops.firstWhere((s) => s.id == shopId);
    } catch (_) {
      return null;
    }
  }

  /// Find shop by Shop Code (e.g. 10000001)
  static Shop? getShopByCode(String code) {
    try {
      return _shops.firstWhere(
        (s) => (s.shopCode ?? '').toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all registered shops (excluding permanently gone shops)
  static List<Shop> get all =>
      _shops.where((s) => !_goneShopIds.contains(s.id)).toList();

  /// Get all registered shops including gone (for historical logs)
  static List<Shop> get allIncludingGone => List.unmodifiable(_shops);

  /// Dynamically add a newly registered shop by employee
  static void addShop(Shop shop) {
    _shops.removeWhere((s) => s.id == shop.id);
    _shops.insert(0, shop);
    shopsRevision.value++;
  }

  static int _nextShopCodeSeq = 10000100;

  /// Approve an "under_process" shop, turning it into live active shop
  static Shop? approveShop(String shopId, {bool syncRemote = true}) {
    final idx = _shops.indexWhere((s) => s.id == shopId);
    if (idx != -1) {
      final current = _shops[idx];
      final newCode = current.shopCode ?? (_nextShopCodeSeq++).toString();
      final approved = current.copyWith(
        status: 'active',
        isAgreed: true,
        shopCode: newCode,
      );
      _shops[idx] = approved;
      shopsRevision.value++;
      return approved;
    }
    return null;
  }

  /// Delete a shop permanently (e.g. unapproved or duplicate shop)
  static void deleteShop(String shopId, {bool syncRemote = true}) {
    _shops.removeWhere((s) => s.id == shopId);
    _closedTodayShopIds.remove(shopId);
    _crossedShopIds.remove(shopId);
    _goneShopIds.remove(shopId);
    shopsRevision.value++;
  }

  /// Update an existing shop (e.g. converting follow-up to agreed)
  static void updateShop(Shop shop) {
    final idx = _shops.indexWhere((s) => s.id == shop.id);
    if (idx != -1) {
      _shops[idx] = shop;
    } else {
      _shops.insert(0, shop);
    }
    shopsRevision.value++;
  }

  /// Mark a shop as distributed for pamphlet distribution campaign
  static void markShopDistributed(String shopId, {DateTime? distributedAt, bool syncRemote = true}) {
    final idx = _shops.indexWhere((s) => s.id == shopId);
    if (idx != -1) {
      _shops[idx] = _shops[idx].copyWith(
        isDistributed: true,
        distributedAt: distributedAt ?? DateTime.now(),
      );
    }
    _closedTodayShopIds.remove(shopId);
    _crossedShopIds.remove(shopId);
    if (syncRemote) {
      unawaited(DistributionSyncService.pushShopDistributed(shopId));
    }
  }

  /// Reset distribution status for a zone (keeps gone shops archived)
  static void resetDistributionForZone(String zoneId) {
    for (int i = 0; i < _shops.length; i++) {
      final s = _shops[i];
      if (s.zoneId == zoneId ||
          (s.zoneId == CanonicalZones.saltLakeSector5Id && zoneId == CanonicalZones.saltLakeAliasId) ||
          (s.zoneId == CanonicalZones.saltLakeAliasId && zoneId == CanonicalZones.saltLakeSector5Id)) {
        _shops[i] = s.copyWith(
          isDistributed: false,
        );
        _closedTodayShopIds.remove(s.id);
        _crossedShopIds.remove(s.id);
      }
    }
  }

  static final ValueNotifier<int> shopsRevision = ValueNotifier<int>(0);

  /// Reset all runtime in-memory distribution and archive states (used for testing and fresh boot)
  static void resetAll() {
    _goneShopIds.clear();
    _closedTodayShopIds.clear();
    _crossedShopIds.clear();
    for (int i = 0; i < _shops.length; i++) {
      _shops[i] = _shops[i].copyWith(isDistributed: false);
    }
    shopsRevision.value++;
  }

  /// Synchronize remote shop state from sync server
  static void syncRemoteShops({
    List<String>? distributedShops,
    List<String>? goneShops,
    List<String>? closedTodayShops,
    List<String>? crossedShops,
  }) {
    bool changed = false;
    if (goneShops != null) {
      for (final id in goneShops) {
        if (_goneShopIds.add(id)) changed = true;
      }
    }
    if (closedTodayShops != null) {
      for (final id in closedTodayShops) {
        if (_closedTodayShopIds.add(id)) changed = true;
      }
    }
    if (crossedShops != null) {
      for (final id in crossedShops) {
        if (_crossedShopIds.add(id)) changed = true;
      }
    }
    if (distributedShops != null) {
      for (final id in distributedShops) {
        final idx = _shops.indexWhere((s) => s.id == id);
        if (idx != -1 && !_shops[idx].isDistributed) {
          _shops[idx] = _shops[idx].copyWith(isDistributed: true);
          changed = true;
        }
        if (_closedTodayShopIds.remove(id)) changed = true;
        if (_crossedShopIds.remove(id)) changed = true;
      }
    }
    if (changed) {
      shopsRevision.value++;
    }
  }

  /// Query shops matching target zone IDs (for Admin / Employee jurisdiction)
  static List<Shop> getShopsForZones(Set<String> zoneIds) {
    return _shops.where((s) {
      if (_goneShopIds.contains(s.id)) return false;
      if (s.zoneId == null) return false;
      return zoneIds.contains(s.zoneId) ||
          (s.zoneId == CanonicalZones.saltLakeSector5Id && zoneIds.contains(CanonicalZones.saltLakeAliasId)) ||
          (s.zoneId == CanonicalZones.saltLakeAliasId && zoneIds.contains(CanonicalZones.saltLakeSector5Id));
    }).toList();
  }

  /// Query shops sanitized for Company view:
  /// STRICT PRIVACY ENFORCEMENT: ONLY Agreed & Active shops, strictly no follow-ups/leads!
  static List<CompanyVisibleShop> getCompanyVisibleShops({
    required List<String> assignedZoneIds,
    String? zoneFilter,
    String? categoryFilter,
    String? searchQuery,
    bool canViewDailyProof = false,
  }) {
    final assignedSet = assignedZoneIds.toSet();

    return _shops.where((s) {
      // 1. Strict Privacy: MUST be agreed and active
      if (!s.isAgreed || s.status.toLowerCase() != 'active') {
        return false;
      }

      // 2. Strict Jurisdiction: MUST belong to company's assigned zones
      final inAssignedZone = assignedSet.contains(s.zoneId) ||
          (s.zoneId == CanonicalZones.saltLakeSector5Id && assignedSet.contains(CanonicalZones.saltLakeAliasId)) ||
          (s.zoneId == CanonicalZones.saltLakeAliasId && assignedSet.contains(CanonicalZones.saltLakeSector5Id));
      if (!inAssignedZone) return false;

      // 3. Optional zone filter
      if (zoneFilter != null && zoneFilter.isNotEmpty) {
        final matchesZone = s.zoneId == zoneFilter ||
            (s.zoneId == CanonicalZones.saltLakeSector5Id && zoneFilter == CanonicalZones.saltLakeAliasId) ||
            (s.zoneId == CanonicalZones.saltLakeAliasId && zoneFilter == CanonicalZones.saltLakeSector5Id);
        if (!matchesZone) return false;
      }

      // 4. Optional category filter
      if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter.toLowerCase() != 'all') {
        if (s.category.toLowerCase() != categoryFilter.toLowerCase()) return false;
      }

      // 5. Optional search query
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matches = s.shopName.toLowerCase().contains(q) ||
            (s.shopCode ?? '').toLowerCase().contains(q) ||
            s.address.toLowerCase().contains(q);
        if (!matches) return false;
      }

      return true;
    }).map((s) {
      final resolvedZoneId = (s.zoneId == CanonicalZones.saltLakeSector5Id &&
              assignedSet.contains(CanonicalZones.saltLakeAliasId) &&
              !assignedSet.contains(CanonicalZones.saltLakeSector5Id))
          ? CanonicalZones.saltLakeAliasId
          : (s.zoneId ?? '');

      return CompanyVisibleShop(
        id: s.id,
        shopCode: s.shopCode ?? '',
        zoneId: resolvedZoneId,
        zoneName: s.zoneName ?? 'Assigned Zone',
        shopName: s.shopName,
        category: s.category,
        address: s.address,
        latitude: s.latitude,
        longitude: s.longitude,
        screenCount: s.activeScreensCount,
        status: s.status,
        agreedAt: s.createdAt,
        createdAt: s.createdAt,
        hasTodayProof: canViewDailyProof ? true : null,
        todayProofUrl: s.shopfrontPhotoUrl,
        photoUrl: s.shopfrontPhotoUrl,
        photoUpdatedAt: s.distributedAt ?? s.createdAt,
        weeklyClosedDay: s.weeklyClosedDay,
      );
    }).toList();
  }
}

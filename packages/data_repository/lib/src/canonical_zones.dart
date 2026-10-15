import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:domain_models/domain_models.dart';
import 'canonical_shops.dart';
import 'sync/distribution_sync_service.dart';

/// Single Canonical Source of Truth for Master Admin created Zones.
/// Guaranteed identical polygon vertices, shapes, centroids, boundaries, and colors
/// across all applications (Master Admin, Admin, Employee, Company, Shopkeeper).
class CanonicalZones {
  const CanonicalZones._();

  static const String kolkataCentralId = 'z-kolkata-central';
  static const String saltLakeSector5Id = 'z-saltlake-sector5';
  static const String saltLakeAliasId = 'z-salt-lake';
  static const String howrahIndustrialId = 'z-howrah-industrial';

  // Canonical Hex Colors
  static const String kolkataCentralColor = '#006699'; // Deep Blue
  static const String saltLakeSector5Color = '#2E7D32'; // Forest Green
  static const String howrahIndustrialColor = '#8E24AA'; // Royal Purple

  // Canonical Polygon Vertices
  static const List<ZoneVertex> kolkataCentralVertices = [
    ZoneVertex(sequenceOrder: 0, latitude: 22.5800, longitude: 88.3550),
    ZoneVertex(sequenceOrder: 1, latitude: 22.5850, longitude: 88.3700),
    ZoneVertex(sequenceOrder: 2, latitude: 22.5750, longitude: 88.3800),
    ZoneVertex(sequenceOrder: 3, latitude: 22.5650, longitude: 88.3750),
    ZoneVertex(sequenceOrder: 4, latitude: 22.5600, longitude: 88.3600),
    ZoneVertex(sequenceOrder: 5, latitude: 22.5700, longitude: 88.3500),
  ];

  static const List<ZoneVertex> saltLakeSector5Vertices = [
    ZoneVertex(sequenceOrder: 0, latitude: 22.5850, longitude: 88.4250),
    ZoneVertex(sequenceOrder: 1, latitude: 22.5900, longitude: 88.4400),
    ZoneVertex(sequenceOrder: 2, latitude: 22.5800, longitude: 88.4500),
    ZoneVertex(sequenceOrder: 3, latitude: 22.5700, longitude: 88.4450),
    ZoneVertex(sequenceOrder: 4, latitude: 22.5650, longitude: 88.4300),
    ZoneVertex(sequenceOrder: 5, latitude: 22.5750, longitude: 88.4200),
  ];

  static const List<ZoneVertex> howrahIndustrialVertices = [
    ZoneVertex(sequenceOrder: 0, latitude: 22.6000, longitude: 88.2600),
    ZoneVertex(sequenceOrder: 1, latitude: 22.6100, longitude: 88.2800),
    ZoneVertex(sequenceOrder: 2, latitude: 22.5950, longitude: 88.2900),
    ZoneVertex(sequenceOrder: 3, latitude: 22.5850, longitude: 88.2700),
    ZoneVertex(sequenceOrder: 4, latitude: 22.5900, longitude: 88.2580),
  ];

  static final Map<String, bool> _zoneDistributionMode = {
    kolkataCentralId: true,
    saltLakeSector5Id: true,
  };
  static final Map<String, Set<String>> _zoneDistributionCategories = {};
  static final Map<String, DateTime> _zoneDistributionStartTime = {};
  static final Map<String, bool> _zoneDriveCompleted = {};

  // Zone-specific Pricing Overrides (Scoped strictly to individual zones)
  static final Map<String, ZonePricingConfig> _zonePricingConfigs = {};

  // Zone Assigned Admin Access Codes (Can be rotated/regenerated to expel old admin)
  static final Map<String, String> _zoneAdminCodes = {
    kolkataCentralId: '10001',
    saltLakeSector5Id: '10002',
    howrahIndustrialId: '10003',
  };

  // Global Master Admin Distribution Material Catalog
  static final List<DistributionMaterial> _materials = [
    DistributionMaterial(
      id: 'mat-papers',
      name: 'Paper',
      targetBusinessType: 'all',
      defaultQuantity: 10,
      createdAt: DateTime(2026, 10, 1),
    ),
    DistributionMaterial(
      id: 'mat-pens',
      name: 'Pens',
      targetBusinessType: 'all',
      defaultQuantity: 5,
      createdAt: DateTime(2026, 10, 1),
    ),
    DistributionMaterial(
      id: 'mat-cello-tape',
      name: 'Cello Tape',
      targetBusinessType: 'all',
      defaultQuantity: 1,
      createdAt: DateTime(2026, 10, 1),
    ),
    DistributionMaterial(
      id: 'mat-marker-pen',
      name: 'Marker Pen',
      targetBusinessType: 'all',
      defaultQuantity: 1,
      createdAt: DateTime(2026, 10, 1),
    ),
    DistributionMaterial(
      id: 'mat-qr-stand',
      name: 'QR Stands',
      targetBusinessType: 'all',
      defaultQuantity: 1,
      createdAt: DateTime(2026, 10, 1),
    ),
  ];

  // Material Distribution Runs keyed by zoneId
  static final Map<String, List<MaterialDistributionRun>> _zoneMaterialRuns = {
    kolkataCentralId: [
      MaterialDistributionRun(
        id: 'mat-run-kolkata-papers',
        zoneId: kolkataCentralId,
        materialId: 'mat-papers',
        materialName: 'Paper',
        targetBusinessType: 'all',
        status: 'active',
        snapshotShopIds: ['shop-101', 'shop-102', 'shop-108'],
        distributedShopIds: const [],
        startedAt: DateTime.now(),
      ),
      MaterialDistributionRun(
        id: 'mat-run-kolkata-pens',
        zoneId: kolkataCentralId,
        materialId: 'mat-pens',
        materialName: 'Pens',
        targetBusinessType: 'all',
        status: 'active',
        snapshotShopIds: ['shop-101', 'shop-102', 'shop-108'],
        distributedShopIds: const [],
        startedAt: DateTime.now(),
      ),
      MaterialDistributionRun(
        id: 'mat-run-kolkata-cello-tape',
        zoneId: kolkataCentralId,
        materialId: 'mat-cello-tape',
        materialName: 'Cello Tape',
        targetBusinessType: 'all',
        status: 'active',
        snapshotShopIds: ['shop-101', 'shop-102', 'shop-108'],
        distributedShopIds: ['shop-108'],
        startedAt: DateTime.now(),
      ),
      MaterialDistributionRun(
        id: 'mat-run-kolkata-marker-pen',
        zoneId: kolkataCentralId,
        materialId: 'mat-marker-pen',
        materialName: 'Marker Pen',
        targetBusinessType: 'all',
        status: 'active',
        snapshotShopIds: ['shop-101', 'shop-102', 'shop-108'],
        distributedShopIds: const [],
        startedAt: DateTime.now(),
      ),
      MaterialDistributionRun(
        id: 'mat-run-kolkata-qr-stand',
        zoneId: kolkataCentralId,
        materialId: 'mat-qr-stand',
        materialName: 'QR Stands',
        targetBusinessType: 'all',
        status: 'active',
        snapshotShopIds: ['shop-101', 'shop-102', 'shop-108'],
        distributedShopIds: const [],
        startedAt: DateTime.now(),
      ),
    ],
  };

  // Company Ad Distribution Runs keyed by zoneId
  static final Map<String, List<CompanyAdDistributionRun>> _zoneCompanyAdRuns = {
    kolkataCentralId: [
      CompanyAdDistributionRun(
        id: 'ad-run-comp-a-shop-left',
        zoneId: kolkataCentralId,
        companyId: 'comp-pepsi',
        companyName: 'ABC (Pepsi India)',
        businessType: 'shop',
        placementSide: 'left',
        standSize: 'A5',
        slotStartDate: DateTime.now().add(const Duration(days: 1)),
        slotEndDate: DateTime.now().add(const Duration(days: 8)),
        adCreativeImageUrl:
            'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=400',
        adDesignUploadedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        printoutProofImageUrl:
            'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400',
        printoutProofUploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
        status: 'active',
        snapshotShopIds: ['shop-102', 'shop-108'],
        distributedShopIds: ['shop-102'],
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      CompanyAdDistributionRun(
        id: 'ad-run-comp-b-shop-right',
        zoneId: kolkataCentralId,
        companyId: 'comp-cadbury',
        companyName: 'CBD (Cadbury Gems)',
        businessType: 'shop',
        placementSide: 'right',
        standSize: 'A6',
        slotStartDate: DateTime.now().add(const Duration(days: 3)),
        slotEndDate: DateTime.now().add(const Duration(days: 10)),
        adCreativeImageUrl:
            'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400',
        adDesignUploadedAt: DateTime.now().subtract(const Duration(hours: 6)),
        printoutProofImageUrl: null,
        printoutProofUploadedAt: null,
        status: 'pending',
        snapshotShopIds: ['shop-102', 'shop-108'],
        startedAt: DateTime.now(),
      ),
      CompanyAdDistributionRun(
        id: 'ad-run-comp-c-saloon-right',
        zoneId: kolkataCentralId,
        companyId: 'comp-gfb',
        companyName: 'Image A (Saloon Exclusive Printout)',
        businessType: 'saloon',
        placementSide: 'right',
        standSize: 'A5',
        slotStartDate: DateTime.now().subtract(const Duration(days: 1)),
        slotEndDate: DateTime.now().add(const Duration(days: 14)),
        adCreativeImageUrl:
            'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400',
        adDesignUploadedAt: DateTime.now().subtract(const Duration(days: 2)),
        printoutProofImageUrl:
            'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400',
        printoutProofUploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        snapshotShopIds: ['shop-101', 'shop-109'],
        distributedShopIds: const [],
        startedAt: DateTime.now(),
      ),
      CompanyAdDistributionRun(
        id: 'ad-run-comp-phonepe',
        zoneId: kolkataCentralId,
        companyId: 'comp-phonepe',
        companyName: 'PhonePe UPI QR Stand',
        businessType: 'shop',
        placementSide: 'left',
        standSize: 'A5',
        slotStartDate: DateTime.now().subtract(const Duration(days: 20)),
        slotEndDate: DateTime.now().subtract(const Duration(days: 6)),
        adCreativeImageUrl:
            'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
        adDesignUploadedAt: DateTime.now().subtract(const Duration(days: 21)),
        printoutProofImageUrl:
            'https://images.unsplash.com/photo-1572945550745-37421bed2e66?w=400',
        printoutProofUploadedAt: DateTime.now().subtract(const Duration(days: 20)),
        status: 'completed',
        snapshotShopIds: ['shop-101', 'shop-102', 'shop-108'],
        distributedShopIds: ['shop-101', 'shop-102'],
        startedAt: DateTime.now().subtract(const Duration(days: 20)),
        completedAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
    ],
    saltLakeSector5Id: [
      CompanyAdDistributionRun(
        id: 'ad-run-sl-comp-1',
        zoneId: saltLakeSector5Id,
        companyId: 'comp-itc',
        companyName: 'ITC Sunfeast',
        businessType: 'shop',
        placementSide: 'left',
        standSize: 'A5',
        slotStartDate: DateTime.now(),
        slotEndDate: DateTime.now().add(const Duration(days: 7)),
        adCreativeImageUrl:
            'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
        adDesignUploadedAt: DateTime.now().subtract(const Duration(days: 2)),
        printoutProofImageUrl:
            'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400',
        printoutProofUploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        status: 'active',
        snapshotShopIds: ['shop-201', 'shop-202', 'shop-203'],
        distributedShopIds: ['shop-201', 'shop-202'],
        startedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CompanyAdDistributionRun(
        id: 'ad-run-sl-comp-2',
        zoneId: saltLakeSector5Id,
        companyId: 'comp-amul',
        companyName: 'Amul Kool',
        businessType: 'shop',
        placementSide: 'right',
        standSize: 'A6',
        slotStartDate: DateTime.now().add(const Duration(days: 2)),
        slotEndDate: DateTime.now().add(const Duration(days: 9)),
        adCreativeImageUrl:
            'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400',
        adDesignUploadedAt: DateTime.now().subtract(const Duration(hours: 5)),
        printoutProofImageUrl: null,
        status: 'pending',
        snapshotShopIds: ['shop-201', 'shop-202'],
        startedAt: DateTime.now(),
      ),
    ],
  };

  // --- Master Catalog Methods ---
  static List<DistributionMaterial> getAllMaterials() => List.unmodifiable(_materials);

  static void addMaterial(DistributionMaterial material, {bool syncRemote = true}) {
    _materials.removeWhere((m) => m.id == material.id);
    _materials.add(material);
    for (final zone in all) {
      getMaterialRuns(zone.id);
    }
    if (syncRemote) {
      unawaited(DistributionSyncService.pushMaterial(material));
    }
  }

  static void removeMaterial(String id, {bool syncRemote = true}) {
    _materials.removeWhere((m) => m.id == id);
    for (final list in _zoneMaterialRuns.values) {
      list.removeWhere((r) => r.materialId == id);
    }
    if (syncRemote) {
      unawaited(DistributionSyncService.pushRemoveMaterial(id));
    }
  }

  // --- Material Runs Methods ---
  static List<MaterialDistributionRun> getMaterialRuns(String zoneId) {
    final list = _zoneMaterialRuns.putIfAbsent(zoneId, () => []);
    final shopsInZone = CanonicalShops.getShopsForZones({zoneId});

    // Remove any runs for materials that Master Admin deleted from the master catalog
    list.removeWhere((r) => !_materials.any((m) => m.id == r.materialId));

    // Automatically provision runs for every material defined in Master Admin's Master Catalog
    for (final material in _materials) {
      final idx = list.indexWhere((r) => r.materialId == material.id);
      if (idx == -1) {
        final targetShops = shopsInZone.where((s) {
          if (CanonicalShops.isShopGone(s.id)) return false;
          if (material.targetBusinessType == 'shops' || material.targetBusinessType == 'shop') {
            return ShopCategory.fromString(s.category) != ShopCategory.saloon;
          } else if (material.targetBusinessType == 'saloon' || material.targetBusinessType == 'saloons') {
            return ShopCategory.fromString(s.category) == ShopCategory.saloon;
          }
          return true;
        }).map((s) => s.id).toList();

        list.add(
          MaterialDistributionRun(
            id: 'mat-run-$zoneId-${material.id}',
            zoneId: zoneId,
            materialId: material.id,
            materialName: material.name,
            targetBusinessType: material.targetBusinessType,
            status: 'active',
            snapshotShopIds: targetShops,
            distributedShopIds: const [],
            goneShopIds: const [],
            startedAt: DateTime.now(),
          ),
        );
      } else {
        if (list[idx].materialName != material.name ||
            list[idx].targetBusinessType != material.targetBusinessType) {
          list[idx] = list[idx].copyWith(
            materialName: material.name,
            targetBusinessType: material.targetBusinessType,
          );
        }
      }
    }
    return List.unmodifiable(list);
  }

  static void startMaterialRun(MaterialDistributionRun run) {
    final list = _zoneMaterialRuns.putIfAbsent(run.zoneId, () => []);
    list.removeWhere((r) => r.id == run.id);
    list.add(run);
    // Ensure distribution mode is ON for the zone
    setDistributionMode(run.zoneId, true);
  }

  static void stopMaterialRun(String zoneId, String runId) {
    final list = _zoneMaterialRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId || r.materialId == runId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          status: 'stopped',
          completedAt: DateTime.now(),
        );
      }
    }
  }

  // --- Company Ad Runs Methods ---
  static List<CompanyAdDistributionRun> getCompanyAdRuns(String zoneId) {
    var runs = _zoneCompanyAdRuns[zoneId];
    if (runs == null || runs.isEmpty) {
      final template = _zoneCompanyAdRuns[kolkataCentralId] ?? const [];
      runs = template.map((r) => r.copyWith(
        id: 'ad-run-$zoneId-${r.companyId}',
        zoneId: zoneId,
      )).toList();
      _zoneCompanyAdRuns[zoneId] = runs;
    }
    return List.unmodifiable(runs);
  }

  /// Get the target business category ('all', 'shop', 'saloon') for a given material or ad item
  static String getItemTargetBusinessType(String? zoneId, String itemId) {
    final targetZoneId = zoneId ?? kolkataCentralId;
    final mats = getMaterialRuns(targetZoneId);
    for (final m in mats) {
      if (m.materialId == itemId || m.id == itemId) {
        return m.targetBusinessType.toLowerCase();
      }
    }
    final ads = getCompanyAdRuns(targetZoneId);
    for (final a in ads) {
      if (a.id == itemId || a.companyId == itemId) {
        return a.businessType.toLowerCase();
      }
    }
    return 'all';
  }

  static void startCompanyAdRun(CompanyAdDistributionRun run) {
    final list = _zoneCompanyAdRuns.putIfAbsent(run.zoneId, () => []);
    final idx = list.indexWhere((r) => r.id == run.id);
    if (idx != -1) {
      list[idx] = run;
    } else {
      list.add(run);
    }
    setDistributionMode(run.zoneId, true);
  }

  static void updateCompanyAdDesign(String zoneId, String runId, String imageUrl, {DateTime? uploadedAt}) {
    final list = _zoneCompanyAdRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          adCreativeImageUrl: imageUrl,
          adDesignUploadedAt: uploadedAt ?? DateTime.now(),
        );
      }
    }
  }

  static void deleteCompanyAdDesign(String zoneId, String runId) {
    final list = _zoneCompanyAdRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          clearAdCreative: true,
          clearPrintoutProof: true,
          status: 'pending',
        );
      }
    }
  }

  static void updateCompanyPrintoutProof(String zoneId, String runId, String imageUrl, {DateTime? uploadedAt}) {
    final list = _zoneCompanyAdRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          printoutProofImageUrl: imageUrl,
          printoutProofUploadedAt: uploadedAt ?? DateTime.now(),
        );
      }
    }
  }

  static void deleteCompanyPrintoutProof(String zoneId, String runId) {
    final list = _zoneCompanyAdRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          clearPrintoutProof: true,
          status: 'pending',
        );
      }
    }
  }

  static void startCompanyDistribution(String zoneId, String runId) {
    final list = _zoneCompanyAdRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId);
      if (idx != -1) {
        final current = list[idx];
        list[idx] = current.copyWith(
          status: 'active',
          startedAt: DateTime.now(),
        );
      }
    }
    setDistributionMode(zoneId, true);
  }

  static void updateCompanyAdCreative(String zoneId, String runId, String imageUrl) {
    updateCompanyAdDesign(zoneId, runId, imageUrl);
  }

  static void toggleCompanyAdRun(String zoneId, String runId, bool active) {
    final list = _zoneCompanyAdRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId);
      if (idx != -1) {
        final current = list[idx];
        list[idx] = current.copyWith(
          status: active ? 'active' : 'stopped',
          startedAt: current.startedAt,
          completedAt: active ? null : DateTime.now(),
        );
      }
    }
    _syncZoneDistributionModeState(zoneId);
  }

  static void toggleMaterialRun(String zoneId, String runId, bool active, {bool syncRemote = true}) {
    final list = _zoneMaterialRuns[zoneId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == runId || r.materialId == runId);
      if (idx != -1) {
        final current = list[idx];
        list[idx] = current.copyWith(
          status: active ? 'active' : 'stopped',
          startedAt: current.startedAt,
          completedAt: active ? null : DateTime.now(),
        );
        if (syncRemote) {
          unawaited(DistributionSyncService.pushMaterialRunToggle(
            zoneId,
            current.materialId,
            active ? 'active' : 'stopped',
          ));
        }
      }
    }
    _syncZoneDistributionModeState(zoneId);
  }

  static void syncRemoteMaterials(List<DistributionMaterial> remoteMaterials) {
    for (final m in remoteMaterials) {
      final idx = _materials.indexWhere((existing) => existing.id == m.id);
      if (idx == -1) {
        _materials.add(m);
      } else {
        _materials[idx] = m;
      }
    }
    for (final zone in all) {
      getMaterialRuns(zone.id);
    }
  }

  static void syncRemoteMaterialRunStatuses(Map<String, dynamic> remoteStatuses) {
    for (final entry in remoteStatuses.entries) {
      final zoneId = entry.key;
      if (entry.value is Map<String, dynamic>) {
        final matMap = entry.value as Map<String, dynamic>;
        for (final mEntry in matMap.entries) {
          final matOrRunId = mEntry.key;
          final status = mEntry.value.toString();
          final list = _zoneMaterialRuns[zoneId];
          if (list != null) {
            final idx = list.indexWhere((r) => r.id == matOrRunId || r.materialId == matOrRunId);
            if (idx != -1) {
              list[idx] = list[idx].copyWith(
                status: status,
                completedAt: status == 'active' ? null : DateTime.now(),
              );
            }
          }
        }
      }
    }
  }

  static void createMaterialRunFromCatalog({
    required String zoneId,
    required DistributionMaterial material,
    required List<String> snapshotShopIds,
  }) {
    final runId = 'mat-run-${material.id}-${DateTime.now().millisecondsSinceEpoch}';
    final newRun = MaterialDistributionRun(
      id: runId,
      zoneId: zoneId,
      materialId: material.id,
      materialName: material.name,
      targetBusinessType: material.targetBusinessType,
      status: 'active',
      snapshotShopIds: snapshotShopIds,
      distributedShopIds: const [],
      goneShopIds: const [],
      startedAt: DateTime.now(),
    );
    startMaterialRun(newRun);
  }

  static void _syncZoneDistributionModeState(String zoneId) {
    final hasActiveMat = (_zoneMaterialRuns[zoneId] ?? const []).any((r) => r.status == 'active');
    final hasActiveAd = (_zoneCompanyAdRuns[zoneId] ?? const []).any((r) => r.status == 'active');
    setDistributionMode(zoneId, hasActiveMat || hasActiveAd);
  }

  // --- Combined QR Scanning & Handover Completion ---
  static String getShopDistributionQrPayload(Shop shop) =>
      'SHOP_DISTRIBUTION:${shop.id}:${shop.shopCode ?? shop.id}';

  static String? parseShopIdFromDistributionQr(String rawData) {
    final trimmed = rawData.trim();
    if (trimmed.startsWith('SHOP_DISTRIBUTION:')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) return parts[1];
    }
    // Also support direct ID lookup or shop code
    final directShop = CanonicalShops.getShopById(trimmed);
    if (directShop != null) return directShop.id;
    final codeShop = CanonicalShops.getShopByCode(trimmed);
    if (codeShop != null) return codeShop.id;
    return trimmed;
  }

  /// Record delivery or gone status for a shop across all active runs in a zone
  static void recordShopDistributionComplete({
    required String zoneId,
    required String shopId,
    bool isGone = false,
  }) {
    // 1. Update Material runs
    final matRuns = _zoneMaterialRuns[zoneId];
    if (matRuns != null) {
      for (int i = 0; i < matRuns.length; i++) {
        final r = matRuns[i];
        if (r.status != 'active') continue;
        final dist = List<String>.from(r.distributedShopIds);
        final gone = List<String>.from(r.goneShopIds);
        if (isGone) {
          if (!gone.contains(shopId)) gone.add(shopId);
        } else {
          if (!dist.contains(shopId)) dist.add(shopId);
        }
        final isAllDone = r.snapshotShopIds.isNotEmpty &&
            r.snapshotShopIds.every((id) => dist.contains(id) || gone.contains(id));
        matRuns[i] = r.copyWith(
          distributedShopIds: dist,
          goneShopIds: gone,
          status: isAllDone ? 'completed' : r.status,
          completedAt: isAllDone ? DateTime.now() : null,
        );
      }
    }

    // 2. Update Company Ad runs
    final adRuns = _zoneCompanyAdRuns[zoneId];
    if (adRuns != null) {
      for (int i = 0; i < adRuns.length; i++) {
        final r = adRuns[i];
        if (r.status != 'active') continue;
        final dist = List<String>.from(r.distributedShopIds);
        final gone = List<String>.from(r.goneShopIds);
        if (isGone) {
          if (!gone.contains(shopId)) gone.add(shopId);
        } else {
          if (!dist.contains(shopId)) dist.add(shopId);
        }
        final isAllDone = r.snapshotShopIds.isNotEmpty &&
            r.snapshotShopIds.every((id) => dist.contains(id) || gone.contains(id));
        adRuns[i] = r.copyWith(
          distributedShopIds: dist,
          goneShopIds: gone,
          status: isAllDone ? 'completed' : r.status,
          completedAt: isAllDone ? DateTime.now() : null,
        );
      }
    }

    // 3. Mark in CanonicalShops
    if (isGone) {
      CanonicalShops.markShopGone(shopId);
    } else {
      CanonicalShops.markShopDistributed(shopId);
    }
  }

  // --- Item-Level Shop Distribution Tracking (Date & Undo Support) ---
  // Key: "$shopId:$itemId" -> DateTime when distributed
  static final Map<String, DateTime> _shopItemDistributedTimestamps = {
    // Initial demo historical items (Yesterday: rolls & pins)
    'shop-101:mat-rolls': DateTime.now().subtract(const Duration(days: 1)),
    'shop-101:mat-pins': DateTime.now().subtract(const Duration(days: 1)),
    'shop-102:mat-rolls': DateTime.now().subtract(const Duration(days: 1)),
    'shop-102:mat-pins': DateTime.now().subtract(const Duration(days: 1)),
    // Initial demo historical items (> 2 days ago: PhonePe poster)
    'shop-101:ad-comp-phonepe': DateTime.now().subtract(const Duration(days: 12)),
    'shop-102:ad-comp-phonepe': DateTime.now().subtract(const Duration(days: 12)),
  };

  static void recordShopItemDistributed({
    required String zoneId,
    required String shopId,
    required String itemId,
    DateTime? timestamp,
  }) {
    final distTime = timestamp ?? DateTime.now();
    _shopItemDistributedTimestamps['$shopId:$itemId'] = distTime;

    // Also sync with run's distributedShopIds list
    final matRuns = _zoneMaterialRuns[zoneId];
    if (matRuns != null) {
      for (int i = 0; i < matRuns.length; i++) {
        if (matRuns[i].materialId == itemId || matRuns[i].id == itemId) {
          final dist = List<String>.from(matRuns[i].distributedShopIds);
          if (!dist.contains(shopId)) dist.add(shopId);
          matRuns[i] = matRuns[i].copyWith(distributedShopIds: dist);
        }
      }
    }

    final adRuns = _zoneCompanyAdRuns[zoneId];
    if (adRuns != null) {
      for (int i = 0; i < adRuns.length; i++) {
        if (adRuns[i].id == itemId || adRuns[i].companyId == itemId) {
          final dist = List<String>.from(adRuns[i].distributedShopIds);
          if (!dist.contains(shopId)) dist.add(shopId);
          adRuns[i] = adRuns[i].copyWith(distributedShopIds: dist);
        }
      }
    }

    CanonicalShops.markShopDistributed(shopId);
    zonesRevision.value++;
  }

  static void unmarkShopItemDistributed({
    required String zoneId,
    required String shopId,
    required String itemId,
  }) {
    _shopItemDistributedTimestamps.remove('$shopId:$itemId');

    // Also remove from run's distributedShopIds
    final matRuns = _zoneMaterialRuns[zoneId];
    if (matRuns != null) {
      for (int i = 0; i < matRuns.length; i++) {
        if (matRuns[i].materialId == itemId || matRuns[i].id == itemId) {
          final dist = List<String>.from(matRuns[i].distributedShopIds);
          dist.remove(shopId);
          matRuns[i] = matRuns[i].copyWith(distributedShopIds: dist);
        }
      }
    }

    final adRuns = _zoneCompanyAdRuns[zoneId];
    if (adRuns != null) {
      for (int i = 0; i < adRuns.length; i++) {
        if (adRuns[i].id == itemId || adRuns[i].companyId == itemId) {
          final dist = List<String>.from(adRuns[i].distributedShopIds);
          dist.remove(shopId);
          adRuns[i] = adRuns[i].copyWith(distributedShopIds: dist);
        }
      }
    }

    zonesRevision.value++;
  }

  static bool isShopItemDistributed(String shopId, String itemId) {
    if (_shopItemDistributedTimestamps.containsKey('$shopId:$itemId')) return true;
    for (final runs in _zoneMaterialRuns.values) {
      for (final r in runs) {
        if ((r.id == itemId || r.materialId == itemId) && r.distributedShopIds.contains(shopId)) {
          return true;
        }
      }
    }
    for (final runs in _zoneCompanyAdRuns.values) {
      for (final r in runs) {
        if ((r.id == itemId || r.companyId == itemId) && r.distributedShopIds.contains(shopId)) {
          return true;
        }
      }
    }
    return false;
  }

  static DateTime? getShopItemDistributedTimestamp(String shopId, String itemId) {
    return _shopItemDistributedTimestamps['$shopId:$itemId'];
  }

  static bool isDistributionModeActive(String? zoneId) =>
      zoneId != null ? (_zoneDistributionMode[zoneId] ?? false) : false;

  static bool get isAnyDistributionActive =>
      _zoneDistributionMode.values.any((mode) => mode == true);

  /// Reset all runtime in-memory distribution modes (used for testing and fresh boot)
  static void resetAll() {
    _zoneDistributionMode.clear();
    _zoneDistributionCategories.clear();
    _zoneDistributionStartTime.clear();
    _zoneDriveCompleted.clear();
    _customZones.clear();
    _employeeZoneAssignments
      ..clear()
      ..addAll(_defaultEmployeeZoneAssignments);
    zonesRevision.value++;
  }

  static Set<String> getDistributionCategories(String? zoneId) =>
      zoneId != null ? (_zoneDistributionCategories[zoneId] ?? <String>{}) : <String>{};

  static DateTime? getDistributionStartTime(String? zoneId) =>
      zoneId != null ? _zoneDistributionStartTime[zoneId] : null;

  static void setDistributionStartTime(String zoneId, DateTime? time) {
    if (time != null) {
      _zoneDistributionStartTime[zoneId] = time;
    } else {
      _zoneDistributionStartTime.remove(zoneId);
    }
  }

  static bool isZoneDriveCompleted(String? zoneId) =>
      zoneId != null ? (_zoneDriveCompleted[zoneId] ?? false) : false;

  static void setZoneDriveCompleted(String zoneId, bool completed, {bool syncRemote = true}) {
    _zoneDriveCompleted[zoneId] = completed;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushZoneMode(
        zoneId,
        _zoneDistributionMode[zoneId] ?? false,
        categories: _zoneDistributionCategories[zoneId]?.toList(),
        driveCompleted: completed,
        startTime: _zoneDistributionStartTime[zoneId]?.toIso8601String(),
      ));
    }
  }

  static void setDistributionMode(
    String zoneId,
    bool active, {
    Set<String>? categories,
    bool? driveCompleted,
    DateTime? startTime,
    bool syncRemote = true,
  }) {
    _zoneDistributionMode[zoneId] = active;
    if (active) {
      _zoneDriveCompleted[zoneId] = false;
      _zoneDistributionStartTime[zoneId] ??= (startTime ?? DateTime.now());
    } else if (driveCompleted != null) {
      _zoneDriveCompleted[zoneId] = driveCompleted;
    }
    if (categories != null) {
      _zoneDistributionCategories[zoneId] = Set<String>.from(categories);
    }
    if (syncRemote) {
      unawaited(DistributionSyncService.pushZoneMode(
        zoneId,
        active,
        categories: _zoneDistributionCategories[zoneId]?.toList(),
        driveCompleted: _zoneDriveCompleted[zoneId] ?? false,
        startTime: _zoneDistributionStartTime[zoneId]?.toIso8601String(),
      ));
    }
  }

  static void setDistributionCategories(
    String zoneId,
    Set<String> categories, {
    bool syncRemote = true,
  }) {
    _zoneDistributionCategories[zoneId] = Set<String>.from(categories);
    if (syncRemote) {
      unawaited(DistributionSyncService.pushZoneMode(
        zoneId,
        _zoneDistributionMode[zoneId] ?? false,
        categories: categories.toList(),
        driveCompleted: _zoneDriveCompleted[zoneId] ?? false,
        startTime: _zoneDistributionStartTime[zoneId]?.toIso8601String(),
      ));
    }
  }

  static final ValueNotifier<int> zonePricingRevision = ValueNotifier<int>(0);

  /// Get Zone-specific Pricing Configuration (falls back to platform defaults)
  static ZonePricingConfig getZonePricing(String zoneId) {
    return _zonePricingConfigs[zoneId] ?? ZonePricingConfig.defaultForZone(zoneId);
  }

  /// Update Zone-specific Pricing Configuration (strictly affects only this zone)
  static void setZonePricing(String zoneId, ZonePricingConfig config, {bool syncRemote = true}) {
    _zonePricingConfigs[zoneId] = config;
    zonePricingRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushZonePricing(zoneId, config));
    }
  }

  /// Sync remote zone pricing configs received from sync server
  static void syncRemoteZonePricings(Map<String, ZonePricingConfig> pricings) {
    bool changed = false;
    for (final entry in pricings.entries) {
      final current = _zonePricingConfigs[entry.key];
      if (current != entry.value) {
        _zonePricingConfigs[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      zonePricingRevision.value++;
    }
  }

  /// Get current assigned Admin Access Code for a zone
  static String getZoneAdminCode(String zoneId) {
    return _zoneAdminCodes[zoneId] ?? '10001';
  }

  /// Rotate Admin Access Code and expel the existing admin for this zone.
  /// Zero operational disruption to shops, employees, distribution drives, or ad campaigns.
  static String rotateZoneAdminCode(String zoneId) {
    final randomInt = 10000 + (DateTime.now().millisecondsSinceEpoch % 89999);
    final newCode = randomInt.toString();
    _zoneAdminCodes[zoneId] = newCode;
    return newCode;
  }

  /// Check whether a shop is crossed (missed delivery past midnight 12:00 AM or closed today)
  static bool isShopCrossed(String? zoneId, String shopId, {DateTime? currentTime}) {
    if (zoneId == null) return false;
    if (CanonicalShops.isShopGone(shopId)) return false;

    // Explicitly marked closed today or crossed
    if (CanonicalShops.isShopClosedToday(shopId) || CanonicalShops.isShopCrossed(shopId)) {
      return true;
    }

    final shop = CanonicalShops.getShopById(shopId);
    if (shop == null || shop.isDistributed || shop.isFollowup) return false;

    // Must be in targeted category
    if (!isShopCategoryTargeted(zoneId, shop.category)) return false;

    final startTime = _zoneDistributionStartTime[zoneId];
    if (startTime == null) return false;

    final now = currentTime ?? DateTime.now();
    final startDay = DateTime(startTime.year, startTime.month, startTime.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    if (currentDay.isAfter(startDay)) {
      // Midnight 12:00 AM has rolled over since the distribution drive started!
      CanonicalShops.markShopCrossed(shopId);
      return true;
    }

    return false;
  }

  /// Check if all targeted shops in zone are distributed (or gone),
  /// and if so, automatically complete the drive and turn OFF distribution mode!
  static bool checkAndAutoCompleteZone(String zoneId) {
    final shopsInZone = CanonicalShops.getShopsForZones({zoneId})
        .where((s) => !s.isFollowup && !CanonicalShops.isShopGone(s.id))
        .where((s) => isShopCategoryTargeted(zoneId, s.category))
        .toList();

    if (shopsInZone.isEmpty) return false;

    final allDone = shopsInZone.every((s) => s.isDistributed);
    if (allDone) {
      // Automatically turn off distribution mode & mark drive completed!
      _zoneDistributionMode[zoneId] = false;
      _zoneDriveCompleted[zoneId] = true;
      unawaited(DistributionSyncService.pushZoneMode(
        zoneId,
        false,
        categories: _zoneDistributionCategories[zoneId]?.toList(),
        driveCompleted: true,
        startTime: _zoneDistributionStartTime[zoneId]?.toIso8601String(),
      ));
      return true;
    }
    return false;
  }

  /// Reset distribution drive for a zone so a new ad campaign can be started fresh
  static void resetDistributionDrive(String zoneId, {bool syncRemote = true}) {
    _zoneDriveCompleted[zoneId] = false;
    _zoneDistributionStartTime[zoneId] = DateTime.now();
    CanonicalShops.resetDistributionForZone(zoneId);
    setDistributionMode(
      zoneId,
      true,
      driveCompleted: false,
      startTime: _zoneDistributionStartTime[zoneId],
      syncRemote: syncRemote,
    );
    if (syncRemote) {
      unawaited(DistributionSyncService.pushResetZoneDrive(zoneId));
    }
  }

  /// Check whether a shop category matches the zone's active distribution filter
  static bool isShopCategoryTargeted(String? zoneId, String? shopCategory) {
    if (!isDistributionModeActive(zoneId)) return false;
    final targeted = getDistributionCategories(zoneId);
    if (targeted.isEmpty || targeted.contains('All') || targeted.contains('all')) {
      return true;
    }
    if (shopCategory == null || shopCategory.isEmpty) return false;

    final cat = ShopCategory.fromString(shopCategory);
    final isSaloon = cat == ShopCategory.saloon;

    final targetsShops = targeted.any((t) {
      final s = t.toLowerCase();
      return s == 'shops' || s == 'shop' || s == 'দোকান' || s == 'দোকানসমূহ';
    });

    final targetsSaloons = targeted.any((t) {
      final s = t.toLowerCase();
      return s == 'saloons' || s == 'saloon' || s == 'সেলুন' || s == 'সেলুনসমূহ';
    });

    if (targetsShops && !isSaloon) return true;
    if (targetsSaloons && isSaloon) return true;

    // Fallback if specific subcategory names were specified
    return targeted.any((t) =>
        t.toLowerCase() == shopCategory.toLowerCase() ||
        t.toLowerCase() == cat.displayName.toLowerCase() ||
        t.toLowerCase() == cat.name.toLowerCase() ||
        t.toLowerCase() == cat.bengaliName.toLowerCase());
  }

  static Future<bool> syncWithRemote() => DistributionSyncService.fetchRemoteState();

  static final Map<String, List<ZoneVertex>> _zoneVertexOverrides = {};
  static final Map<String, String?> _zoneAssignedAdminIds = {};
  static final Map<String, String?> _zoneAssignedAdminNames = {};
  static final Map<String, String?> _zoneAssignedAdminPhones = {
    kolkataCentralId: '+91 98301 11223',
    saltLakeSector5Id: '+91 98301 11223',
  };

  static void assignAdminToZone({
    required String zoneId,
    required String? adminId,
    required String? adminName,
    String? adminPhone,
    bool syncRemote = true,
  }) {
    _zoneAssignedAdminIds[zoneId] = adminId;
    _zoneAssignedAdminNames[zoneId] = adminName;
    if (adminPhone != null) {
      _zoneAssignedAdminPhones[zoneId] = adminPhone;
    } else if (adminId == null) {
      _zoneAssignedAdminPhones.remove(zoneId);
    }
    final existingIdx = _customZones.indexWhere((z) => z.id == zoneId);
    if (existingIdx >= 0) {
      _customZones[existingIdx] = _customZones[existingIdx].copyWith(
        assignedAdminId: adminId,
        assignedAdminName: adminName,
        updatedAt: DateTime.now(),
      );
    }
    zonesRevision.value++;
  }

  static void expelAdminFromZone(String zoneId, {bool syncRemote = true}) {
    assignAdminToZone(
      zoneId: zoneId,
      adminId: null,
      adminName: null,
      syncRemote: syncRemote,
    );
  }

  static String? getZoneAdminPhone(String zoneId) => _zoneAssignedAdminPhones[zoneId];

  static Zone get kolkataCentral => Zone(
        id: kolkataCentralId,
        name: 'Kolkata Central Zone',
        description: 'Major retail hub, MG Road, New Market & Esplanade',
        colorHex: kolkataCentralColor,
        isActive: true,
        isArchived: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        shopCount: 14,
        isDistributionMode: isDistributionModeActive(kolkataCentralId),
        assignedAdminId: _zoneAssignedAdminIds.containsKey(kolkataCentralId)
            ? _zoneAssignedAdminIds[kolkataCentralId]
            : 'admin-10001',
        assignedAdminName: _zoneAssignedAdminNames.containsKey(kolkataCentralId)
            ? _zoneAssignedAdminNames[kolkataCentralId]
            : 'Subhasis Sen (ID: 10001)',
        assignedCompanyId: 'comp-alpha-101',
        assignedCompanyName: 'Alpha Media & Ads Pvt Ltd',
        vertices: _zoneVertexOverrides[kolkataCentralId] ?? kolkataCentralVertices,
      );

  static Zone get saltLakeSector5 => Zone(
        id: saltLakeSector5Id,
        name: 'Salt Lake Sector V',
        description: 'IT and electronics corridor',
        colorHex: saltLakeSector5Color,
        isActive: true,
        isArchived: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        shopCount: 19,
        isDistributionMode: isDistributionModeActive(saltLakeSector5Id),
        assignedAdminId: _zoneAssignedAdminIds.containsKey(saltLakeSector5Id)
            ? _zoneAssignedAdminIds[saltLakeSector5Id]
            : 'admin-10001',
        assignedAdminName: _zoneAssignedAdminNames.containsKey(saltLakeSector5Id)
            ? _zoneAssignedAdminNames[saltLakeSector5Id]
            : 'Subhasis Sen (ID: 10001)',
        assignedCompanyId: 'comp-alpha-101',
        assignedCompanyName: 'Alpha Media & Ads Pvt Ltd',
        vertices: _zoneVertexOverrides[saltLakeSector5Id] ?? saltLakeSector5Vertices,
      );

  static Zone get howrahIndustrial => Zone(
        id: howrahIndustrialId,
        name: 'Howrah Industrial Area',
        description: 'Commercial market around GT Road and Railway hub',
        colorHex: howrahIndustrialColor,
        isActive: true,
        isArchived: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        shopCount: 8,
        isDistributionMode: isDistributionModeActive(howrahIndustrialId),
        assignedAdminId: _zoneAssignedAdminIds[howrahIndustrialId],
        assignedAdminName: _zoneAssignedAdminNames[howrahIndustrialId],
        vertices: _zoneVertexOverrides[howrahIndustrialId] ?? howrahIndustrialVertices,
      );

  static final List<Zone> _customZones = [];

  static final ValueNotifier<int> zonesRevision = ValueNotifier<int>(0);

  static const Map<String, List<String>> _defaultEmployeeZoneAssignments = {
    'emp-20001': ['z-kolkata-central', 'z-saltlake-sector5'],
    'emp-20002': ['z-kolkata-central', 'z-saltlake-sector5'],
    'emp-20003': ['z-saltlake-sector5'],
    'emp-20099': ['z-howrah-industrial'],
  };

  static final Map<String, List<String>> _employeeZoneAssignments =
      Map<String, List<String>>.from(_defaultEmployeeZoneAssignments);

  /// Get zone IDs assigned to an employee
  static List<String> getEmployeeAssignedZoneIds(String employeeId) {
    final cleanId = employeeId.trim();
    final result = <String>[];

    if (_employeeZoneAssignments.containsKey(cleanId)) {
      result.addAll(_employeeZoneAssignments[cleanId]!);
    } else if (_employeeZoneAssignments.containsKey('emp-$cleanId')) {
      result.addAll(_employeeZoneAssignments['emp-$cleanId']!);
    } else if (_defaultEmployeeZoneAssignments.containsKey(cleanId)) {
      result.addAll(_defaultEmployeeZoneAssignments[cleanId]!);
    } else if (_defaultEmployeeZoneAssignments.containsKey('emp-$cleanId')) {
      result.addAll(_defaultEmployeeZoneAssignments['emp-$cleanId']!);
    }

    // Auto-include custom zones created by Master Admin for default field employee (emp-20001)
    // unless explicitly assigned to another employee
    if (cleanId == 'emp-20001' || cleanId == '20001') {
      for (final cz in _customZones) {
        if (!result.contains(cz.id)) {
          bool assignedToOther = false;
          for (final entry in _employeeZoneAssignments.entries) {
            if (entry.key != 'emp-20001' && entry.key != '20001' && entry.value.contains(cz.id)) {
              assignedToOther = true;
              break;
            }
          }
          if (!assignedToOther) {
            result.add(cz.id);
          }
        }
      }
    }
    return result;
  }

  /// Get full Zone objects assigned to an employee
  static List<Zone> getEmployeeAssignedZones(String employeeId) {
    final assignedIds = getEmployeeAssignedZoneIds(employeeId);
    return all.where((z) => assignedIds.contains(z.id)).toList();
  }

  /// Assign an employee to zones and sync across applications
  static void setEmployeeAssignedZoneIds(
    String employeeId,
    List<String> zoneIds, {
    bool syncRemote = true,
  }) {
    final cleanId = employeeId.trim();
    _employeeZoneAssignments[cleanId] = List.from(zoneIds);
    zonesRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushEmployeeZoneAssignment(cleanId, zoneIds));
    }
  }

  /// Bulk sync employee zone assignments received from sync server
  static void syncRemoteEmployeeAssignments(Map<String, List<String>> assignments) {
    bool changed = false;
    for (final entry in assignments.entries) {
      final current = _employeeZoneAssignments[entry.key];
      if (current == null || !listEquals(current, entry.value)) {
        _employeeZoneAssignments[entry.key] = List.from(entry.value);
        changed = true;
      }
    }
    if (changed) {
      zonesRevision.value++;
    }
  }

  static int _employeeDisplayIdCounter = 20004;

  static final List<UserProfile> _managedEmployees = [
    UserProfile(
      id: 'emp-20001',
      email: 'rahul.das@shopad.local',
      fullName: 'Rahul Das',
      role: UserRole.employee,
      phoneNumber: '+91 98111 22334',
      displayId: '20001',
      isActive: true,
      metadata: const {'managed_by_admin': 'admin-10001'},
      createdAt: DateTime(2026, 1, 15),
    ),
    UserProfile(
      id: 'emp-20002',
      email: 'amit.roy@shopad.local',
      fullName: 'Amit Roy',
      role: UserRole.employee,
      phoneNumber: '+91 98222 33445',
      displayId: '20002',
      isActive: true,
      metadata: const {'managed_by_admin': 'admin-10001'},
      createdAt: DateTime(2026, 2, 1),
    ),
    UserProfile(
      id: 'emp-20003',
      email: 'sneha.sen@shopad.local',
      fullName: 'Sneha Sen',
      role: UserRole.employee,
      phoneNumber: '+91 98333 44556',
      displayId: '20003',
      isActive: true,
      metadata: const {'managed_by_admin': 'admin-10001'},
      createdAt: DateTime(2026, 2, 10),
    ),
  ];

  /// Get list of managed employees (returns unmodifiable copy)
  static List<UserProfile> getManagedEmployees({String? adminId}) {
    if (adminId == null || adminId.isEmpty) {
      return List.unmodifiable(_managedEmployees.where((e) => e.isActive));
    }
    return List.unmodifiable(_managedEmployees.where((e) {
      if (!e.isActive) return false;
      final mgr = e.metadata['managed_by_admin']?.toString();
      return mgr == null || mgr == adminId || mgr == 'admin-10001';
    }));
  }

  /// Create a new unclaimed Employee Code (e.g. 20004) without a name
  static UserProfile createEmployeeCode({String? managedByAdminId}) {
    final code = (_employeeDisplayIdCounter++).toString();
    final newEmp = UserProfile(
      id: 'emp-code-$code',
      email: '',
      fullName: '',
      role: UserRole.employee,
      phoneNumber: '',
      displayId: code,
      isActive: true,
      metadata: {'managed_by_admin': managedByAdminId ?? 'admin-10001'},
      createdAt: DateTime.now(),
    );
    _managedEmployees.insert(0, newEmp);
    zonesRevision.value++;
    return newEmp;
  }

  /// Pair/bind an employee code with the employee's name and phone number upon login
  static UserProfile? pairEmployeeCode(
    String code, {
    required String fullName,
    required String phoneNumber,
  }) {
    final cleanCode = code.trim();
    final idx = _managedEmployees.indexWhere((e) => e.displayId == cleanCode);
    if (idx >= 0) {
      final existing = _managedEmployees[idx];
      final updated = existing.copyWith(
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        email: '${fullName.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), '.')}@shopad.local',
      );
      _managedEmployees[idx] = updated;
      zonesRevision.value++;
      return updated;
    }
    return null;
  }

  /// Soft delete an employee from managed employees (past historical shop visits preserve attribution)
  static void deleteEmployee(String employeeId, {bool syncRemote = true}) {
    final cleanId = employeeId.trim();
    final idx = _managedEmployees.indexWhere((e) => e.id == cleanId || e.displayId == cleanId);
    if (idx >= 0) {
      _managedEmployees[idx] = _managedEmployees[idx].copyWith(isActive: false);
    }

    // Unassign this employee from all zones immediately
    final keysToRemove = [cleanId, 'emp-$cleanId', if (cleanId.startsWith('emp-')) cleanId.substring(4)];
    for (final k in keysToRemove) {
      _employeeZoneAssignments[k] = const [];
    }
    zonesRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushEmployeeZoneAssignment(cleanId, const []));
    }
  }

  static int _adminDisplayIdCounter = 10004;

  static final List<UserProfile> _managedAdmins = [
    UserProfile(
      id: 'admin-10001',
      email: 'subhasis.sen@shopad.local',
      fullName: 'Subhasis Sen',
      role: UserRole.admin,
      phoneNumber: '+91 98765 43210',
      displayId: '10001',
      isActive: true,
      metadata: const {
        'admin_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
      },
      createdAt: DateTime(2026, 1, 1),
    ),
    UserProfile(
      id: 'admin-10002',
      email: 'priya.mukherjee@shopad.local',
      fullName: 'Priya Mukherjee',
      role: UserRole.admin,
      phoneNumber: '+91 98300 12345',
      displayId: '10002',
      isActive: true,
      metadata: const {
        'admin_zones': ['z-howrah-industrial'],
      },
      createdAt: DateTime(2026, 1, 10),
    ),
    UserProfile(
      id: 'admin-10003',
      email: 'debanjan.sen@shopad.local',
      fullName: 'Debanjan Sen',
      role: UserRole.admin,
      phoneNumber: '+91 98303 33445',
      displayId: '10003',
      isActive: true,
      metadata: const {
        'admin_zones': ['z-kolkata-central'],
      },
      createdAt: DateTime(2026, 1, 20),
    ),
  ];

  /// Get list of managed admins (returns unmodifiable copy)
  static List<UserProfile> getManagedAdmins() {
    return List.unmodifiable(_managedAdmins.where((a) => a.isActive));
  }

  /// Create a new unclaimed Admin Code (e.g. 10004) without a name
  static UserProfile createAdminCode({bool syncRemote = true}) {
    final code = (_adminDisplayIdCounter++).toString();
    final newAdmin = UserProfile(
      id: 'admin-code-$code',
      email: '',
      fullName: '',
      role: UserRole.admin,
      phoneNumber: '',
      displayId: code,
      isActive: true,
      metadata: const {
        'admin_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
      },
      createdAt: DateTime.now(),
    );
    _managedAdmins.insert(0, newAdmin);
    zonesRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushAdmin(newAdmin));
    }
    return newAdmin;
  }

  /// Pair/bind an admin code with the admin's name and phone number upon login/signup
  static UserProfile pairAdminCode(
    String code, {
    required String fullName,
    required String phoneNumber,
    bool syncRemote = true,
  }) {
    final cleanCode = code.trim();
    final idx = _managedAdmins.indexWhere((a) => a.displayId == cleanCode || a.id == cleanCode || a.id == 'admin-$cleanCode');
    UserProfile updated;
    if (idx >= 0) {
      final existing = _managedAdmins[idx];
      updated = existing.copyWith(
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        email: '${fullName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@shopad.local',
      );
      _managedAdmins[idx] = updated;
    } else {
      updated = UserProfile(
        id: 'admin-$cleanCode',
        email: '${fullName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@shopad.local',
        fullName: fullName.trim(),
        role: UserRole.admin,
        phoneNumber: phoneNumber.trim(),
        displayId: cleanCode,
        isActive: true,
        metadata: const {
          'admin_zones': ['z-kolkata-central', 'z-saltlake-sector5'],
        },
        createdAt: DateTime.now(),
      );
      _managedAdmins.insert(0, updated);
    }
    zonesRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushAdmin(updated));
    }
    return updated;
  }

  /// Synchronize remote admins received from sync server or database
  static void syncRemoteAdmins(List<UserProfile> admins) {
    bool changed = false;
    for (final remote in admins) {
      final idx = _managedAdmins.indexWhere((a) => a.displayId == remote.displayId || a.id == remote.id);
      if (idx >= 0) {
        if (_managedAdmins[idx].fullName != remote.fullName ||
            _managedAdmins[idx].phoneNumber != remote.phoneNumber ||
            _managedAdmins[idx].isActive != remote.isActive) {
          _managedAdmins[idx] = remote;
          changed = true;
        }
      } else {
        _managedAdmins.add(remote);
        changed = true;
      }
    }
    if (changed) {
      zonesRevision.value++;
    }
  }

  /// Get employee IDs assigned to a specific zone
  static List<String> getZoneAssignedEmployeeIds(String zoneId) {
    final result = <String>{};
    for (final entry in _employeeZoneAssignments.entries) {
      if (entry.value.contains(zoneId)) {
        final emp = _managedEmployees.firstWhere(
          (e) => e.id == entry.key || e.displayId == entry.key || 'emp-${e.displayId}' == entry.key,
          orElse: () => UserProfile(
            id: entry.key,
            email: '',
            fullName: 'Employee (${entry.key})',
            role: UserRole.employee,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        if (emp.isActive) {
          result.add(emp.id);
        }
      }
    }
    return result.toList();
  }

  /// Get active UserProfile objects assigned to a specific zone
  static List<UserProfile> getZoneAssignedEmployees(String zoneId) {
    final ids = getZoneAssignedEmployeeIds(zoneId);
    return _managedEmployees.where((e) => e.isActive && (ids.contains(e.id) || ids.contains(e.displayId))).toList();
  }

  /// Returns true if the zone has at least one active employee assigned
  static bool hasAssignedEmployee(String zoneId) {
    return getZoneAssignedEmployeeIds(zoneId).isNotEmpty;
  }

  /// Assign an employee to a specific zone
  static void assignEmployeeToZone(String zoneId, String employeeId, {bool syncRemote = true}) {
    final current = getEmployeeAssignedZoneIds(employeeId);
    if (!current.contains(zoneId)) {
      final updated = [...current, zoneId];
      setEmployeeAssignedZoneIds(employeeId, updated, syncRemote: syncRemote);
    }
  }

  /// Unassign an employee from a specific zone (employee remains active in managed pool)
  static void unassignEmployeeFromZone(String zoneId, String employeeId, {bool syncRemote = true}) {
    final current = getEmployeeAssignedZoneIds(employeeId);
    if (current.contains(zoneId)) {
      final updated = current.where((id) => id != zoneId).toList();
      setEmployeeAssignedZoneIds(employeeId, updated, syncRemote: syncRemote);
    }
  }

  /// Register or update a custom zone created in Master Admin
  static void registerCustomZone(Zone zone, {bool syncRemote = true}) {
    final idx = _customZones.indexWhere((z) => z.id == zone.id);
    final isNew = idx < 0;
    if (idx >= 0) {
      _customZones[idx] = zone;
    } else {
      _customZones.add(zone);
    }
    _zoneVertexOverrides[zone.id] = zone.vertices;
    zonesRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushCustomZone(zone));
      if (isNew) {
        final currentAssignments = getEmployeeAssignedZoneIds('emp-20001');
        unawaited(DistributionSyncService.pushEmployeeZoneAssignment(
          'emp-20001',
          currentAssignments,
        ));
      }
    }
  }

  /// Bulk sync custom zones received from remote sync server
  static void syncRemoteZones(List<Zone> zones) {
    bool changed = false;
    for (final z in zones) {
      final idx = _customZones.indexWhere((cz) => cz.id == z.id);
      if (idx >= 0) {
        if (_customZones[idx] != z) {
          _customZones[idx] = z;
          changed = true;
        }
      } else {
        _customZones.add(z);
        changed = true;
      }
      _zoneVertexOverrides[z.id] = z.vertices;
    }
    if (changed) {
      zonesRevision.value++;
    }
  }

  /// Update the polygon vertices for any zone (canonical or custom) and sync remote
  static void updateZoneVertices(String zoneId, List<ZoneVertex> vertices, {bool syncRemote = true}) {
    _zoneVertexOverrides[zoneId] = vertices;
    final existing = all.firstWhere((z) => z.id == zoneId, orElse: () => kolkataCentral);
    final updated = existing.copyWith(
      vertices: vertices,
      updatedAt: DateTime.now(),
    );
    registerCustomZone(updated, syncRemote: syncRemote);
  }

  /// Remove or archive custom zone
  static void removeCustomZone(String zoneId, {bool syncRemote = true}) {
    _customZones.removeWhere((z) => z.id == zoneId);
    _zoneVertexOverrides.remove(zoneId);
    zonesRevision.value++;
    if (syncRemote) {
      unawaited(DistributionSyncService.pushRemoveZone(zoneId));
    }
  }

  /// All canonical zones
  static List<Zone> get all {
    final canonicalList = [
      kolkataCentral,
      saltLakeSector5,
      howrahIndustrial,
    ];
    final canonicalIds = canonicalList.map((z) => z.id).toSet();
    return [
      ...canonicalList,
      ..._customZones.where((z) => !canonicalIds.contains(z.id)),
    ];
  }
}

class DistributionMaterial {
  final String id;
  final String name;
  final String targetBusinessType; // 'all', 'shop', 'saloon'
  final int defaultQuantity;
  final DateTime createdAt;

  const DistributionMaterial({
    required this.id,
    required this.name,
    this.targetBusinessType = 'all',
    this.defaultQuantity = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetBusinessType': targetBusinessType,
        'defaultQuantity': defaultQuantity,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DistributionMaterial.fromJson(Map<String, dynamic> json) =>
      DistributionMaterial(
        id: json['id'] as String,
        name: json['name'] as String,
        targetBusinessType:
            (json['targetBusinessType'] as String?) ?? 'all',
        defaultQuantity: (json['defaultQuantity'] as num?)?.toInt() ?? 1,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  DistributionMaterial copyWith({
    String? id,
    String? name,
    String? targetBusinessType,
    int? defaultQuantity,
    DateTime? createdAt,
  }) {
    return DistributionMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      targetBusinessType: targetBusinessType ?? this.targetBusinessType,
      defaultQuantity: defaultQuantity ?? this.defaultQuantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MaterialDistributionRun {
  final String id;
  final String zoneId;
  final String materialId;
  final String materialName;
  final String targetBusinessType; // 'all', 'shop', 'saloon'
  final String status; // 'active', 'completed', 'stopped'
  final List<String> snapshotShopIds;
  final List<String> distributedShopIds;
  final List<String> goneShopIds;
  final DateTime startedAt;
  final DateTime? completedAt;

  const MaterialDistributionRun({
    required this.id,
    required this.zoneId,
    required this.materialId,
    required this.materialName,
    this.targetBusinessType = 'all',
    this.status = 'active',
    this.snapshotShopIds = const [],
    this.distributedShopIds = const [],
    this.goneShopIds = const [],
    required this.startedAt,
    this.completedAt,
  });

  int get totalTargetCount => snapshotShopIds.length;
  int get deliveredCount => distributedShopIds.length;
  int get goneCount => goneShopIds.length;
  int get completedOrGoneCount => deliveredCount + goneCount;

  double get progressFraction => totalTargetCount == 0
      ? 1.0
      : (completedOrGoneCount / totalTargetCount).clamp(0.0, 1.0);

  int get progressPercent => (progressFraction * 100).round();

  bool get isCompleted =>
      status == 'completed' ||
      (totalTargetCount > 0 && completedOrGoneCount >= totalTargetCount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'materialId': materialId,
        'materialName': materialName,
        'targetBusinessType': targetBusinessType,
        'status': status,
        'snapshotShopIds': snapshotShopIds,
        'distributedShopIds': distributedShopIds,
        'goneShopIds': goneShopIds,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory MaterialDistributionRun.fromJson(Map<String, dynamic> json) =>
      MaterialDistributionRun(
        id: json['id'] as String,
        zoneId: json['zoneId'] as String,
        materialId: json['materialId'] as String,
        materialName: json['materialName'] as String,
        targetBusinessType:
            (json['targetBusinessType'] as String?) ?? 'all',
        status: (json['status'] as String?) ?? 'active',
        snapshotShopIds: (json['snapshotShopIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        distributedShopIds: (json['distributedShopIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        goneShopIds: (json['goneShopIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  MaterialDistributionRun copyWith({
    String? id,
    String? zoneId,
    String? materialId,
    String? materialName,
    String? targetBusinessType,
    String? status,
    List<String>? snapshotShopIds,
    List<String>? distributedShopIds,
    List<String>? goneShopIds,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return MaterialDistributionRun(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      targetBusinessType: targetBusinessType ?? this.targetBusinessType,
      status: status ?? this.status,
      snapshotShopIds: snapshotShopIds ?? this.snapshotShopIds,
      distributedShopIds: distributedShopIds ?? this.distributedShopIds,
      goneShopIds: goneShopIds ?? this.goneShopIds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class CompanyAdDistributionRun {
  final String id;
  final String zoneId;
  final String companyId;
  final String companyName;
  final String businessType; // 'shop', 'saloon'
  final String placementSide; // 'left', 'right', 'both'
  final String standSize; // 'A5', 'A6'
  final DateTime slotStartDate;
  final DateTime slotEndDate;
  final String? adCreativeImageUrl;
  final DateTime? adDesignUploadedAt;
  final String? printoutProofImageUrl;
  final DateTime? printoutProofUploadedAt;
  final String status; // 'pending', 'active', 'completed', 'stopped'
  final List<String> snapshotShopIds;
  final List<String> distributedShopIds;
  final List<String> goneShopIds;
  final DateTime startedAt;
  final DateTime? completedAt;

  const CompanyAdDistributionRun({
    required this.id,
    required this.zoneId,
    required this.companyId,
    required this.companyName,
    required this.businessType,
    required this.placementSide,
    this.standSize = 'A5',
    required this.slotStartDate,
    required this.slotEndDate,
    this.adCreativeImageUrl,
    this.adDesignUploadedAt,
    this.printoutProofImageUrl,
    this.printoutProofUploadedAt,
    this.status = 'active',
    this.snapshotShopIds = const [],
    this.distributedShopIds = const [],
    this.goneShopIds = const [],
    required this.startedAt,
    this.completedAt,
  });

  bool get hasAdDesign =>
      adCreativeImageUrl != null && adCreativeImageUrl!.trim().isNotEmpty;

  bool get hasPrintoutProof =>
      printoutProofImageUrl != null && printoutProofImageUrl!.trim().isNotEmpty;

  bool get canUploadPrintout => hasAdDesign;

  bool get canStartDistribution => hasAdDesign && hasPrintoutProof;

  bool get isDistributionActive => status == 'active';

  int get totalTargetCount => snapshotShopIds.length;
  int get deliveredCount => distributedShopIds.length;
  int get goneCount => goneShopIds.length;
  int get completedOrGoneCount => deliveredCount + goneCount;

  double get progressFraction => totalTargetCount == 0
      ? 1.0
      : (completedOrGoneCount / totalTargetCount).clamp(0.0, 1.0);

  int get progressPercent => (progressFraction * 100).round();

  bool get isCompleted =>
      status == 'completed' ||
      (totalTargetCount > 0 && completedOrGoneCount >= totalTargetCount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'companyId': companyId,
        'companyName': companyName,
        'businessType': businessType,
        'placementSide': placementSide,
        'standSize': standSize,
        'slotStartDate': slotStartDate.toIso8601String(),
        'slotEndDate': slotEndDate.toIso8601String(),
        'adCreativeImageUrl': adCreativeImageUrl,
        'adDesignUploadedAt': adDesignUploadedAt?.toIso8601String(),
        'printoutProofImageUrl': printoutProofImageUrl,
        'printoutProofUploadedAt': printoutProofUploadedAt?.toIso8601String(),
        'status': status,
        'snapshotShopIds': snapshotShopIds,
        'distributedShopIds': distributedShopIds,
        'goneShopIds': goneShopIds,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory CompanyAdDistributionRun.fromJson(Map<String, dynamic> json) =>
      CompanyAdDistributionRun(
        id: json['id'] as String,
        zoneId: json['zoneId'] as String,
        companyId: json['companyId'] as String,
        companyName: json['companyName'] as String,
        businessType: (json['businessType'] as String?) ?? 'shop',
        placementSide: (json['placementSide'] as String?) ?? 'left',
        standSize: (json['standSize'] as String?) ?? 'A5',
        slotStartDate: json['slotStartDate'] != null
            ? DateTime.parse(json['slotStartDate'] as String)
            : DateTime.now(),
        slotEndDate: json['slotEndDate'] != null
            ? DateTime.parse(json['slotEndDate'] as String)
            : DateTime.now().add(const Duration(days: 7)),
        adCreativeImageUrl: json['adCreativeImageUrl'] as String?,
        adDesignUploadedAt: json['adDesignUploadedAt'] != null
            ? DateTime.tryParse(json['adDesignUploadedAt'] as String)
            : (json['adCreativeImageUrl'] != null ? DateTime.now() : null),
        printoutProofImageUrl: json['printoutProofImageUrl'] as String?,
        printoutProofUploadedAt: json['printoutProofUploadedAt'] != null
            ? DateTime.tryParse(json['printoutProofUploadedAt'] as String)
            : (json['printoutProofImageUrl'] != null ? DateTime.now() : null),
        status: (json['status'] as String?) ?? 'active',
        snapshotShopIds: (json['snapshotShopIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        distributedShopIds: (json['distributedShopIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        goneShopIds: (json['goneShopIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  CompanyAdDistributionRun copyWith({
    String? id,
    String? zoneId,
    String? companyId,
    String? companyName,
    String? businessType,
    String? placementSide,
    String? standSize,
    DateTime? slotStartDate,
    DateTime? slotEndDate,
    String? adCreativeImageUrl,
    bool clearAdCreative = false,
    DateTime? adDesignUploadedAt,
    String? printoutProofImageUrl,
    bool clearPrintoutProof = false,
    DateTime? printoutProofUploadedAt,
    String? status,
    List<String>? snapshotShopIds,
    List<String>? distributedShopIds,
    List<String>? goneShopIds,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return CompanyAdDistributionRun(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      businessType: businessType ?? this.businessType,
      placementSide: placementSide ?? this.placementSide,
      standSize: standSize ?? this.standSize,
      slotStartDate: slotStartDate ?? this.slotStartDate,
      slotEndDate: slotEndDate ?? this.slotEndDate,
      adCreativeImageUrl: clearAdCreative
          ? null
          : (adCreativeImageUrl ?? this.adCreativeImageUrl),
      adDesignUploadedAt: clearAdCreative
          ? null
          : (adDesignUploadedAt ?? this.adDesignUploadedAt),
      printoutProofImageUrl: clearPrintoutProof
          ? null
          : (printoutProofImageUrl ?? this.printoutProofImageUrl),
      printoutProofUploadedAt: clearPrintoutProof
          ? null
          : (printoutProofUploadedAt ?? this.printoutProofUploadedAt),
      status: status ?? this.status,
      snapshotShopIds: snapshotShopIds ?? this.snapshotShopIds,
      distributedShopIds: distributedShopIds ?? this.distributedShopIds,
      goneShopIds: goneShopIds ?? this.goneShopIds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

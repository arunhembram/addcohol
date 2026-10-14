class ZoneSummary {
  final int totalShops;
  final List<dynamic> assignedEmployees;
  final Map<String, dynamic>? activeCompany;
  final int todayUploadsCount;
  final int verifiedCount;
  final int submittedCount;
  final int rejectedCount;
  final int compliancePercentage;

  ZoneSummary({
    required this.totalShops,
    required this.assignedEmployees,
    this.activeCompany,
    required this.todayUploadsCount,
    required this.verifiedCount,
    required this.submittedCount,
    required this.rejectedCount,
    required this.compliancePercentage,
  });

  factory ZoneSummary.fromJson(Map<String, dynamic> json) {
    return ZoneSummary(
      totalShops: json['total_shops'] ?? 0,
      assignedEmployees: json['assigned_employees'] ?? [],
      activeCompany: json['active_company'],
      todayUploadsCount: json['today_uploads_count'] ?? 0,
      verifiedCount: json['verified_count'] ?? 0,
      submittedCount: json['submitted_count'] ?? 0,
      rejectedCount: json['rejected_count'] ?? 0,
      compliancePercentage: json['compliance_percentage'] ?? 0,
    );
  }
}

class ZoneModel {
  final String id;
  final String name;
  final String? description;
  final String? boundaryGeojson;
  final String status;
  final String? createdByUserId;
  final String createdAt;
  final ZoneSummary? summary;

  ZoneModel({
    required this.id,
    required this.name,
    this.description,
    this.boundaryGeojson,
    required this.status,
    this.createdByUserId,
    required this.createdAt,
    this.summary,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      boundaryGeojson: json['boundary_geojson'],
      status: json['status'] ?? 'active',
      createdByUserId: json['created_by_user_id'],
      createdAt: json['created_at'] ?? '',
      summary: json['summary'] != null ? ZoneSummary.fromJson(json['summary']) : null,
    );
  }
}

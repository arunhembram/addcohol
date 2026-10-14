class IssueModel {
  final String id;
  final String shopId;
  final String shopName;
  final String shopCode;
  final String zoneId;
  final String zoneName;
  final String createdByUserId;
  final String reporterName;
  final String issueType;
  final String notes;
  final String? photoPath;
  final String status; // 'open', 'assigned', 'resolved', 'closed'
  final String? assignedEmployeeUserId;
  final String? assignedEmployeeName;
  final String createdAt;
  final String? resolvedAt;

  IssueModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.shopCode,
    required this.zoneId,
    required this.zoneName,
    required this.createdByUserId,
    required this.reporterName,
    required this.issueType,
    required this.notes,
    this.photoPath,
    required this.status,
    this.assignedEmployeeUserId,
    this.assignedEmployeeName,
    required this.createdAt,
    this.resolvedAt,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      shopName: json['shop_name'] ?? 'Unknown Shop',
      shopCode: json['shop_code'] ?? '',
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? 'Unknown Zone',
      createdByUserId: json['created_by_user_id'] ?? '',
      reporterName: json['reporter_name'] ?? 'Unknown',
      issueType: json['issue_type'] ?? 'other',
      notes: json['notes'] ?? '',
      photoPath: json['photo_path'],
      status: json['status'] ?? 'open',
      assignedEmployeeUserId: json['assigned_employee_user_id'],
      assignedEmployeeName: json['assigned_employee_name'],
      createdAt: json['created_at'] ?? '',
      resolvedAt: json['resolved_at'],
    );
  }
}

class AssignmentModel {
  final String id;
  final String zoneId;
  final String companyId;
  final String campaignName;
  final String? campaignDescription;
  final String campaignStartDate;
  final String campaignEndDate;
  final String status;
  final bool exclusivityEnabled;
  final String? zoneName;
  final String? companyName;
  final String createdAt;

  AssignmentModel({
    required this.id,
    required this.zoneId,
    required this.companyId,
    required this.campaignName,
    this.campaignDescription,
    required this.campaignStartDate,
    required this.campaignEndDate,
    required this.status,
    required this.exclusivityEnabled,
    this.zoneName,
    this.companyName,
    required this.createdAt,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'] ?? '',
      zoneId: json['zone_id'] ?? '',
      companyId: json['company_id'] ?? '',
      campaignName: json['campaign_name'] ?? '',
      campaignDescription: json['campaign_description'],
      campaignStartDate: json['campaign_start_date'] ?? '',
      campaignEndDate: json['campaign_end_date'] ?? '',
      status: json['status'] ?? 'active',
      exclusivityEnabled: json['exclusivity_enabled'] ?? true,
      zoneName: json['zone_name'],
      companyName: json['company_name'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

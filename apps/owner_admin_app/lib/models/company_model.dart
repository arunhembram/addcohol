class CompanyModel {
  final String id;
  final String name;
  final String? contactPersonName;
  final String? contactPhone;
  final String? contactEmail;
  final bool isActive;
  final int activeZonesCount;
  final int totalAssignmentsCount;
  final List<dynamic> users;

  CompanyModel({
    required this.id,
    required this.name,
    this.contactPersonName,
    this.contactPhone,
    this.contactEmail,
    required this.isActive,
    required this.activeZonesCount,
    required this.totalAssignmentsCount,
    required this.users,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      contactPersonName: json['contact_person_name'],
      contactPhone: json['contact_phone'],
      contactEmail: json['contact_email'],
      isActive: json['is_active'] ?? true,
      activeZonesCount: json['active_zones_count'] ?? 0,
      totalAssignmentsCount: json['total_assignments_count'] ?? 0,
      users: json['users'] ?? [],
    );
  }
}

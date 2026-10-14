import 'package:equatable/equatable.dart';

class AdCampaign extends Equatable {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final String mediaUrl;
  final String status;
  final double budget;
  final double targetRadiusKm;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  const AdCampaign({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    required this.mediaUrl,
    required this.status,
    required this.budget,
    this.targetRadiusKm = 5.0,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      mediaUrl: json['media_url'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      targetRadiusKm: (json['target_radius_km'] as num?)?.toDouble() ?? 5.0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'description': description,
      'media_url': mediaUrl,
      'status': status,
      'budget': budget,
      'target_radius_km': targetRadiusKm,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    companyId,
    title,
    description,
    mediaUrl,
    status,
    budget,
    targetRadiusKm,
    startDate,
    endDate,
    createdAt,
  ];
}

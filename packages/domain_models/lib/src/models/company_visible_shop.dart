import 'package:equatable/equatable.dart';
import '../enums/shop_category.dart';

/// Sanitized shop representation for Company access.
/// Strictly excludes: Aadhaar documents, employee IDs, personal audit logs,
/// private storage paths, and payment management controls.
class CompanyVisibleShop extends Equatable {
  final String id;
  final String shopCode;
  final String zoneId;
  final String zoneName;
  final String shopName;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final int screenCount;
  final String status;
  final DateTime? agreedAt;
  final DateTime createdAt;
  final bool? hasTodayProof;
  final String? todayProofUrl;
  final String? photoUrl;
  final DateTime? photoUpdatedAt;
  final String? weeklyClosedDay;

  const CompanyVisibleShop({
    required this.id,
    required this.shopCode,
    required this.zoneId,
    required this.zoneName,
    required this.shopName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.screenCount = 1,
    required this.status,
    this.agreedAt,
    required this.createdAt,
    this.hasTodayProof,
    this.todayProofUrl,
    this.photoUrl,
    this.photoUpdatedAt,
    this.weeklyClosedDay,
  });

  ShopCategory get shopCategory => ShopCategory.fromString(category);

  bool get isActive => status.toLowerCase() == 'active' || status.toLowerCase() == 'agreed';

  bool get hasPhoto =>
      (photoUrl != null && photoUrl!.isNotEmpty) ||
      (todayProofUrl != null && todayProofUrl!.isNotEmpty);

  String? get effectivePhotoUrl =>
      (photoUrl != null && photoUrl!.isNotEmpty) ? photoUrl : todayProofUrl;

  factory CompanyVisibleShop.fromJson(
    Map<String, dynamic> json, {
    bool canViewDailyProof = false,
  }) {
    return CompanyVisibleShop(
      id: json['id'] as String? ?? '',
      shopCode: json['shop_code'] as String? ?? '',
      zoneId: json['zone_id'] as String? ?? '',
      zoneName: json['zone_name'] as String? ?? 'Assigned Zone',
      shopName: json['shop_name'] as String? ?? 'Shop',
      category: json['category'] as String? ?? 'Other',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      screenCount: (json['screen_count'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'agreed',
      agreedAt: json['agreed_at'] != null
          ? DateTime.tryParse(json['agreed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      hasTodayProof: canViewDailyProof ? (json['has_today_proof'] as bool? ?? false) : null,
      todayProofUrl: canViewDailyProof ? (json['today_proof_url'] as String?) : null,
      photoUrl: json['photo_url'] as String? ?? json['shopfront_photo_url'] as String? ?? json['today_proof_url'] as String?,
      photoUpdatedAt: json['photo_updated_at'] != null
          ? DateTime.tryParse(json['photo_updated_at'] as String)
          : (json['distributed_at'] != null
              ? DateTime.tryParse(json['distributed_at'] as String)
              : null),
      weeklyClosedDay: json['weekly_closed_day'] as String?,
    );
  }

  Map<String, dynamic> toJson({bool canViewDailyProof = false}) {
    return {
      'id': id,
      'shop_code': shopCode,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'shop_name': shopName,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'screen_count': screenCount,
      'status': status,
      'agreed_at': agreedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
      'photo_updated_at': photoUpdatedAt?.toIso8601String(),
      'weekly_closed_day': weeklyClosedDay,
      if (canViewDailyProof) ...{
        'has_today_proof': hasTodayProof,
        'today_proof_url': todayProofUrl,
      },
    };
  }

  @override
  List<Object?> get props => [
    id,
    shopCode,
    zoneId,
    zoneName,
    shopName,
    category,
    address,
    latitude,
    longitude,
    screenCount,
    status,
    agreedAt,
    createdAt,
    hasTodayProof,
    todayProofUrl,
    photoUrl,
    photoUpdatedAt,
    weeklyClosedDay,
  ];
}

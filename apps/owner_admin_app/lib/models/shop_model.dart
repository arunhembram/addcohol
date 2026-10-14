class CurrentProofModel {
  final String id;
  final String status;
  final String uploaderType;
  final String capturedAt;
  final String? rejectionReason;
  final double distanceMeters;
  final bool isDistanceSuspicious;
  final bool hasImage;
  final String? imageUrl;

  CurrentProofModel({
    required this.id,
    required this.status,
    required this.uploaderType,
    required this.capturedAt,
    this.rejectionReason,
    required this.distanceMeters,
    required this.isDistanceSuspicious,
    required this.hasImage,
    this.imageUrl,
  });

  factory CurrentProofModel.fromJson(Map<String, dynamic> json) {
    return CurrentProofModel(
      id: json['id'] ?? '',
      status: json['status'] ?? 'submitted',
      uploaderType: json['uploader_type'] ?? 'employee',
      capturedAt: json['captured_at'] ?? '',
      rejectionReason: json['rejection_reason'],
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      isDistanceSuspicious: json['is_distance_suspicious'] ?? false,
      hasImage: json['has_image'] ?? false,
      imageUrl: json['image_url'],
    );
  }
}

class ShopModel {
  final String id;
  final String shopCode;
  final String shopName;
  final String category;
  final String logoType;
  final String address;
  final double latitude;
  final double longitude;
  final String zoneId;
  final String zoneName;
  final String? merchantPhone;
  final String? merchantUserId;
  final String uploadMode;
  final String status;
  final String todayUploadState; // 'not_uploaded', 'submitted', 'verified', 'rejected'
  final CurrentProofModel? currentProof;

  ShopModel({
    required this.id,
    required this.shopCode,
    required this.shopName,
    required this.category,
    required this.logoType,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.zoneId,
    required this.zoneName,
    this.merchantPhone,
    this.merchantUserId,
    required this.uploadMode,
    required this.status,
    required this.todayUploadState,
    this.currentProof,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? '',
      shopCode: json['shop_code'] ?? '',
      shopName: json['shop_name'] ?? '',
      category: json['category'] ?? 'other',
      logoType: json['logo_type'] ?? 'default',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? 'Unknown Zone',
      merchantPhone: json['merchant_phone'],
      merchantUserId: json['merchant_user_id'],
      uploadMode: json['upload_mode'] ?? 'both',
      status: json['status'] ?? 'active',
      todayUploadState: json['today_upload_state'] ?? 'not_uploaded',
      currentProof: json['current_proof'] != null
          ? CurrentProofModel.fromJson(json['current_proof'])
          : null,
    );
  }
}

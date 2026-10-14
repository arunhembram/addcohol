class UploadModel {
  final String id;
  final String shopId;
  final String shopName;
  final String shopCode;
  final String shopCategory;
  final String shopAddress;
  final String zoneId;
  final String zoneName;
  final String businessDate;
  final String uploadedByUserId;
  final String uploaderName;
  final String uploaderType;
  final String? imageStoragePath;
  final String? imageDeletedAt;
  final String capturedAt;
  final String uploadedAt;
  final double capturedLatitude;
  final double capturedLongitude;
  final double distanceMeters;
  final bool isDistanceSuspicious;
  final String status; // 'submitted', 'verified', 'rejected', 'expired'
  final String? rejectionReason;
  final bool hasImage;
  final String? imageUrl;

  UploadModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.shopCode,
    required this.shopCategory,
    required this.shopAddress,
    required this.zoneId,
    required this.zoneName,
    required this.businessDate,
    required this.uploadedByUserId,
    required this.uploaderName,
    required this.uploaderType,
    this.imageStoragePath,
    this.imageDeletedAt,
    required this.capturedAt,
    required this.uploadedAt,
    required this.capturedLatitude,
    required this.capturedLongitude,
    required this.distanceMeters,
    required this.isDistanceSuspicious,
    required this.status,
    this.rejectionReason,
    required this.hasImage,
    this.imageUrl,
  });

  factory UploadModel.fromJson(Map<String, dynamic> json) {
    return UploadModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      shopName: json['shop_name'] ?? 'Unknown Shop',
      shopCode: json['shop_code'] ?? '',
      shopCategory: json['shop_category'] ?? '',
      shopAddress: json['shop_address'] ?? '',
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? 'Unknown Zone',
      businessDate: json['business_date'] ?? '',
      uploadedByUserId: json['uploaded_by_user_id'] ?? '',
      uploaderName: json['uploader_name'] ?? 'Unknown',
      uploaderType: json['uploader_type'] ?? 'employee',
      imageStoragePath: json['image_storage_path'],
      imageDeletedAt: json['image_deleted_at'],
      capturedAt: json['captured_at'] ?? '',
      uploadedAt: json['uploaded_at'] ?? '',
      capturedLatitude: (json['captured_latitude'] as num?)?.toDouble() ?? 0.0,
      capturedLongitude: (json['captured_longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      isDistanceSuspicious: json['is_distance_suspicious'] ?? false,
      status: json['status'] ?? 'submitted',
      rejectionReason: json['rejection_reason'],
      hasImage: json['has_image'] ?? false,
      imageUrl: json['image_url'],
    );
  }
}

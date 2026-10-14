class ShopDailyUpload {
  final String id;
  final String shopId;
  final String? shopCode;
  final String uploaderId;
  final String photoStoragePath;
  final String photoUrl;
  final DateTime captureTime;
  final DateTime serverUploadTime;
  final String businessDate; // YYYY-MM-DD
  final double latitude;
  final double longitude;
  final double geofenceDistanceMeters;
  final bool isGeofenceVerified;
  final DateTime expiryTime;
  final bool isExpired;
  final String verificationStatus; // 'pending', 'verified', 'flagged', 'rejected'
  final Map<String, dynamic> metadata;

  const ShopDailyUpload({
    required this.id,
    required this.shopId,
    this.shopCode,
    required this.uploaderId,
    required this.photoStoragePath,
    required this.photoUrl,
    required this.captureTime,
    required this.serverUploadTime,
    required this.businessDate,
    required this.latitude,
    required this.longitude,
    required this.geofenceDistanceMeters,
    required this.isGeofenceVerified,
    required this.expiryTime,
    this.isExpired = false,
    this.verificationStatus = 'verified',
    this.metadata = const {},
  });

  factory ShopDailyUpload.fromJson(Map<String, dynamic> json) {
    return ShopDailyUpload(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      shopCode: json['shop_code'] as String?,
      uploaderId: json['uploader_id'] as String? ?? 'shopkeeper',
      photoStoragePath: json['photo_storage_path'] as String? ?? '',
      photoUrl: json['photo_url'] as String? ?? '',
      captureTime: json['capture_time'] != null
          ? DateTime.parse(json['capture_time'] as String)
          : DateTime.now(),
      serverUploadTime: json['server_upload_time'] != null
          ? DateTime.parse(json['server_upload_time'] as String)
          : DateTime.now(),
      businessDate: json['business_date'] as String? ??
          DateTime.now().toIso8601String().substring(0, 10),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      geofenceDistanceMeters:
          (json['geofence_distance_meters'] as num?)?.toDouble() ?? 0.0,
      isGeofenceVerified: json['is_geofence_verified'] as bool? ?? true,
      expiryTime: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : (json['expiry_time'] != null
              ? DateTime.parse(json['expiry_time'] as String)
              : DateTime.now().add(const Duration(hours: 12))),
      isExpired: json['is_expired'] as bool? ?? false,
      verificationStatus: json['verification_status'] as String? ?? 'verified',
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_code': shopCode,
      'uploader_id': uploaderId,
      'photo_storage_path': photoStoragePath,
      'photo_url': photoUrl,
      'capture_time': captureTime.toIso8601String(),
      'server_upload_time': serverUploadTime.toIso8601String(),
      'business_date': businessDate,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_distance_meters': geofenceDistanceMeters,
      'is_geofence_verified': isGeofenceVerified,
      'expires_at': expiryTime.toIso8601String(),
      'is_expired': isExpired,
      'verification_status': verificationStatus,
      'metadata': metadata,
    };
  }

  ShopDailyUpload copyWith({
    String? id,
    String? shopId,
    String? shopCode,
    String? uploaderId,
    String? photoStoragePath,
    String? photoUrl,
    DateTime? captureTime,
    DateTime? serverUploadTime,
    String? businessDate,
    double? latitude,
    double? longitude,
    double? geofenceDistanceMeters,
    bool? isGeofenceVerified,
    DateTime? expiryTime,
    bool? isExpired,
    String? verificationStatus,
    Map<String, dynamic>? metadata,
  }) {
    return ShopDailyUpload(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopCode: shopCode ?? this.shopCode,
      uploaderId: uploaderId ?? this.uploaderId,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
      photoUrl: photoUrl ?? this.photoUrl,
      captureTime: captureTime ?? this.captureTime,
      serverUploadTime: serverUploadTime ?? this.serverUploadTime,
      businessDate: businessDate ?? this.businessDate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceDistanceMeters:
          geofenceDistanceMeters ?? this.geofenceDistanceMeters,
      isGeofenceVerified: isGeofenceVerified ?? this.isGeofenceVerified,
      expiryTime: expiryTime ?? this.expiryTime,
      isExpired: isExpired ?? this.isExpired,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      metadata: metadata ?? this.metadata,
    );
  }
}

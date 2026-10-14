import 'package:equatable/equatable.dart';

class DeviceScreen extends Equatable {
  final String id;
  final String shopId;
  final String screenCode;
  final String status;
  final String resolution;
  final String locationNote;
  final DateTime? lastPingAt;
  final DateTime createdAt;

  const DeviceScreen({
    required this.id,
    required this.shopId,
    required this.screenCode,
    this.status = 'offline',
    this.resolution = '1920x1080',
    this.locationNote = '',
    this.lastPingAt,
    required this.createdAt,
  });

  factory DeviceScreen.fromJson(Map<String, dynamic> json) {
    return DeviceScreen(
      id: json['id'] as String? ?? '',
      shopId: json['shop_id'] as String? ?? '',
      screenCode: json['screen_code'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      resolution: json['resolution'] as String? ?? '1920x1080',
      locationNote: json['location_note'] as String? ?? '',
      lastPingAt: json['last_ping_at'] != null
          ? DateTime.tryParse(json['last_ping_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'screen_code': screenCode,
      'status': status,
      'resolution': resolution,
      'location_note': locationNote,
      'last_ping_at': lastPingAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isOnline {
    if (lastPingAt == null) return false;
    return DateTime.now().difference(lastPingAt!).inMinutes < 5;
  }

  @override
  List<Object?> get props => [
    id,
    shopId,
    screenCode,
    status,
    resolution,
    locationNote,
    lastPingAt,
    createdAt,
  ];
}

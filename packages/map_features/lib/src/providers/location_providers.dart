import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return LocationService(logger: logger);
});

final locationHealthCheckProvider = FutureProvider.autoDispose<SubsystemStatus>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return await service.checkHealth();
});

final userCurrentPositionProvider = FutureProvider.autoDispose<LocationCoords?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return await service.getCurrentLocation();
});

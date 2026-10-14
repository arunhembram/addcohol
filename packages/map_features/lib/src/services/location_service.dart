import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:geolocator/geolocator.dart' hide ServiceStatus;

class LocationService {
  final AppLogger _logger;

  const LocationService({AppLogger? logger})
    : _logger = logger ?? const AppLogger(tag: 'LocationService');

  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      _logger.warning('Failed to check if location service is enabled: $e');
      return false;
    }
  }

  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      _logger.warning('Failed to check location permission: $e');
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      _logger.error('Failed to request location permission', e);
      return LocationPermission.denied;
    }
  }

  Future<LocationCoords?> getCurrentLocation() async {
    try {
      final enabled = await isServiceEnabled();
      if (!enabled) {
        _logger.warning('Location services are disabled');
        return null;
      }

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.warning('Location permissions are permanently denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationCoords(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        timestamp: position.timestamp,
      );
    } catch (e, st) {
      _logger.error('Error obtaining location', e, st);
      return null;
    }
  }

  Future<SubsystemStatus> checkHealth() async {
    try {
      final enabled = await isServiceEnabled();
      final permission = await checkPermission();

      if (!enabled) {
        return const SubsystemStatus(
          name: 'Location & GPS Service',
          status: ServiceStatus.disconnected,
          message: 'Device location service / GPS is disabled',
        );
      }

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return const SubsystemStatus(
            name: 'Location & GPS Service',
            status: ServiceStatus.connected,
            message: 'Location permission granted (GPS active)',
          );
        case LocationPermission.denied:
          return const SubsystemStatus(
            name: 'Location & GPS Service',
            status: ServiceStatus.unconfigured,
            message: 'Permission not yet granted by user',
          );
        case LocationPermission.deniedForever:
          return const SubsystemStatus(
            name: 'Location & GPS Service',
            status: ServiceStatus.disconnected,
            message: 'Permission permanently denied (Open app settings)',
          );
        case LocationPermission.unableToDetermine:
          return const SubsystemStatus(
            name: 'Location & GPS Service',
            status: ServiceStatus.unconfigured,
            message: 'Location permission undetermined',
          );
      }
    } catch (e) {
      return SubsystemStatus(
        name: 'Location & GPS Service',
        status: ServiceStatus.disconnected,
        message: 'Diagnostics failed: $e',
      );
    }
  }
}

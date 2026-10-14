import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_features/map_features.dart';
import '../../providers/shopkeeper_state_providers.dart';

enum UploadScreenState {
  initial,
  capturing,
  uploading,
  permissionDenied,
  locationOutsideRadius,
  cameraFailure,
  alreadyUploadedToday,
  success,
}

class UploadPhotoScreen extends ConsumerStatefulWidget {
  const UploadPhotoScreen({super.key});

  @override
  ConsumerState<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends ConsumerState<UploadPhotoScreen> {
  UploadScreenState _screenState = UploadScreenState.initial;
  String? _errorMessage;
  double? _measuredDistanceMeters;
  final double _maxGeofenceRadiusMeters = 50.0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  void _checkInitialStatus() async {
    final repo = ref.read(shopkeeperRepositoryProvider);
    final shop = ref.read(currentBoundShopProvider);
    final existing = await repo.getTodayUpload(shop.id);
    if (existing != null && mounted) {
      setState(() {
        _screenState = UploadScreenState.alreadyUploadedToday;
      });
    }
  }

  Future<void> _startCaptureFlow() async {
    setState(() {
      _screenState = UploadScreenState.capturing;
      _errorMessage = null;
    });

    final shop = ref.read(currentBoundShopProvider);
    final locationService = ref.read(locationServiceProvider);

    // 1. Obtain Foreground GPS Location
    final gps = await locationService.getCurrentLocation();
    if (gps == null) {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.permissionDenied;
          _errorMessage = 'Location permission and GPS service are required to verify shop geofence.';
        });
      }
      return;
    }

    final double captureLat = gps.latitude;
    final double captureLng = gps.longitude;

    // 2. Camera Capture (Gallery is strictly disabled!)
    XFile? capturedFile;
    try {
      capturedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      // Camera failure or platform issue
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.cameraFailure;
          _errorMessage = 'Camera capture failed: $e';
        });
      }
      return;
    }

    // In web/desktop or test environment if user cancelled camera:
    if (capturedFile == null) {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.cameraFailure;
          _errorMessage = 'Camera capture was cancelled or camera unavailable.';
        });
      }
      return;
    }

    // 3. Upload to Private Storage with Geofence Validation
    setState(() => _screenState = UploadScreenState.uploading);

    try {
      final repo = ref.read(shopkeeperRepositoryProvider);
      final upload = await repo.uploadDailyPhoto(
        shopId: shop.id,
        uploaderId: shop.ownerId,
        localPhotoPath: capturedFile.path,
        latitude: captureLat,
        longitude: captureLng,
        captureTime: DateTime.now(),
        maxGeofenceRadiusMeters: _maxGeofenceRadiusMeters,
      );

      ref.invalidate(todayUploadProvider);

      if (!mounted) return;
      setState(() => _screenState = UploadScreenState.success);

      // Show confirmation dialog with metadata
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 54),
          title: const Text("Today's Photo Uploaded!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photo for "${shop.shopName}" (Code: ${upload.shopCode}) has been verified and securely uploaded to private storage.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Business Date: ${upload.businessDate}',
                        style: const TextStyle(fontSize: 11)),
                    Text('• Capture Time: ${upload.captureTime.toLocal().toString().substring(11, 19)}',
                        style: const TextStyle(fontSize: 11)),
                    Text('• Geofence Distance: ${upload.geofenceDistanceMeters.toStringAsFixed(1)}m (Verified)',
                        style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                    const Text('• Retained on Device: Yes (Local copy preserved)',
                        style: TextStyle(fontSize: 11)),
                    const Text('• Server Private Storage: Auto-deletes at midnight IST',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'View Fullscreen Ad View',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/view-photo');
              },
            ),
          ],
        ),
      );
    } on LocationOutsideRadiusException catch (e) {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.locationOutsideRadius;
          _measuredDistanceMeters = e.distanceMeters;
          _errorMessage = e.message;
        });
      }
    } on AlreadyUploadedTodayException {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.alreadyUploadedToday;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.cameraFailure;
          _errorMessage = 'Upload failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(currentBoundShopProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Today's Shop Photo"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildStateContent(context, shop, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent(BuildContext context, dynamic shop, ThemeData theme) {
    switch (_screenState) {
      case UploadScreenState.initial:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, size: 54, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Capture Today's Shop Photo",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Shop: ${shop.shopName} (Code: ${shop.shopCode})',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),

              // Upload Rules Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mandatory Verification Rules:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    SizedBox(height: 6),
                    Text('1. Direct camera capture required (Gallery upload is disabled).',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700)),
                    Text('2. Foreground GPS location verified against shop geofence (Max 50m).',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700)),
                    Text('3. One photo per business day. Private server image expires at midnight IST.',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700)),
                    Text('4. Local photo is retained on your phone for records.',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700)),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Launch Camera & Verify GPS',
                icon: Icons.camera_alt_outlined,
                onPressed: _startCaptureFlow,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Mock Sandbox quick-test button (for web/emulator where real camera is absent)
              TextButton.icon(
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Simulate In-Geofence Camera Capture (Dev Test)',
                    style: TextStyle(fontSize: 11)),
                onPressed: () => _simulateCapture(isWithinGeofence: true),
              ),

              TextButton.icon(
                icon: const Icon(Icons.wrong_location_outlined, size: 16, color: AppColors.warning),
                label: const Text('Simulate Outside-Geofence Capture (Dev Test)',
                    style: TextStyle(fontSize: 11, color: AppColors.warning)),
                onPressed: () => _simulateCapture(isWithinGeofence: false),
              ),
            ],
          ),
        );

      case UploadScreenState.capturing:
      case UploadScreenState.uploading:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                _screenState == UploadScreenState.capturing
                    ? 'Acquiring GPS & Preparing Camera...'
                    : 'Validating Geofence & Uploading to Private Storage...',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case UploadScreenState.permissionDenied:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Permission Denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage ??
                    'Camera and location permissions are required to capture today\'s verified photo.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Retry Permissions',
                icon: Icons.refresh,
                onPressed: _startCaptureFlow,
              ),
            ],
          ),
        );

      case UploadScreenState.locationOutsideRadius:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wrong_location_rounded, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Location Outside Shop Radius',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your current GPS position is ${_measuredDistanceMeters?.toStringAsFixed(1) ?? "120"}m '
                'away from the registered shop location.\n\n'
                'Security Policy: To prevent fraud, daily photos must be taken within $_maxGeofenceRadiusMeters meters of your shop.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral800),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Stand Near Shop & Retry',
                icon: Icons.my_location,
                onPressed: _startCaptureFlow,
              ),
            ],
          ),
        );

      case UploadScreenState.cameraFailure:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.warning),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Camera Capture Incomplete',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage ?? 'Camera operation was not completed.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Try Again',
                icon: Icons.refresh,
                onPressed: _startCaptureFlow,
              ),
            ],
          ),
        );

      case UploadScreenState.alreadyUploadedToday:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, size: 64, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "Already Uploaded Today",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                "You have already captured and verified today's shop photo. "
                "Only one daily verification photo is allowed per business day.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: "View Fullscreen Photo",
                icon: Icons.fullscreen,
                onPressed: () => context.go('/view-photo'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        );

      case UploadScreenState.success:
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 64, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              const Text('Photo Successfully Verified & Uploaded!'),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'View in Fullscreen',
                onPressed: () => context.go('/view-photo'),
              ),
            ],
          ),
        );
    }
  }

  void _simulateCapture({required bool isWithinGeofence}) async {
    setState(() => _screenState = UploadScreenState.uploading);
    final shop = ref.read(currentBoundShopProvider);
    final repo = ref.read(shopkeeperRepositoryProvider);

    // If within geofence: use shop coordinates; if outside: shift by 200m
    final lat = isWithinGeofence ? shop.latitude : shop.latitude + 0.002;
    final lng = isWithinGeofence ? shop.longitude : shop.longitude + 0.002;

    try {
      await repo.uploadDailyPhoto(
        shopId: shop.id,
        uploaderId: shop.ownerId,
        localPhotoPath: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
        latitude: lat,
        longitude: lng,
        captureTime: DateTime.now(),
        maxGeofenceRadiusMeters: _maxGeofenceRadiusMeters,
      );

      ref.invalidate(todayUploadProvider);
      if (mounted) setState(() => _screenState = UploadScreenState.success);
    } on LocationOutsideRadiusException catch (e) {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.locationOutsideRadius;
          _measuredDistanceMeters = e.distanceMeters;
          _errorMessage = e.message;
        });
      }
    } on AlreadyUploadedTodayException {
      if (mounted) setState(() => _screenState = UploadScreenState.alreadyUploadedToday);
    } catch (e) {
      if (mounted) {
        setState(() {
          _screenState = UploadScreenState.cameraFailure;
          _errorMessage = 'Simulated capture failed: $e';
        });
      }
    }
  }
}

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_features/map_features.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);
    final locationHealthAsync = ref.watch(locationHealthCheckProvider);
    final currentPosAsync = ref.watch(userCurrentPositionProvider);

    return AppScaffold(
      title: AppStrings.get('map_view', lang: lang),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Map & Geospatial Shell',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            locationHealthAsync.when(
              data: (status) => AppHealthCard(
                title: status.name,
                status: status.status.label,
                message: status.message,
                icon: Icons.my_location_rounded,
              ),
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => Text('Location error: $e'),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppMapView(initialLatitude: 23.8103, initialLongitude: 90.4125),
            const SizedBox(height: AppSpacing.md),
            currentPosAsync.when(
              data: (pos) => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS Position',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      pos != null
                          ? 'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}\nAccuracy: ${pos.accuracy?.toStringAsFixed(1) ?? 'N/A'}m'
                          : 'Position unavailable (grant location permission on device)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/employee_state_providers.dart';

class OfflineDraftsScreen extends ConsumerWidget {
  const OfflineDraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(offlineDraftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Saved Drafts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(offlineDraftsProvider),
          ),
        ],
      ),
      body: draftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading drafts: $err'),
        ),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drafts_outlined, size: 64, color: AppColors.neutral400),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'No Offline Drafts Found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'When you save a draft while in the field, it will appear here.',
                    style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: drafts.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final draftId = draft['id'] as String? ?? 'draft-$index';
              final shopName = draft['shop_name'] as String? ?? 'Untitled Shop';
              final ownerName = draft['owner_name'] as String? ?? 'N/A';
              final phone = draft['phone_number'] as String? ?? 'N/A';
              final zoneName = draft['zone_name'] as String? ?? 'Assigned Zone';
              final categoryStr = draft['category'] as String? ?? 'other';
              final isAgreed = draft['is_agreed'] as bool? ?? true;
              final lat = (draft['latitude'] as num?)?.toDouble() ?? 22.5726;
              final lng = (draft['longitude'] as num?)?.toDouble() ?? 88.3639;
              final createdAt = draft['created_at'] as String? ?? '';
              final category = ShopCategory.fromString(categoryStr);

              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(category.icon, size: 20, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              shopName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        AppBadge(
                          label: isAgreed ? 'Agreed Draft' : 'Follow-up Draft',
                          variant: isAgreed ? AppBadgeVariant.success : AppBadgeVariant.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Zone: $zoneName • Category: ${category.displayName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
                    ),
                    Text(
                      'Owner: $ownerName • Phone: $phone',
                      style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        'Saved: ${createdAt.substring(0, 19).replaceAll("T", " ")}',
                        style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Resume & Register',
                            icon: Icons.edit_note,
                            onPressed: () {
                              context.push(
                                '/shop/add?zoneId=${draft['zone_id']}&zoneName=${Uri.encodeComponent(zoneName)}&lat=$lat&lng=$lng',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          tooltip: 'Delete Draft',
                          onPressed: () async {
                            final repo = ref.read(employeeRepositoryProvider);
                            await repo.deleteOfflineDraft(draftId);
                            ref.invalidate(offlineDraftsProvider);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

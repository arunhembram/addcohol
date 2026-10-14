import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/company_state_providers.dart';
import 'company_shop_detail_modal.dart';

class CompanyShopsListScreen extends ConsumerWidget {
  const CompanyShopsListScreen({super.key});

  static const List<String> categories = [
    'All',
    'Fast Food',
    'Bakery',
    'Pharmacy',
    'Grocery',
    'Tea Stall',
    'Chicken',
    'Saloon',
    'Clothing',
    'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(companyAuthProvider);
    final company = authState.company;
    final shopsAsync = ref.watch(companyAssignedShopsProvider);
    final zonesAsync = ref.watch(companyAssignedZonesProvider);
    final selectedZone = ref.watch(companySelectedZoneFilterProvider);
    final selectedCategory = ref.watch(companySelectedCategoryFilterProvider);
    final theme = Theme.of(context);

    final canViewDailyProof = company?.canViewDailyProof ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertising Locations (Shops)'),
        actions: [
          IconButton(
            tooltip: 'Refresh Shops',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(companyAssignedShopsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by shop name, code, or street...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: ref.watch(companySearchQueryProvider).isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => ref
                                .read(companySearchQueryProvider.notifier)
                                .state = '',
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(companySearchQueryProvider.notifier).state = val;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Zone Selector Filter
                zonesAsync.when(
                  data: (zones) {
                    if (zones.isEmpty) return const SizedBox.shrink();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Zone: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral700,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('All Zones'),
                            selected: selectedZone == null,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(companySelectedZoneFilterProvider.notifier).state = null;
                              }
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ...zones.map((z) => Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.xs),
                                child: ChoiceChip(
                                  label: Text(z.name),
                                  selected: selectedZone == z.id,
                                  onSelected: (selected) {
                                    ref.read(companySelectedZoneFilterProvider.notifier).state =
                                        selected ? z.id : null;
                                  },
                                ),
                              )),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          avatar: cat != 'All'
                              ? Icon(
                                  CompanyShopDetailModal.getCategoryIcon(cat),
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : CompanyShopDetailModal.getCategoryColor(cat),
                                )
                              : null,
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(companySelectedCategoryFilterProvider.notifier).state = cat;
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Privacy Assurance Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            color: AppColors.neutral100,
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Displaying only verified active & agreed partner shops inside assigned territories.',
                    style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                  ),
                ),
                if (!canViewDailyProof)
                  AppBadge(
                    label: 'Proof Hidden',
                    variant: AppBadgeVariant.neutral,
                  ),
              ],
            ),
          ),

          // Shops List
          Expanded(
            child: shopsAsync.when(
              data: (shops) {
                if (shops.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 64,
                            color: AppColors.neutral400,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No Agreed Shops Found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'No active agreed shops match the selected filters inside your assigned zones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.neutral600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: shops.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return _buildShopCard(context, shop, canViewDailyProof);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Unable to load shops',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(err.toString(), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(
    BuildContext context,
    CompanyVisibleShop shop,
    bool canViewDailyProof,
  ) {
    final catIcon = CompanyShopDetailModal.getCategoryIcon(shop.category);
    final catColor = CompanyShopDetailModal.getCategoryColor(shop.category);

    return InkWell(
      onTap: () => CompanyShopDetailModal.show(
        context,
        shop: shop,
        canViewDailyProof: canViewDailyProof,
      ),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.neutral200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon container
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: catColor.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(catIcon, color: catColor, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),

            // Shop Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shop.shopName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutral900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.neutral300),
                        ),
                        child: Text(
                          shop.shopCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutral800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 13, color: AppColors.neutral500),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          shop.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      AppBadge(
                        label: shop.category,
                        variant: AppBadgeVariant.neutral,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tv_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${shop.screenCount} Screen${shop.screenCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (canViewDailyProof && shop.hasTodayProof != null)
                        AppBadge(
                          label: shop.hasTodayProof! ? 'Proof Active' : 'Proof Pending',
                          variant: shop.hasTodayProof!
                              ? AppBadgeVariant.success
                              : AppBadgeVariant.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

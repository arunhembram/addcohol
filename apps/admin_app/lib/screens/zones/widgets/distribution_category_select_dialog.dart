import 'package:flutter/material.dart';
import 'package:domain_models/domain_models.dart';
import 'package:design_system/design_system.dart';

/// Interactive dialog for Admin to select which shop categories
/// participate in the pamphlet distribution mode for a specific zone.
class DistributionCategorySelectDialog extends StatefulWidget {
  final String zoneId;
  final String zoneName;
  final Set<String> initialCategories;
  final List<Shop> zoneShops;

  const DistributionCategorySelectDialog({
    super.key,
    required this.zoneId,
    required this.zoneName,
    required this.initialCategories,
    required this.zoneShops,
  });

  static Future<Set<String>?> show(
    BuildContext context, {
    required String zoneId,
    required String zoneName,
    required Set<String> initialCategories,
    required List<Shop> zoneShops,
  }) {
    return showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DistributionCategorySelectDialog(
        zoneId: zoneId,
        zoneName: zoneName,
        initialCategories: initialCategories,
        zoneShops: zoneShops,
      ),
    );
  }

  @override
  State<DistributionCategorySelectDialog> createState() =>
      _DistributionCategorySelectDialogState();
}

class _DistributionCategorySelectDialogState
    extends State<DistributionCategorySelectDialog> {
  late bool _selectAll;
  late Set<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategories.isEmpty ||
        widget.initialCategories.contains('All') ||
        widget.initialCategories.contains('all')) {
      _selectAll = true;
      _selectedCategories = ShopCategory.values.map((c) => c.displayName).toSet();
    } else {
      _selectAll = false;
      _selectedCategories = Set<String>.from(widget.initialCategories);
      if (_selectedCategories.length == ShopCategory.values.length) {
        _selectAll = true;
      }
    }
  }

  int _countMatchingShops() {
    return widget.zoneShops.where((shop) {
      if (shop.isFollowup) return false;
      if (_selectAll) return true;
      final cat = ShopCategory.fromString(shop.category);
      return _selectedCategories.contains(cat.displayName) ||
          _selectedCategories.contains(shop.category);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchingCount = _countMatchingShops();
    final nonFollowupTotal = widget.zoneShops.where((s) => !s.isFollowup).length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.category_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'সামগ্রী ও বিজ্ঞাপন বিতরণের ক্যাটাগরি',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.zoneName,
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'এই জোনে কোন কোন ক্যাটাগরির দোকানে সামগ্রী ও বিজ্ঞাপন বিতরণ করা হবে তা নির্বাচন করুন:',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.neutral700),
              ),
              const SizedBox(height: 12),

              // Match Count Preview Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: Color(0xFF2E7D32), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'টার্গেট দোকান সংখ্যা: $matchingCount / $nonFollowupTotal টি',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // "All Categories" Switch / Checkbox
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _selectAll = !_selectAll;
                    if (_selectAll) {
                      _selectedCategories =
                          ShopCategory.values.map((c) => c.displayName).toSet();
                    } else {
                      _selectedCategories.clear();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectAll
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectAll ? AppColors.primary : AppColors.neutral300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectAll,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _selectAll = val ?? false;
                            if (_selectAll) {
                              _selectedCategories =
                                  ShopCategory.values.map((c) => c.displayName).toSet();
                            } else {
                              _selectedCategories.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'সব ক্যাটাগরি (All Categories)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Individual Categories Grid / List
              ...ShopCategory.values.map((cat) {
                final isSelected = _selectedCategories.contains(cat.displayName);
                final catShopCount = widget.zoneShops.where((s) {
                  if (s.isFollowup) return false;
                  return ShopCategory.fromString(s.category) == cat;
                }).length;

                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.remove(cat.displayName);
                        _selectAll = false;
                      } else {
                        _selectedCategories.add(cat.displayName);
                        if (_selectedCategories.length == ShopCategory.values.length) {
                          _selectAll = true;
                        }
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedCategories.add(cat.displayName);
                                if (_selectedCategories.length ==
                                    ShopCategory.values.length) {
                                  _selectAll = true;
                                }
                              } else {
                                _selectedCategories.remove(cat.displayName);
                                _selectAll = false;
                              }
                            });
                          },
                        ),
                        Icon(cat.icon, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${cat.bengaliName} (${cat.displayName})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.neutral200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$catShopCount টি',
                            style: const TextStyle(fontSize: 11, color: AppColors.neutral700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('বাতিল (Cancel)'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _selectedCategories.isEmpty
              ? null
              : () {
                  final result = _selectAll ? <String>{'All'} : _selectedCategories;
                  Navigator.of(context).pop(result);
                },
          child: const Text('সংরক্ষণ করুন (Apply)'),
        ),
      ],
    );
  }
}

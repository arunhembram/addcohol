import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String category;

  const CategoryChip({super.key, required this.category});

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tea_stall':
        return Icons.coffee_rounded;
      case 'food_stall':
        return Icons.restaurant_rounded;
      case 'vegetable_shop':
        return Icons.eco_rounded;
      case 'fish_shop':
        return Icons.set_meal_rounded;
      case 'grocery_shop':
        return Icons.storefront_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'tea_stall':
        return const Color(0xFFB45309);
      case 'food_stall':
        return const Color(0xFFEA580C);
      case 'vegetable_shop':
        return const Color(0xFF16A34A);
      case 'fish_shop':
        return const Color(0xFF0284C7);
      case 'grocery_shop':
        return const Color(0xFF7C3AED);
      case 'pharmacy':
        return const Color(0xFFE11D48);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<AppLocaleProvider>(context);
    final icon = getCategoryIcon(category);
    final color = getCategoryColor(category);
    final label = localeProvider.t('cat_$category');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

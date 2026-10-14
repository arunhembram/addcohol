import 'package:flutter/material.dart';

enum ShopCategory {
  chicken('Chicken', 'চিকেন শপ', Icons.set_meal_outlined),
  fastFood('Fast Food', 'ফাস্ট ফুড', Icons.fastfood_outlined),
  grocery('Grocery', 'মুদি দোকান', Icons.local_grocery_store_outlined),
  saloon('Saloon', 'সেলুন / পার্লার', Icons.content_cut_outlined),
  pharmacy('Pharmacy', 'ওষুধের দোকান', Icons.local_pharmacy_outlined),
  teaStall('Tea Stall', 'চায়ের দোকান', Icons.emoji_food_beverage_outlined),
  bakery('Bakery', 'বেকারি ও কনফেকশনারি', Icons.bakery_dining_outlined),
  clothing('Clothing', 'পোশাকের দোকান', Icons.checkroom_outlined),
  other('Other', 'অন্যান্য', Icons.storefront_outlined);

  final String displayName;
  final String bengaliName;
  final IconData icon;

  const ShopCategory(this.displayName, this.bengaliName, this.icon);

  static ShopCategory fromString(String? val) {
    if (val == null) return ShopCategory.other;
    final normalized = val.trim().toLowerCase();
    for (final cat in ShopCategory.values) {
      if (cat.displayName.toLowerCase() == normalized ||
          cat.name.toLowerCase() == normalized) {
        return cat;
      }
    }
    if (normalized.contains('chicken') || normalized.contains('meat')) {
      return ShopCategory.chicken;
    }
    if (normalized.contains('food') || normalized.contains('burger')) {
      return ShopCategory.fastFood;
    }
    if (normalized.contains('grocery') || normalized.contains('ration')) {
      return ShopCategory.grocery;
    }
    if (normalized.contains('saloon') || normalized.contains('parlour') || normalized.contains('hair')) {
      return ShopCategory.saloon;
    }
    if (normalized.contains('pharmacy') || normalized.contains('medicine') || normalized.contains('chemist')) {
      return ShopCategory.pharmacy;
    }
    if (normalized.contains('tea') || normalized.contains('chai') || normalized.contains('cafe')) {
      return ShopCategory.teaStall;
    }
    if (normalized.contains('bakery') || normalized.contains('cake') || normalized.contains('biscuit')) {
      return ShopCategory.bakery;
    }
    if (normalized.contains('cloth') || normalized.contains('garment') || normalized.contains('textile')) {
      return ShopCategory.clothing;
    }
    return ShopCategory.other;
  }
}

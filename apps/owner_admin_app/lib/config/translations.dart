import 'package:flutter/material.dart';

class AppLocaleProvider extends ChangeNotifier {
  String _locale = 'bn'; // Default to Bengali as required

  String get locale => _locale;
  bool get isBengali => _locale == 'bn';

  void setLocale(String lang) {
    if (_locale != lang) {
      _locale = lang;
      notifyListeners();
    }
  }

  void toggleLocale() {
    _locale = _locale == 'bn' ? 'en' : 'bn';
    notifyListeners();
  }

  String t(String key) {
    return Translations.get(key, _locale);
  }
}

class Translations {
  static const Map<String, Map<String, String>> _strings = {
    // Brand & App
    'app_title': {'bn': 'অ্যাডপ্রুফ অ্যাডমিন ড্যাশবোর্ড', 'en': 'AdProof Owner Admin Dashboard'},
    'app_subtitle': {
      'bn': 'লোকেশন-ভিত্তিক বিজ্ঞাপন প্রমাণ ব্যবস্থাপনা প্ল্যাটফর্ম',
      'en': 'Location-Based Advertisement Proof Platform',
    },

    // Navigation
    'nav_dashboard': {'bn': 'ড্যাশবোর্ড', 'en': 'Dashboard'},
    'nav_zones': {'bn': 'জোনসমূহ', 'en': 'Zones'},
    'nav_shops': {'bn': 'দোকানসমূহ', 'en': 'Shops'},
    'nav_employees': {'bn': 'মাঠকর্মী', 'en': 'Employees'},
    'nav_companies': {'bn': 'কোম্পানিসমূহ', 'en': 'Companies'},
    'nav_assignments': {'bn': 'জোন বরাদ্দ', 'en': 'Zone Assignments'},
    'nav_live_map': {'bn': 'লাইভ ম্যাপ', 'en': 'Live Map'},
    'nav_upload_review': {'bn': 'প্রুফ রিভিউ', 'en': 'Upload Review'},
    'nav_issues': {'bn': 'সমস্যা রিপোর্ট', 'en': 'Issue Reports'},
    'nav_reports': {'bn': 'প্রতিবেদন ও কমপ্লায়েন্স', 'en': 'Compliance Reports'},
    'nav_audit_logs': {'bn': 'অডিট লগ', 'en': 'Audit Logs'},
    'nav_settings': {'bn': 'সেটিংস', 'en': 'Settings'},
    'nav_logout': {'bn': 'লগআউট', 'en': 'Logout'},

    // KPIs
    'kpi_total_zones': {'bn': 'মোট সক্রিয় জোন', 'en': 'Total Active Zones'},
    'kpi_total_shops': {'bn': 'মোট সক্রিয় দোকান', 'en': 'Total Active Shops'},
    'kpi_uploaded_today': {'bn': 'আজকে আপলোড সম্পন্ন', 'en': 'Uploaded Today'},
    'kpi_not_uploaded_today': {'bn': 'আজকে বাকি দোকান', 'en': 'Not Uploaded Today'},
    'kpi_verified_today': {'bn': 'যাচাইকৃত প্রুফ', 'en': 'Verified Today'},
    'kpi_rejected_today': {'bn': 'বাতিলকৃত প্রুফ', 'en': 'Rejected Proofs'},
    'kpi_pending_issues': {'bn': 'অমীমাংসিত সমস্যা', 'en': 'Pending Issues'},
    'kpi_compliance_rate': {'bn': 'সামগ্রিক কমপ্লায়েন্স হার', 'en': 'Overall Compliance'},

    // Actions & Buttons
    'btn_add_zone': {'bn': 'নতুন জোন তৈরি করুন', 'en': 'Create New Zone'},
    'btn_add_shop': {'bn': 'নতুন দোকান যোগ করুন', 'en': 'Add New Shop'},
    'btn_add_company': {'bn': 'নতুন কোম্পানি যোগ করুন', 'en': 'Add Company'},
    'btn_assign_zone': {'bn': 'কোম্পানিকে জোন বরাদ্দ দিন', 'en': 'Assign Zone to Company'},
    'btn_assign_employee': {'bn': 'মাঠকর্মী বরাদ্দ দিন', 'en': 'Assign Employee'},
    'btn_verify': {'bn': 'অনুমোদন করুন', 'en': 'Verify'},
    'btn_reject': {'bn': 'বাতিল করুন', 'en': 'Reject'},
    'btn_save': {'bn': 'সংরক্ষণ করুন', 'en': 'Save'},
    'btn_cancel': {'bn': 'বাতিল', 'en': 'Cancel'},
    'btn_refresh': {'bn': 'রিফ্রেশ', 'en': 'Refresh'},
    'btn_move_zone': {'bn': 'জোন স্থানান্তর', 'en': 'Move Zone'},
    'btn_archive': {'bn': 'আর্কাইভ করুন', 'en': 'Archive'},
    'btn_trigger_midnight': {'bn': 'মিডনাইট ক্লিনআপ চালান', 'en': 'Run Midnight Expiry'},

    // Statuses
    'status_verified': {'bn': 'অনুমোদিত', 'en': 'Verified'},
    'status_submitted': {'bn': 'পর্যালোচনাধীন', 'en': 'Submitted'},
    'status_rejected': {'bn': 'বাতিলকৃত', 'en': 'Rejected'},
    'status_not_uploaded': {'bn': 'আপলোড করা হয়নি', 'en': 'Not Uploaded'},
    'status_expired': {'bn': 'মেয়াদোত্তীর্ণ', 'en': 'Expired'},
    'status_active': {'bn': 'সক্রিয়', 'en': 'Active'},
    'status_inactive': {'bn': 'নিষ্ক্রিয়', 'en': 'Inactive'},
    'status_archived': {'bn': 'আর্কাইভকৃত', 'en': 'Archived'},

    // Shop Categories
    'cat_tea_stall': {'bn': 'চা স্টল', 'en': 'Tea Stall'},
    'cat_food_stall': {'bn': 'খাবারের দোকান', 'en': 'Food Stall'},
    'cat_vegetable_shop': {'bn': 'কাঁচাবাজার', 'en': 'Vegetable Shop'},
    'cat_fish_shop': {'bn': 'মাছের দোকান', 'en': 'Fish Shop'},
    'cat_grocery_shop': {'bn': 'মুদি দোকান', 'en': 'Grocery Shop'},
    'cat_pharmacy': {'bn': 'ফার্মেসি', 'en': 'Pharmacy'},
    'cat_other': {'bn': 'অন্যান্য', 'en': 'Other'},

    // Upload Modes
    'mode_merchant_self_upload': {'bn': 'মার্চেন্ট নিজে আপলোড', 'en': 'Merchant Self Upload'},
    'mode_employee_managed_upload': {
      'bn': 'মাঠকর্মী দ্বারা আপলোড',
      'en': 'Employee Managed Upload',
    },
    'mode_both': {'bn': 'মার্চেন্ট ও মাঠকর্মী উভয়ই', 'en': 'Both'},

    // Issue Types
    'issue_poster_damaged': {'bn': 'পোস্টার ক্ষতিগ্রস্ত', 'en': 'Poster Damaged'},
    'issue_qr_covered': {'bn': 'QR কোড ঢাকা পড়েছে', 'en': 'QR Covered'},
    'issue_wrong_advertisement': {'bn': 'ভুল বিজ্ঞাপন প্রদর্শিত', 'en': 'Wrong Advertisement'},
    'issue_cannot_upload': {'bn': 'আপলোড করা সম্ভব হচ্ছে না', 'en': 'Cannot Upload'},
    'issue_needs_visit': {'bn': 'পরিদর্শন প্রয়োজন', 'en': 'Needs Visit'},
    'issue_other': {'bn': 'অন্যান্য সমস্যা', 'en': 'Other'},

    // Messages
    'msg_connected': {'bn': 'লাইভ সার্ভার সংযুক্ত', 'en': 'Live Server Connected'},
    'msg_disconnected': {'bn': 'সংযোগ বিচ্ছিন্ন', 'en': 'Disconnected'},
    'msg_timezone_notice': {
      'bn': 'প্রতি মধ্যরাত ১২:০০ টায় (Asia/Dhaka) স্বয়ংক্রিয়ভাবে ছবি ডিলিট এবং রিসেট হয়।',
      'en': 'Photos are automatically deleted and daily states reset every midnight (Asia/Dhaka).',
    },
  };

  static String get(String key, String locale) {
    if (_strings.containsKey(key)) {
      final map = _strings[key]!;
      return map[locale] ?? map['bn'] ?? key;
    }
    return key;
  }
}

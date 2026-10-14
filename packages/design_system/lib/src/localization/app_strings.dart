enum AppLanguage {
  en('en', 'English'),
  bn('bn', 'বাংলা (Bengali)');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.en;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => AppLanguage.en,
    );
  }
}

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Shop Ad Platform',
      'system_health': 'System Health & Diagnostics',
      'health_summary': 'Subsystem Status Overview',
      'environment': 'Environment',
      'app_role': 'App Role',
      'status': 'Status',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'unconfigured': 'Not Configured',
      'checking': 'Checking...',
      'healthy': 'Healthy',
      'degraded': 'Degraded',
      'unhealthy': 'Unhealthy',
      'secure_storage': 'Secure Storage (Keystore)',
      'supabase_backend': 'Supabase Backend Cloud',
      'location_service': 'Location & GPS Subsystem',
      'camera_scanner': 'Camera & QR Scanner',
      'theme_mode': 'Theme Mode',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'language': 'Language',
      'refresh': 'Refresh Diagnostics',
      'retry': 'Retry',
      'dashboard': 'Dashboard',
      'map_view': 'Map & Geo-fence',
      'qr_features': 'QR Features',
      'qr_scanner': 'Scan QR Code',
      'qr_generator': 'Generate QR Code',
      'camera_ready': 'Camera Ready for Scanning',
      'location_permission_granted': 'Location Permission Granted',
      'location_permission_denied': 'Location Permission Denied',
      'error_title': 'Something went wrong',
      'error_subtitle': 'An unexpected issue occurred while processing your request.',
      'loading': 'Loading, please wait...',
      'active_devices': 'Active Display Screens',
      'campaigns': 'Ad Campaigns',
      'shops': 'Registered Shops',
      'revenue': 'Transactions & Settlement',
    },
    'bn': {
      'app_title': 'শপ অ্যাড প্ল্যাটফর্ম',
      'system_health': 'সিস্টেম স্বাস্থ্য ও ডায়াগনস্টিকস',
      'health_summary': 'সাব-সিস্টেম অবস্থা পর্যবেক্ষণ',
      'environment': 'পরিবেশ',
      'app_role': 'অ্যাপের ভূমিকা',
      'status': 'অবস্থা',
      'connected': 'সংযুক্ত',
      'disconnected': 'সংযোগ বিচ্ছিন্ন',
      'unconfigured': 'কনফিগার করা হয়নি',
      'checking': 'যাচাই করা হচ্ছে...',
      'healthy': 'কার্যকর ও সুস্থ',
      'degraded': 'আংশিক কার্যকর',
      'unhealthy': 'ত্রুটিযুক্ত',
      'secure_storage': 'সিকিউর স্টোরেজ (কিস্টোর)',
      'supabase_backend': 'সুপাবেস ব্যাকএন্ড ক্লাউড',
      'location_service': 'লোকেশন ও জিপিএস সাব-সিস্টেম',
      'camera_scanner': 'ক্যামেরা ও কিউআর স্ক্যানার',
      'theme_mode': 'থিম মোড',
      'dark_mode': 'ডার্ক মোড',
      'light_mode': 'লাইট মোড',
      'language': 'ভাষা',
      'refresh': 'পুনরায় যাচাই করুন',
      'retry': 'আবার চেষ্টা করুন',
      'dashboard': 'ড্যাশবোর্ড',
      'map_view': 'ম্যাপ ও জিও-ফেন্স',
      'qr_features': 'কিউআর ফিচার',
      'qr_scanner': 'কিউআর কোড স্ক্যান করুন',
      'qr_generator': 'কিউআর কোড তৈরি করুন',
      'camera_ready': 'স্ক্যান করার জন্য ক্যামেরা প্রস্তুত',
      'location_permission_granted': 'লোকেশন অনুমতি অনুমোদিত',
      'location_permission_denied': 'লোকেশন অনুমতি প্রত্যাখ্যাত',
      'error_title': 'একটি সমস্যা দেখা দিয়েছে',
      'error_subtitle': 'আপনার অনুরোধ প্রক্রিয়া করার সময় একটি অপ্রত্যাশিত সমস্যা হয়েছে।',
      'loading': 'লোড হচ্ছে, অনুগ্রহ করে অপেক্ষা করুন...',
      'active_devices': 'সক্রিয় ডিসপ্লে স্ক্রিন',
      'campaigns': 'বিজ্ঞাপন ক্যাম্পেইন',
      'shops': 'নিবন্ধিত দোকানসমূহ',
      'revenue': 'লেনদেন ও সেটেলমেন্ট',
    },
  };

  static String get(String key, {AppLanguage lang = AppLanguage.en}) {
    final values = _localizedValues[lang.code] ?? _localizedValues['en']!;
    return values[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

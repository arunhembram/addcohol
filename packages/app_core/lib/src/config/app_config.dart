import 'app_environment.dart';

/// Application configuration loaded from environment variables (--dart-define or .env files).
/// Sensitive values must NEVER be hardcoded.
class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String googleMapsApiKey;
  final String apiBaseUrl;
  final bool enableVerboseLogging;
  final int requestTimeoutMs;

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleMapsApiKey,
    required this.apiBaseUrl,
    this.enableVerboseLogging = true,
    this.requestTimeoutMs = 15000,
  });

  /// Factory to load from compile-time defines or runtime environment map.
  factory AppConfig.fromEnvironment({Map<String, String>? envOverrides, String? defaultAppName}) {
    String getVal(String key, String constVal, String defaultValue) {
      if (envOverrides != null && envOverrides.containsKey(key)) {
        final val = envOverrides[key]!;
        if (val.isNotEmpty) return val;
      }
      return constVal.isNotEmpty ? constVal : defaultValue;
    }

    final rawEnv = getVal(
      'APP_ENV',
      const String.fromEnvironment('APP_ENV'),
      'dev',
    );
    final environment = AppEnvironment.fromString(rawEnv);

    final appName = getVal(
      'APP_NAME',
      const String.fromEnvironment('APP_NAME'),
      defaultAppName ?? 'Shop Ad Platform (${environment.name.toUpperCase()})',
    );
    final supabaseUrl = getVal(
      'SUPABASE_URL',
      const String.fromEnvironment('SUPABASE_URL'),
      '',
    );
    final supabaseAnonKey = getVal(
      'SUPABASE_ANON_KEY',
      const String.fromEnvironment('SUPABASE_ANON_KEY'),
      '',
    );
    final googleMapsApiKey = getVal(
      'GOOGLE_MAPS_API_KEY',
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
      '',
    );
    final apiBaseUrl = getVal(
      'API_BASE_URL',
      const String.fromEnvironment('API_BASE_URL'),
      'https://api.shopad.local',
    );
    final verboseStr = getVal(
      'ENABLE_VERBOSE_LOGGING',
      const String.fromEnvironment('ENABLE_VERBOSE_LOGGING'),
      environment.isProd ? 'false' : 'true',
    );

    return AppConfig(
      environment: environment,
      appName: appName,
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: supabaseAnonKey.trim(),
      googleMapsApiKey: googleMapsApiKey.trim(),
      apiBaseUrl: apiBaseUrl.trim(),
      enableVerboseLogging: verboseStr.toLowerCase() == 'true',
    );
  }

  /// Whether Supabase configuration is valid and usable
  bool get isSupabaseConfigured {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return false;
    if (supabaseUrl.contains('your-project') || supabaseUrl.contains('example.com')) return false;
    return Uri.tryParse(supabaseUrl)?.hasScheme == true;
  }

  /// Whether Google Maps API key is provided
  bool get isGoogleMapsConfigured {
    if (googleMapsApiKey.isEmpty) return false;
    if (googleMapsApiKey.contains('AIzaSy_YOUR_KEY') || googleMapsApiKey.contains('placeholder')) {
      return false;
    }
    return true;
  }

  /// Validates configuration and returns non-fatal diagnostics
  List<String> validate() {
    final diagnostics = <String>[];
    if (supabaseUrl.isEmpty) {
      diagnostics.add('SUPABASE_URL is missing. Add to your .env file or --dart-define.');
    } else if (!isSupabaseConfigured) {
      diagnostics.add('SUPABASE_URL appears to be a placeholder: "$supabaseUrl"');
    }

    if (supabaseAnonKey.isEmpty) {
      diagnostics.add('SUPABASE_ANON_KEY is missing. Add to your .env file or --dart-define.');
    }

    if (googleMapsApiKey.isEmpty) {
      diagnostics.add('GOOGLE_MAPS_API_KEY is missing. Maps will operate in demo fallback mode.');
    }

    return diagnostics;
  }

  AppConfig copyWith({
    AppEnvironment? environment,
    String? appName,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? googleMapsApiKey,
    String? apiBaseUrl,
    bool? enableVerboseLogging,
    int? requestTimeoutMs,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      appName: appName ?? this.appName,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      googleMapsApiKey: googleMapsApiKey ?? this.googleMapsApiKey,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      enableVerboseLogging: enableVerboseLogging ?? this.enableVerboseLogging,
      requestTimeoutMs: requestTimeoutMs ?? this.requestTimeoutMs,
    );
  }
}

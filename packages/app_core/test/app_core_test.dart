import 'package:flutter_test/flutter_test.dart';
import 'package:app_core/app_core.dart';

void main() {
  group('AppEnvironment Tests', () {
    test('Environment parsing and defaults', () {
      expect(AppEnvironment.fromString('dev'), AppEnvironment.dev);
      expect(AppEnvironment.fromString('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromString('prod'), AppEnvironment.prod);
      expect(AppEnvironment.fromString('PRODUCTION'), AppEnvironment.prod);
      expect(AppEnvironment.fromString(null), AppEnvironment.dev);
      expect(AppEnvironment.fromString('invalid'), AppEnvironment.dev);
    });

    test('Environment booleans', () {
      expect(AppEnvironment.dev.isDev, isTrue);
      expect(AppEnvironment.staging.isStaging, isTrue);
      expect(AppEnvironment.prod.isProd, isTrue);
    });
  });

  group('AppConfig Tests', () {
    test('Loading from map overrides', () {
      final config = AppConfig.fromEnvironment(
        envOverrides: {
          'APP_ENV': 'staging',
          'APP_NAME': 'Staging Shop Platform',
          'SUPABASE_URL': 'https://xyzcompany.supabase.co',
          'SUPABASE_ANON_KEY': 'sample-anon-key-12345',
          'GOOGLE_MAPS_API_KEY': 'AIzaSyActualValidKey99',
        },
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.appName, 'Staging Shop Platform');
      expect(config.supabaseUrl, 'https://xyzcompany.supabase.co');
      expect(config.isSupabaseConfigured, isTrue);
      expect(config.isGoogleMapsConfigured, isTrue);
      expect(config.validate(), isEmpty);
    });

    test('Detecting placeholder and missing keys in validation', () {
      final config = AppConfig.fromEnvironment(
        envOverrides: {
          'APP_ENV': 'dev',
          'SUPABASE_URL': 'https://your-project.supabase.co',
          'SUPABASE_ANON_KEY': '',
          'GOOGLE_MAPS_API_KEY': 'AIzaSy_YOUR_KEY_HERE',
        },
      );

      expect(config.isSupabaseConfigured, isFalse);
      expect(config.isGoogleMapsConfigured, isFalse);

      final diagnostics = config.validate();
      expect(diagnostics.length, greaterThanOrEqualTo(2));
    });
  });

  group('AppException Tests', () {
    test('Exceptions hierarchy formatting', () {
      const ex = NetworkException('Connection timed out', code: 'CONN_TIMEOUT');
      expect(ex.message, 'Connection timed out');
      expect(ex.code, 'CONN_TIMEOUT');
      expect(ex.toString(), contains('NetworkException (CONN_TIMEOUT)'));
    });
  });
}

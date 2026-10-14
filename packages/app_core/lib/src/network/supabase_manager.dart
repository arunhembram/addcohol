import 'dart:async';
import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';

class SupabaseManager {
  final AppConfig config;
  final AppLogger _logger;
  bool _isInitialized = false;

  SupabaseManager({required this.config, AppLogger? logger})
    : _logger = logger ?? const AppLogger(tag: 'SupabaseManager');

  bool get isInitialized => _isInitialized;

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Safe initialization that prevents app crash when keys are dummy or missing
  Future<bool> initialize() async {
    if (!config.isSupabaseConfigured) {
      _logger.warning('Supabase is not properly configured. Check your .env file.');
      return false;
    }

    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(url: config.supabaseUrl, anonKey: config.supabaseAnonKey);
      _isInitialized = true;
      _logger.info('Supabase initialized successfully for ${config.environment.name}');
      return true;
    } catch (e, st) {
      _logger.error('Failed to initialize Supabase client', e, st);
      _isInitialized = false;
      return false;
    }
  }

  /// Probes Supabase health endpoint or REST ping
  Future<SubsystemStatus> checkHealth() async {
    if (!config.isSupabaseConfigured) {
      return const SubsystemStatus(
        name: 'Supabase Cloud',
        status: ServiceStatus.unconfigured,
        message: 'Credentials missing or set to placeholder in .env file',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final healthUri = Uri.parse('${config.supabaseUrl}/rest/v1/');
      final response = await http
          .get(
            healthUri,
            headers: {
              'apikey': config.supabaseAnonKey,
              'Authorization': 'Bearer ${config.supabaseAnonKey}',
            },
          )
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();

      // Supabase REST root typically returns 200 or 401 with valid JSON
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return SubsystemStatus(
          name: 'Supabase Cloud',
          status: ServiceStatus.connected,
          message: 'Connected (HTTP ${response.statusCode})',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return SubsystemStatus(
          name: 'Supabase Cloud',
          status: ServiceStatus.disconnected,
          message: 'Server returned HTTP ${response.statusCode}',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return SubsystemStatus(
        name: 'Supabase Cloud',
        status: ServiceStatus.disconnected,
        message: 'Ping failed: ${e.toString().split('\n').first}',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}

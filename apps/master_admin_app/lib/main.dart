import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load client configuration from compile-time / environment defines
  final config = AppConfig.fromEnvironment(defaultAppName: 'Master Admin (ShopAd)');

  // Initialize Supabase safely (non-fatal if keys are placeholder)
  final supabaseManager = SupabaseManager(config: config);
  await supabaseManager.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseManagerProvider.overrideWithValue(supabaseManager),
        currentAppRoleProvider.overrideWithValue(UserRole.masterAdmin),
      ],
      child: const MasterAdminApp(),
    ),
  );
}

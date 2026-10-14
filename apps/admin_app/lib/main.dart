import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment(defaultAppName: 'Admin App (ShopAd)');

  final supabaseManager = SupabaseManager(config: config);
  await supabaseManager.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseManagerProvider.overrideWithValue(supabaseManager),
        currentAppRoleProvider.overrideWithValue(UserRole.admin),
      ],
      child: const AdminApp(),
    ),
  );
}

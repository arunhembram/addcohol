import 'dart:async';
import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Non-blocking Firebase initialization to guarantee immediate web rendering
  unawaited(
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      debugPrint('[Firebase] Initialized successfully');
    }).catchError((e) {
      debugPrint('[Firebase] Initialization notice: $e');
    }),
  );

  final config = AppConfig.fromEnvironment(defaultAppName: 'Company & Advertiser (ShopAd)');

  final supabaseManager = SupabaseManager(config: config);
  try {
    await supabaseManager.initialize().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('[Supabase] Initialization notice: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseManagerProvider.overrideWithValue(supabaseManager),
        currentAppRoleProvider.overrideWithValue(UserRole.company),
      ],
      child: const CompanyApp(),
    ),
  );
}

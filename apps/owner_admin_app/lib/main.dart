import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/translations.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_data_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = ApiService();
  final wsService = WebSocketService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLocaleProvider()),
        Provider<ApiService>.value(value: apiService),
        Provider<WebSocketService>.value(value: wsService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProxyProvider<AuthProvider, AdminDataProvider>(
          create: (_) => AdminDataProvider(apiService, wsService),
          update: (_, auth, adminData) {
            if (auth.isAuthenticated) {
              apiService.setToken(auth.token);
              adminData?.fetchAll(silent: true);
            }
            return adminData!;
          },
        ),
      ],
      child: const AdProofOwnerApp(),
    ),
  );
}

class AdProofOwnerApp extends StatelessWidget {
  const AdProofOwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<AppLocaleProvider>(context);

    return MaterialApp(
      title: locale.t('app_title'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const MainLayoutScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

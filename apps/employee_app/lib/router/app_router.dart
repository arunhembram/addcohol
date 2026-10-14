import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/drafts/offline_drafts_screen.dart';
import '../screens/followups/followups_list_screen.dart';
import '../screens/health_screen.dart';
import '../screens/login/employee_login_screen.dart';
import '../screens/map/employee_zone_map_screen.dart';
import '../screens/qr_screen.dart';
import '../screens/shop/add_shop_screen.dart';
import '../screens/payment/employee_payment_flow_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const EmployeeLoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const EmployeeZoneMapScreen(),
    ),
    GoRoute(
      path: '/shop/add',
      builder: (context, state) {
        final zoneId = state.uri.queryParameters['zoneId'];
        final zoneName = state.uri.queryParameters['zoneName'];
        final latStr = state.uri.queryParameters['lat'];
        final lngStr = state.uri.queryParameters['lng'];
        final category = state.uri.queryParameters['category'];

        return AddShopScreen(
          zoneId: zoneId,
          zoneName: zoneName,
          latitude: latStr != null ? double.tryParse(latStr) : null,
          longitude: lngStr != null ? double.tryParse(lngStr) : null,
          initialCategory: category,
        );
      },
    ),
    GoRoute(
      path: '/followups',
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tabIndex = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
        return FollowupsListScreen(initialTab: tabIndex);
      },
    ),
    GoRoute(
      path: '/drafts',
      builder: (context, state) => const OfflineDraftsScreen(),
    ),
    GoRoute(
      path: '/health',
      builder: (context, state) => const AppHealthScreen(),
    ),
    GoRoute(
      path: '/payment/scan',
      builder: (context, state) => const EmployeePaymentFlowScreen(),
    ),
    GoRoute(
      path: '/qr',
      builder: (context, state) => const QrScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: AppErrorView(
      title: 'Page Not Found',
      message: 'The requested route "${state.uri.toString()}" could not be resolved.',
      retryLabel: 'Return to Zone Map',
      onRetry: () => context.go('/'),
    ),
  ),
);

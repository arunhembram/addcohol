import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/booking/company_ad_booking_screen.dart';
import '../screens/booking/company_slot_booking_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/health_screen.dart';
import '../screens/login/company_login_screen.dart';
import '../screens/landing/company_landing_screen.dart';
import '../screens/map/company_zones_map_screen.dart';
import '../screens/reports/company_reporting_screen.dart';
import '../screens/shops/company_shops_list_screen.dart';
import '../screens/zones/company_zone_summary_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CompanyLandingScreen(),
    ),
    GoRoute(
      path: '/landing',
      builder: (context, state) => const CompanyLandingScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const CompanyLoginScreen(),
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) => const CompanyZonesMapScreen(),
    ),
    GoRoute(
      path: '/book-ad-space',
      builder: (context, state) {
        final zone = state.extra is Zone ? state.extra as Zone : null;
        final zoneId = state.uri.queryParameters['zoneId'] ?? zone?.id;
        return CompanyAdBookingScreen(
          initialZone: zone,
          initialZoneId: zoneId,
        );
      },
    ),
    GoRoute(
      path: '/book-slots',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        if (args == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid slot booking request')),
          );
        }
        return CompanySlotBookingScreen(
          company: args['company'] as Company,
          zone: args['zone'] as Zone,
          businessType: args['businessType'] as String,
          adSize: args['adSize'] as String,
          sideOption: args['sideOption'] as String,
          pricePerLocation: args['pricePerLocation'] as double,
          eligibleCount: args['eligibleCount'] as int,
          baseWeeklyTotal: args['baseWeeklyTotal'] as double,
        );
      },
    ),
    GoRoute(
      path: '/shops',
      builder: (context, state) => const CompanyShopsListScreen(),
    ),
    GoRoute(
      path: '/summary',
      builder: (context, state) => const CompanyZoneSummaryScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const CompanyReportingScreen(),
    ),
    GoRoute(
      path: '/health',
      builder: (context, state) => const AppHealthScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: AppErrorView(
      title: 'Page Not Found',
      message: 'The requested route "${state.uri.toString()}" could not be resolved.',
      retryLabel: 'Return to Company Dashboard',
      onRetry: () => context.go('/'),
    ),
  ),
);

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/admin_directory_screen.dart';
import '../screens/assign_admin_zones_screen.dart';
import '../screens/audit_reporting_screen.dart';
import '../screens/company_management_screen.dart';
import '../screens/create_admin_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/distribution_catalog_screen.dart';
import '../screens/health_screen.dart';
import '../screens/login_screen.dart';
import '../screens/master_weekly_bookings_screen.dart';
import '../screens/master_zones_map_screen.dart';
import '../screens/zone_list_screen.dart';
import '../screens/zone_map_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/',
      builder: (context, state) => MasterZonesMapScreen(
        initialZoneId: state.uri.queryParameters['zoneId'],
      ),
    ),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/zones', builder: (context, state) => const ZoneListScreen()),
    GoRoute(
      path: '/zones/map',
      builder: (context, state) => MasterZonesMapScreen(
        initialZoneId: state.uri.queryParameters['zoneId'],
      ),
    ),
    GoRoute(
      path: '/zones/create',
      builder: (context, state) => ZoneMapScreen(
        initialCenterLat: double.tryParse(state.uri.queryParameters['lat'] ?? ''),
        initialCenterLng: double.tryParse(state.uri.queryParameters['lng'] ?? ''),
        initialZoom: double.tryParse(state.uri.queryParameters['zoom'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/zones/:id',
      builder: (context, state) => ZoneMapScreen(existingZoneId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/zones/:id/edit',
      builder: (context, state) => ZoneMapScreen(existingZoneId: state.pathParameters['id']),
    ),
    GoRoute(path: '/admins', builder: (context, state) => const AdminDirectoryScreen()),
    GoRoute(path: '/admins/create', builder: (context, state) => const CreateAdminScreen()),
    GoRoute(path: '/admins/assign', builder: (context, state) => const AssignAdminZonesScreen()),
    GoRoute(path: '/companies', builder: (context, state) => const CompanyManagementScreen()),
    GoRoute(path: '/distribution/materials', builder: (context, state) => const DistributionCatalogScreen()),
    GoRoute(
      path: '/bookings',
      builder: (context, state) => MasterWeeklyBookingsScreen(
        initialSlotId: state.uri.queryParameters['slotId'],
      ),
    ),
    GoRoute(path: '/audit', builder: (context, state) => const AuditReportingScreen()),
    GoRoute(path: '/health', builder: (context, state) => const AppHealthScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: AppErrorView(
      title: 'Page Not Found',
      message: 'The requested route "${state.uri.toString()}" could not be resolved.',
      retryLabel: 'Return to Dashboard',
      onRetry: () => context.go('/'),
    ),
  ),
);

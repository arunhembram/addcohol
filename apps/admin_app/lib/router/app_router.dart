import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/dashboard/admin_dashboard_screen.dart';
import '../screens/employees/assign_employee_zones_screen.dart';
import '../screens/employees/create_employee_screen.dart';
import '../screens/employees/employee_list_screen.dart';
import '../screens/health_screen.dart';
import '../screens/login/admin_login_screen.dart';
import '../screens/performance/employee_performance_screen.dart';
import '../screens/qr_screen.dart';
import '../screens/shops/shops_overview_screen.dart';
import '../screens/zones/controlled_zone_map_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/zones/:zoneId/map',
      builder: (context, state) => ControlledZoneMapScreen(
        zoneId: state.pathParameters['zoneId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/employees',
      builder: (context, state) => const EmployeeListScreen(),
    ),
    GoRoute(
      path: '/employees/create',
      builder: (context, state) => const CreateEmployeeScreen(),
    ),
    GoRoute(
      path: '/employees/:employeeId/assign-zones',
      builder: (context, state) => AssignEmployeeZonesScreen(
        employeeId: state.pathParameters['employeeId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/shops',
      builder: (context, state) => const ShopsOverviewScreen(),
    ),
    GoRoute(
      path: '/performance',
      builder: (context, state) => const EmployeePerformanceScreen(),
    ),
    GoRoute(
      path: '/health',
      builder: (context, state) => const AppHealthScreen(),
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
      retryLabel: 'Return Home',
      onRetry: () => context.go('/'),
    ),
  ),
);

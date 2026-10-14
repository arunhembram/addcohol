import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/dashboard/shopkeeper_dashboard_screen.dart';
import '../screens/health_screen.dart';
import '../screens/login/shopkeeper_login_screen.dart';
import '../screens/payments/payments_placeholder_screen.dart';
import '../screens/payments/accept_payment_screen.dart';
import '../screens/photo/fullscreen_photo_screen.dart';
import '../screens/photo/upload_photo_screen.dart';
import '../screens/profile/shopkeeper_profile_screen.dart';
import '../screens/qr_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const ShopkeeperLoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const ShopkeeperDashboardScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadPhotoScreen(),
    ),
    GoRoute(
      path: '/view-photo',
      builder: (context, state) => const FullscreenPhotoScreen(),
    ),
    GoRoute(
      path: '/payments',
      builder: (context, state) => const PaymentsPlaceholderScreen(),
    ),
    GoRoute(
      path: '/accept-payment',
      builder: (context, state) => const AcceptPaymentScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ShopkeeperProfileScreen(),
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

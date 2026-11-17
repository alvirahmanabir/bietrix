import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/features/admin/admin_shell.dart';
import 'package:jamcon/features/admin/screens/admin_coupons_screen.dart';
import 'package:jamcon/features/admin/screens/admin_customers_screen.dart';
import 'package:jamcon/features/admin/screens/admin_login_screen.dart';
import 'package:jamcon/features/admin/screens/admin_orders_screen.dart';
import 'package:jamcon/features/admin/screens/admin_packages_screen.dart';
import 'package:jamcon/features/admin/screens/admin_profile_screen.dart';
import 'package:jamcon/features/admin/screens/admin_revenue_screen.dart';
import 'package:jamcon/features/admin/screens/admin_services_screen.dart';
import 'package:jamcon/features/admin/screens/admin_support_screen.dart';
import 'package:jamcon/features/admin/screens/overview_screen.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/auth/presentation/auth_screens.dart';
import 'package:jamcon/features/customer/booking/booking_confirmation_screen.dart';
import 'package:jamcon/features/customer/booking/booking_flow_screen.dart';
import 'package:jamcon/features/customer/builder/builder_screen.dart';
import 'package:jamcon/features/customer/customer_shell.dart';
import 'package:jamcon/features/customer/home/home_screen.dart';
import 'package:jamcon/features/customer/orders/order_detail_screen.dart';
import 'package:jamcon/features/customer/orders/orders_screen.dart';
import 'package:jamcon/features/customer/packages/package_detail_screen.dart';
import 'package:jamcon/features/customer/packages/packages_screen.dart';
import 'package:jamcon/features/customer/packages/wishlist_screen.dart';
import 'package:jamcon/features/customer/profile/delete_account_screen.dart';
import 'package:jamcon/features/customer/profile/edit_profile_screen.dart';
import 'package:jamcon/features/customer/profile/profile_screen.dart';
import 'package:jamcon/features/customer/profile/support_screens.dart';

/// Route table + role-based guards. Customers can never open /admin/**, and each
/// admin section is additionally gated by the role's permission.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<Session?>(ref.read(sessionProvider));
  ref.listen<Session?>(sessionProvider, (_, next) => auth.value = next);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider), state.matchedLocation),
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Page not found'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/home'), child: const Text('Go home')),
        ]),
      ),
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/verify-otp', builder: (_, s) => VerifyOtpScreen(email: s.uri.queryParameters['email'] ?? '')),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // Customer shell (bottom navigation)
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/packages', builder: (_, s) => PackagesScreen(initialQuery: s.uri.queryParameters['q'] ?? '')),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),

      // Customer full-screen routes
      GoRoute(path: '/packages/:id', builder: (_, s) => PackageDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/builder', builder: (_, __) => const CustomBuilderScreen()),
      GoRoute(path: '/book', builder: (_, __) => const BookingFlowScreen()),
      GoRoute(path: '/book/confirmed/:id', builder: (_, s) => BookingConfirmationScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/orders/:id', builder: (_, s) => OrderDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactUsScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PolicyScreen(kind: PolicyKind.privacy)),
      GoRoute(path: '/terms', builder: (_, __) => const PolicyScreen(kind: PolicyKind.terms)),
      GoRoute(path: '/delete-account', builder: (_, __) => const DeleteAccountScreen()),

      // Admin
      GoRoute(path: '/admin/login', builder: (_, __) => const AdminLoginScreen()),
      ShellRoute(
        builder: (_, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/admin/overview', builder: (_, __) => const OverviewScreen()),
          GoRoute(path: '/admin/packages', builder: (_, __) => const AdminPackagesScreen()),
          GoRoute(path: '/admin/services', builder: (_, __) => const AdminServicesScreen()),
          GoRoute(path: '/admin/orders', builder: (_, __) => const AdminOrdersScreen()),
          GoRoute(path: '/admin/orders/:id', builder: (_, s) => AdminOrderDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/admin/customers', builder: (_, __) => const AdminCustomersScreen()),
          GoRoute(path: '/admin/customers/:id', builder: (_, s) => AdminCustomerDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/admin/coupons', builder: (_, __) => const AdminCouponsScreen()),
          GoRoute(path: '/admin/support', builder: (_, __) => const AdminSupportScreen()),
          GoRoute(path: '/admin/revenue', builder: (_, __) => const AdminRevenueScreen()),
          GoRoute(path: '/admin/profile', builder: (_, __) => const AdminProfileScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});

const _guestPaths = ['/welcome', '/login', '/register', '/verify-otp', '/forgot-password'];

/// Pure redirect logic (unit-testable).
String? redirectFor(Session? s, String loc) {
  if (loc == '/splash') return null;
  final inAdmin = loc.startsWith('/admin');
  final isGuestPath = _guestPaths.any((p) => loc.startsWith(p));
  if (s == null) {
    if (loc == '/admin/login') return null;
    if (inAdmin) return '/admin/login';
    return isGuestPath ? null : '/welcome';
  }
  if (s.isAdmin) {
    if (!inAdmin || loc == '/admin/login') return '/admin/overview';
    final need = permissionForPath(loc);
    if (need != null && !s.can(need)) return '/admin/overview';
    return null;
  }
  if (inAdmin) return '/home';
  if (isGuestPath) return '/home';
  return null;
}

Permission? permissionForPath(String loc) {
  if (loc.startsWith('/admin/packages')) return Permission.managePackages;
  if (loc.startsWith('/admin/services')) return Permission.manageServices;
  if (loc.startsWith('/admin/orders')) return Permission.manageOrders;
  if (loc.startsWith('/admin/customers')) return Permission.viewCustomers;
  if (loc.startsWith('/admin/coupons')) return Permission.manageCoupons;
  if (loc.startsWith('/admin/support')) return Permission.manageSupport;
  if (loc.startsWith('/admin/revenue')) return Permission.viewRevenue;
  return null;
}

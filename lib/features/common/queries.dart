import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/paginated.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/services/services.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';

// Shared read-side providers. Every one is backed by a service stream, so admin
// changes show up instantly on the customer side (and vice-versa).

final packagesProvider = StreamProvider<List<Package>>((ref) => ref.watch(packageServiceProvider).watchAll());
final servicesProvider = StreamProvider<List<Service>>((ref) => ref.watch(serviceManagementProvider).watchAll());
final couponsProvider = StreamProvider<List<Coupon>>((ref) => ref.watch(couponServiceProvider).watchAll());

final activePackagesProvider = Provider<AsyncValue<List<Package>>>(
  (ref) => ref.watch(packagesProvider).whenData((l) => l.where((p) => p.isActive).toList()),
);
final activeServicesProvider = Provider<AsyncValue<List<Service>>>(
  (ref) => ref.watch(servicesProvider).whenData((l) => l.where((s) => s.isActive).toList()),
);
final availableCouponsProvider = Provider<AsyncValue<List<Coupon>>>((ref) => ref.watch(couponsProvider).whenData((l) {
      final now = DateTime.now();
      return l.where((c) => c.isActive && !c.isExpired(now) && (c.usageLimit == 0 || c.usedCount < c.usageLimit)).toList();
    }));

final packageByIdProvider = Provider.family<AsyncValue<Package?>, String>(
  (ref, id) => ref.watch(packagesProvider).whenData((l) => l.firstWhereOrNull((p) => p.id == id)),
);

// Current customer
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null || s.isAdmin) return Stream.value(null);
  return ref.watch(userServiceProvider).watchUser(s.userId);
});

final myBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null) return Stream.value(const <Booking>[]);
  return ref.watch(bookingServiceProvider).watchCustomerBookings(s.userId);
});

final bookingByIdProvider = StreamProvider.family<Booking?, String>(
  (ref, id) => ref.watch(bookingServiceProvider).watchBooking(id),
);

final wishlistIdsProvider = StreamProvider<List<String>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null || s.isAdmin) return Stream.value(const <String>[]);
  return ref.watch(wishlistServiceProvider).watchIds(s.userId);
});

// Admin
final currentAdminProvider = StreamProvider<AdminUser?>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null || !s.isAdmin) return Stream.value(null);
  return ref.watch(adminServiceProvider).watchAdmin(s.userId);
});

final adminBookingsProvider = StreamProvider.family<Paginated<Booking>, BookingFilter>((ref, f) {
  final s = ref.watch(sessionProvider);
  if (s == null) return const Stream.empty();
  return ref.watch(bookingServiceProvider).watchAllBookings(f, s);
});

final dashboardProvider = StreamProvider<DashboardStats>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null) return const Stream.empty();
  return ref.watch(analyticsServiceProvider).watchDashboard(s);
});

final revenueProvider = StreamProvider<RevenueSummary>((ref) {
  final s = ref.watch(sessionProvider);
  if (s == null) return const Stream.empty();
  return ref.watch(analyticsServiceProvider).watchRevenue(s);
});

typedef CustomerQuery = ({String query, AccountStatus? status});
final customersProvider = StreamProvider.family<List<AppUser>, CustomerQuery>(
  (ref, q) => ref.watch(userServiceProvider).watchCustomers(query: q.query, status: q.status),
);

typedef SupportQuery = ({SupportCategory? category, SupportStatus? status});
final supportRequestsProvider = StreamProvider.family<List<SupportRequest>, SupportQuery>(
  (ref, q) => ref.watch(supportServiceProvider).watchAll(category: q.category, status: q.status),
);

final customerBookingsProvider = StreamProvider.family<List<Booking>, String>(
  (ref, id) => ref.watch(bookingServiceProvider).watchCustomerBookings(id),
);

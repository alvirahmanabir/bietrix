import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/core/storage/local_store.dart';
import 'package:jamcon/data/mock/mock_database.dart';
import 'package:jamcon/data/mock/mock_services.dart';
import 'package:jamcon/domain/services/services.dart';

/// The ONLY place that decides which implementation backs each service.
/// To go live: add `Api*Service` classes and return them when `Env.useMock` is false
/// (or simply replace the right-hand sides below). No UI code changes.

/// Overridden in main() with the opened store.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('localStoreProvider must be overridden'));

final mockDbProvider = Provider<MockDatabase>((ref) => MockDatabase.open(ref.watch(localStoreProvider)));

final authServiceProvider = Provider<AuthService>((ref) => MockAuthService(ref.watch(mockDbProvider)));
final userServiceProvider = Provider<UserService>((ref) => MockUserService(ref.watch(mockDbProvider)));
final packageServiceProvider = Provider<PackageService>((ref) => MockPackageService(ref.watch(mockDbProvider)));
final serviceManagementProvider = Provider<ServiceManagementService>((ref) => MockServiceManagementService(ref.watch(mockDbProvider)));
final bookingServiceProvider = Provider<BookingService>((ref) => MockBookingService(ref.watch(mockDbProvider)));
final couponServiceProvider = Provider<CouponService>((ref) => MockCouponService(ref.watch(mockDbProvider)));
final wishlistServiceProvider = Provider<WishlistService>((ref) => MockWishlistService(ref.watch(mockDbProvider)));
final paymentServiceProvider = Provider<PaymentService>((ref) => MockPaymentService());
final supportServiceProvider = Provider<SupportService>((ref) => MockSupportService(ref.watch(mockDbProvider)));
final adminServiceProvider = Provider<AdminService>((ref) => MockAdminService(ref.watch(mockDbProvider)));
final analyticsServiceProvider = Provider<AnalyticsService>((ref) => MockAnalyticsService(ref.watch(mockDbProvider)));

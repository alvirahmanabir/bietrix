import 'package:jamcon/core/utils/paginated.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/coupon_validator.dart';

// Service contracts. The UI only depends on these interfaces.
// `watch*` methods return streams so a real implementation can poll / use SSE / WebSockets
// (real-time order status updates); `Future` methods map to ordinary REST calls.
// Admin mutations take the acting [Session] — the backend must verify permissions itself.

abstract class AuthService {
  Session? restore();
  Future<Session> login({required String email, required String password, required bool asAdmin});
  Future<String> register({required String name, required String email, required String phone, required String password});
  Future<Session> verifyOtp({required String email, required String code});
  Future<void> resendOtp(String email);
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({required String email, required String code, required String newPassword});
  Future<void> logout();
}

abstract class UserService {
  Stream<AppUser?> watchUser(String id);
  Stream<List<AppUser>> watchCustomers({String query = '', AccountStatus? status});
  Future<AppUser> updateProfile(String id, {required String name, required String phone, required String address});
  Future<void> deleteAccount(String id);
}

abstract class PackageService {
  Stream<List<Package>> watchAll();
  Future<Package> save(Package p, Session actor); // empty id => create
  Future<void> delete(String id, Session actor);
}

abstract class ServiceManagementService {
  Stream<List<Service>> watchAll();
  Future<Service> save(Service s, Session actor);
  Future<void> delete(String id, Session actor);
}

class BookingFilter {
  const BookingFilter({this.query = '', this.status, this.eventDate, this.page = 1, this.pageSize = 20});
  final String query;
  final BookingStatus? status;
  final DateTime? eventDate;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is BookingFilter &&
      other.query == query &&
      other.status == status &&
      other.eventDate == eventDate &&
      other.page == page &&
      other.pageSize == pageSize;
  @override
  int get hashCode => Object.hash(query, status, eventDate, page, pageSize);
}

abstract class BookingService {
  Future<List<String>> freeSlots(DateTime date);
  Future<Set<DateTime>> fullyBookedDates();
  Future<Booking> create(BookingRequest request);
  Stream<Booking?> watchBooking(String id);
  Stream<List<Booking>> watchCustomerBookings(String customerId);
  Stream<Paginated<Booking>> watchAllBookings(BookingFilter filter, Session actor);
  Future<Booking> cancelByCustomer({required String bookingId, required String customerId, String? reason});
  Future<Booking> confirm(String bookingId, Session actor);
  Future<Booking> cancelByAdmin(String bookingId, Session actor, {String? reason});
  Future<Booking> complete(String bookingId, Session actor);
}

abstract class CouponService {
  Stream<List<Coupon>> watchAll();
  Future<CouponCheck> validate({required String code, required int subtotal, required String customerId});
  Future<Coupon> save(Coupon c, Session actor);
  Future<void> delete(String id, Session actor);
}

abstract class WishlistService {
  Stream<List<String>> watchIds(String userId);
  Future<bool> toggle(String userId, String packageId); // returns true when now in wishlist
}

class PaymentResult {
  const PaymentResult({required this.success, this.reference, required this.message});
  final bool success;
  final String? reference;
  final String message;
}

abstract class PaymentService {
  /// Simulated gateway. A real implementation creates a payment intent and
  /// redirects to / embeds the gateway; never handle raw card data in-app.
  Future<PaymentResult> charge({required int amount, required PaymentProvider provider, required String credential});
}

abstract class SupportService {
  Future<SupportRequest> submit(SupportRequest request);
  Stream<List<SupportRequest>> watchAll({SupportCategory? category, SupportStatus? status});
  Future<SupportRequest> updateStatus(String id, SupportStatus status, Session actor);
  Future<SupportRequest> addNote(String id, String note, Session actor);
}

abstract class AdminService {
  Stream<AdminUser?> watchAdmin(String id);
  Future<AdminUser> updateProfile(String id, {required String name, required String phone});
}

abstract class AnalyticsService {
  Stream<DashboardStats> watchDashboard(Session actor);
  Stream<RevenueSummary> watchRevenue(Session actor);
}

import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/user.dart';

class RevenuePoint {
  const RevenuePoint({required this.date, this.realized = 0, this.booked = 0});
  final DateTime date;
  final int realized; // completed orders
  final int booked; // confirmed, not yet completed
}

class RevenueSummary {
  const RevenueSummary({
    required this.realized,
    required this.bookedValue,
    required this.pendingValue,
    required this.countByStatus,
    required this.byDay,
    required this.byMonth,
    required this.byPackage,
    required this.ordersByPackage,
    required this.byPayment,
  });
  final int realized;
  final int bookedValue;
  final int pendingValue;
  final Map<BookingStatus, int> countByStatus;
  final List<RevenuePoint> byDay;
  final List<RevenuePoint> byMonth;
  final Map<String, int> byPackage; // realized revenue per package (desc)
  final Map<String, int> ordersByPackage; // non-cancelled order count (desc)
  final Map<PaymentMethod, int> byPayment; // realized revenue per method
  int get totalOrders => countByStatus.values.fold(0, (a, b) => a + b);
  int count(BookingStatus s) => countByStatus[s] ?? 0;
}

class DashboardStats {
  const DashboardStats({
    required this.revenue,
    required this.totalCustomers,
    required this.recentOrders,
    required this.recentCustomers,
  });
  final RevenueSummary revenue;
  final int totalCustomers;
  final List<Booking> recentOrders;
  final List<AppUser> recentCustomers;
}

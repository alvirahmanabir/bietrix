import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';

/// Pure analytics over bookings. Revenue recognition:
///  * realized  = Completed orders
///  * booked    = Confirmed orders (not yet completed)
///  * pending / cancelled are excluded from revenue.
/// A backend can replace this with an aggregate endpoint returning [RevenueSummary].
abstract final class RevenueCalculator {
  static RevenueSummary compute(List<Booking> bookings, {DateTime? now, int days = 14, int months = 6}) {
    final today = now ?? DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);

    final counts = <BookingStatus, int>{for (final s in BookingStatus.values) s: 0};
    var realized = 0, booked = 0, pending = 0;
    final byPackage = <String, int>{};
    final orders = <String, int>{};
    final byPayment = <PaymentMethod, int>{for (final m in PaymentMethod.values) m: 0};

    final dayMap = <DateTime, List<int>>{
      for (var i = days - 1; i >= 0; i--) d0.subtract(Duration(days: i)): [0, 0],
    };
    final monthMap = <DateTime, List<int>>{
      for (var i = months - 1; i >= 0; i--) DateTime(today.year, today.month - i, 1): [0, 0],
    };

    for (final b in bookings) {
      counts[b.status] = (counts[b.status] ?? 0) + 1;
      final amount = b.pricing.total;
      final day = DateTime(b.schedule.date.year, b.schedule.date.month, b.schedule.date.day);
      final month = DateTime(day.year, day.month, 1);
      switch (b.status) {
        case BookingStatus.completed:
          realized += amount;
          byPackage[b.packageName] = (byPackage[b.packageName] ?? 0) + amount;
          byPayment[b.payment.method] = (byPayment[b.payment.method] ?? 0) + amount;
          dayMap[day]?[0] += amount;
          monthMap[month]?[0] += amount;
        case BookingStatus.confirmed:
          booked += amount;
          dayMap[day]?[1] += amount;
          monthMap[month]?[1] += amount;
        case BookingStatus.pendingConfirmation:
          pending += amount;
        case BookingStatus.cancelledByCustomer:
        case BookingStatus.cancelledByAdmin:
          break;
      }
      if (!b.status.isCancelled) orders[b.packageName] = (orders[b.packageName] ?? 0) + 1;
    }

    Map<String, int> sorted(Map<String, int> m) =>
        Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    return RevenueSummary(
      realized: realized,
      bookedValue: booked,
      pendingValue: pending,
      countByStatus: counts,
      byDay: [for (final e in dayMap.entries) RevenuePoint(date: e.key, realized: e.value[0], booked: e.value[1])],
      byMonth: [for (final e in monthMap.entries) RevenuePoint(date: e.key, realized: e.value[0], booked: e.value[1])],
      byPackage: sorted(byPackage),
      ordersByPackage: sorted(orders),
      byPayment: byPayment,
    );
  }
}

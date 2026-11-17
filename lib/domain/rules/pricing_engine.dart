import 'dart:math';

import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';

/// Reusable pricing logic — UI never computes totals itself.
abstract final class PricingEngine {
  static int clampQty(Service s, int q) => max(1, min(q, s.maxQty));

  /// Builds a price snapshot for the selected services (serviceId -> qty).
  /// Unknown serviceIds are skipped; inactive ones are skipped unless [includeInactive].
  static List<BookingItem> snapshot(Map<String, int> selection, Iterable<Service> catalog, {bool includeInactive = false}) {
    final items = <BookingItem>[];
    for (final s in catalog) {
      final q = selection[s.id];
      if (q == null || q <= 0) continue;
      if (!s.isActive && !includeInactive) continue;
      items.add(BookingItem(serviceId: s.id, name: s.name, unitPrice: s.unitPrice, qty: clampQty(s, q), unitLabel: s.unitLabel));
    }
    return items;
  }

  static int subtotalOf(Iterable<BookingItem> items) => items.fold(0, (sum, i) => sum + i.lineTotal);

  static Pricing price({required int subtotal, int discount = 0}) {
    final d = max(0, min(discount, subtotal));
    return Pricing(subtotal: subtotal, discount: d, total: subtotal - d);
  }
}

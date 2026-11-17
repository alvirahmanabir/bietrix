import 'dart:math';

import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';

enum CouponError { notFound, inactive, expired, minNotMet, limitReached, userLimitReached }

class CouponCheck {
  const CouponCheck.ok(Coupon c, int d)
      : coupon = c,
        discount = d,
        error = null,
        message = null;
  const CouponCheck.fail(CouponError e, String m)
      : coupon = null,
        discount = 0,
        error = e,
        message = m;

  final Coupon? coupon;
  final int discount;
  final CouponError? error;
  final String? message;
  bool get isOk => coupon != null;
}

/// Single source of truth for coupon rules (used by customer UI and the booking service).
abstract final class CouponValidator {
  static CouponCheck validate({
    required String code,
    required Iterable<Coupon> coupons,
    required int subtotal,
    required DateTime now,
    int userUsage = 0,
  }) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return const CouponCheck.fail(CouponError.notFound, 'Enter a coupon code');
    Coupon? found;
    for (final x in coupons) {
      if (x.code.toUpperCase() == c) found = x;
    }
    if (found == null) return const CouponCheck.fail(CouponError.notFound, 'Invalid coupon code');
    if (!found.isActive) return const CouponCheck.fail(CouponError.inactive, 'This coupon is not active');
    if (found.isExpired(now)) return CouponCheck.fail(CouponError.expired, 'This coupon expired on ${Fmt.date(found.expiresAt)}');
    if (subtotal < found.minOrder) {
      return CouponCheck.fail(CouponError.minNotMet, 'Minimum order of ${Fmt.money(found.minOrder)} required');
    }
    if (found.usageLimit > 0 && found.usedCount >= found.usageLimit) {
      return const CouponCheck.fail(CouponError.limitReached, 'This coupon has reached its usage limit');
    }
    if (found.perUserLimit > 0 && userUsage >= found.perUserLimit) {
      return const CouponCheck.fail(CouponError.userLimitReached, 'You have already used this coupon');
    }
    return CouponCheck.ok(found, discountFor(found, subtotal));
  }

  static int discountFor(Coupon c, int subtotal) {
    var d = c.type == CouponType.percent ? subtotal * c.value ~/ 100 : c.value;
    if (c.type == CouponType.percent && c.maxDiscount != null && c.maxDiscount! > 0) d = min(d, c.maxDiscount!);
    return max(0, min(d, subtotal));
  }
}

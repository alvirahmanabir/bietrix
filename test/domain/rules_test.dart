import 'package:flutter_test/flutter_test.dart';

import 'package:jamcon/app/router/app_router.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/booking_policy.dart';
import 'package:jamcon/domain/rules/coupon_validator.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/domain/rules/pricing_engine.dart';
import 'package:jamcon/domain/rules/revenue_calculator.dart';

Booking _booking(BookingStatus s, {int total = 10000, PaymentMethod m = PaymentMethod.cashOnSite, DateTime? date}) => Booking(
      id: 'bk_1',
      code: 'BK-2026-00001',
      customerId: 'usr_1',
      packageName: 'Test Package',
      items: const [],
      schedule: EventSchedule(date: date ?? DateTime.now(), slot: '09:00 AM'),
      location: const EventLocation(division: 'Dhaka', district: 'Dhaka', area: 'A', detail: 'B'),
      contact: const ContactInfo(name: 'N', phone: '01712345678', email: 'e@e.com'),
      pricing: Pricing(subtotal: total, discount: 0, total: total),
      payment: Payment(method: m, status: PaymentStatus.pending, amount: total),
      status: s,
      history: const [],
      createdAt: DateTime.now(),
    );

void main() {
  group('PricingEngine', () {
    const svcs = [
      Service(id: 'a', category: 'x', name: 'A', description: '', unitPrice: 1000, maxQty: 5),
      Service(id: 'b', category: 'x', name: 'B', description: '', unitPrice: 2500),
      Service(id: 'c', category: 'x', name: 'C', description: '', unitPrice: 999, isActive: false),
    ];

    test('computes subtotal from quantities and clamps quantity to max', () {
      final items = PricingEngine.snapshot({'a': 3, 'b': 9}, svcs);
      expect(PricingEngine.subtotalOf(items), 3 * 1000 + 2500); // b clamped to maxQty 1
    });

    test('skips inactive and unknown services', () {
      final items = PricingEngine.snapshot({'c': 1, 'zzz': 2}, svcs);
      expect(items, isEmpty);
    });

    test('discount never exceeds subtotal', () {
      final p = PricingEngine.price(subtotal: 1000, discount: 5000);
      expect(p.discount, 1000);
      expect(p.total, 0);
    });
  });

  group('CouponValidator', () {
    final now = DateTime(2026, 6, 1);
    final coupons = [
      Coupon(id: '1', code: 'PCT', type: CouponType.percent, value: 10, maxDiscount: 500, minOrder: 1000, expiresAt: DateTime(2026, 12, 31)),
      Coupon(id: '2', code: 'FLAT', type: CouponType.fixed, value: 300, expiresAt: DateTime(2026, 12, 31)),
      Coupon(id: '3', code: 'OLD', type: CouponType.fixed, value: 300, expiresAt: DateTime(2026, 1, 1)),
      Coupon(id: '4', code: 'OFF', type: CouponType.fixed, value: 300, expiresAt: DateTime(2026, 12, 31), isActive: false),
      Coupon(id: '5', code: 'FULL', type: CouponType.fixed, value: 300, expiresAt: DateTime(2026, 12, 31), usageLimit: 2, usedCount: 2),
    ];
    CouponCheck v(String code, int subtotal, {int usage = 0}) => CouponValidator.validate(code: code, coupons: coupons, subtotal: subtotal, now: now, userUsage: usage);

    test('percent discount respects the cap', () => expect(v('pct', 10000).discount, 500));
    test('percent discount below cap', () => expect(v('PCT', 2000).discount, 200));
    test('fixed discount is clamped to subtotal', () => expect(v('FLAT', 100).discount, 100));
    test('unknown code', () => expect(v('NOPE', 5000).error, CouponError.notFound));
    test('expired', () => expect(v('OLD', 5000).error, CouponError.expired));
    test('inactive', () => expect(v('OFF', 5000).error, CouponError.inactive));
    test('minimum order', () => expect(v('PCT', 500).error, CouponError.minNotMet));
    test('usage limit', () => expect(v('FULL', 5000).error, CouponError.limitReached));
    test('per-user limit', () => expect(v('PCT', 5000, usage: 1).error, CouponError.userLimitReached));
  });

  group('BookingPolicy (cancellation rules)', () {
    final now = DateTime.now();

    test('customer can cancel a pending booking and cancellation details are recorded', () {
      final b = BookingPolicy.apply(_booking(BookingStatus.pendingConfirmation), BookingStatus.cancelledByCustomer, Actor.customer, now: now, by: 'Customer', reason: 'Changed plans');
      expect(b.status, BookingStatus.cancelledByCustomer);
      expect(b.cancellation!.cancelledBy, Actor.customer);
      expect(b.cancellation!.reason, 'Changed plans');
      expect(b.cancellation!.cancelledAt, now);
    });

    test('customer can NOT cancel a confirmed booking', () {
      expect(() => BookingPolicy.apply(_booking(BookingStatus.confirmed), BookingStatus.cancelledByCustomer, Actor.customer, now: now, by: 'Customer'), throwsA(isA<PolicyFailure>()));
      expect(BookingPolicy.canCustomerCancel(_booking(BookingStatus.confirmed)), isFalse);
    });

    test('customer cannot impersonate admin transitions', () {
      for (final to in [BookingStatus.confirmed, BookingStatus.cancelledByAdmin, BookingStatus.completed]) {
        expect(() => BookingPolicy.apply(_booking(BookingStatus.pendingConfirmation), to, Actor.customer, now: now, by: 'x'), throwsA(isA<PolicyFailure>()));
      }
    });

    test('admin can confirm pending, cancel pending, cancel confirmed, complete confirmed', () {
      expect(BookingPolicy.apply(_booking(BookingStatus.pendingConfirmation), BookingStatus.confirmed, Actor.admin, now: now, by: 'a').status, BookingStatus.confirmed);
      expect(BookingPolicy.apply(_booking(BookingStatus.pendingConfirmation), BookingStatus.cancelledByAdmin, Actor.admin, now: now, by: 'a').status, BookingStatus.cancelledByAdmin);
      final c = BookingPolicy.apply(_booking(BookingStatus.confirmed), BookingStatus.cancelledByAdmin, Actor.admin, now: now, by: 'a', reason: 'No staff');
      expect(c.cancellation!.cancelledBy, Actor.admin);
      expect(BookingPolicy.apply(_booking(BookingStatus.confirmed), BookingStatus.completed, Actor.admin, now: now, by: 'a').status, BookingStatus.completed);
    });

    test('terminal states cannot change', () {
      for (final s in [BookingStatus.cancelledByCustomer, BookingStatus.cancelledByAdmin, BookingStatus.completed]) {
        for (final to in BookingStatus.values) {
          expect(BookingPolicy.canTransition(Actor.admin, s, to), isFalse);
          expect(BookingPolicy.canTransition(Actor.customer, s, to), isFalse);
        }
      }
    });

    test('pending cannot jump straight to completed', () => expect(BookingPolicy.canAdminComplete(_booking(BookingStatus.pendingConfirmation)), isFalse));
  });

  group('RevenueCalculator', () {
    test('only completed counts as realized; confirmed is upcoming; cancelled excluded', () {
      final today = DateTime.now();
      final list = [
        _booking(BookingStatus.completed, total: 1000, date: today),
        _booking(BookingStatus.completed, total: 2000, m: PaymentMethod.online, date: today),
        _booking(BookingStatus.confirmed, total: 4000, date: today),
        _booking(BookingStatus.pendingConfirmation, total: 8000, date: today),
        _booking(BookingStatus.cancelledByAdmin, total: 16000, date: today),
      ];
      final r = RevenueCalculator.compute(list);
      expect(r.realized, 3000);
      expect(r.bookedValue, 4000);
      expect(r.pendingValue, 8000);
      expect(r.totalOrders, 5);
      expect(r.byPayment[PaymentMethod.online], 2000);
      expect(r.byDay.last.realized, 3000);
      expect(r.byPackage['Test Package'], 3000);
    });
  });

  group('Permissions & route guards', () {
    test('roles differ', () {
      expect(Permissions.has(AdminRole.customerSupport, Permission.manageOrders), isFalse);
      expect(Permissions.has(AdminRole.orderManager, Permission.manageOrders), isTrue);
      expect(Permissions.has(AdminRole.orderManager, Permission.managePackages), isFalse);
      expect(Permissions.has(AdminRole.admin, Permission.manageAdmins), isFalse);
      expect(Permissions.has(AdminRole.superAdmin, Permission.manageAdmins), isTrue);
    });

    const customer = Session(userId: 'u', name: 'C', email: 'c@c.com');
    const support = Session(userId: 'a', name: 'S', email: 's@s.com', role: AdminRole.customerSupport);

    test('guests are sent to welcome / admin login', () {
      expect(redirectFor(null, '/home'), '/welcome');
      expect(redirectFor(null, '/orders/1'), '/welcome');
      expect(redirectFor(null, '/admin/orders'), '/admin/login');
      expect(redirectFor(null, '/login'), isNull);
    });

    test('customers can never open admin routes', () {
      expect(redirectFor(customer, '/admin/overview'), '/home');
      expect(redirectFor(customer, '/login'), '/home');
      expect(redirectFor(customer, '/orders'), isNull);
    });

    test('admins are kept in /admin and limited by permission', () {
      expect(redirectFor(support, '/home'), '/admin/overview');
      expect(redirectFor(support, '/admin/orders'), '/admin/overview');
      expect(redirectFor(support, '/admin/support'), isNull);
    });
  });
}

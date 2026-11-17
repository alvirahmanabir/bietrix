import 'package:flutter_test/flutter_test.dart';

import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/storage/local_store.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/data/mock/mock_database.dart';
import 'package:jamcon/data/mock/mock_latency.dart';
import 'package:jamcon/data/mock/mock_services.dart';
import 'package:jamcon/data/mock/seed.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/services/services.dart';

void main() {
  late MockDatabase db;
  late MockBookingService bookings;
  late MockUserService users;
  late MockCouponService coupons;
  late MockPackageService packages;

  const admin = Session(userId: 'adm_2', name: 'Tanvir', email: 'admin@jamcon.app', role: AdminRole.admin);
  const support = Session(userId: 'adm_4', name: 'Sumaiya', email: 'support@jamcon.app', role: AdminRole.customerSupport);

  setUp(() {
    MockLatency.enabled = false;
    db = MockDatabase.open(LocalStore.memory());
    bookings = MockBookingService(db);
    users = MockUserService(db);
    coupons = MockCouponService(db);
    packages = MockPackageService(db);
  });

  Future<DateTime> freeDate() async {
    var d = dateOnly(DateTime.now()).add(const Duration(days: 100));
    while ((await bookings.freeSlots(d)).isEmpty) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  Future<BookingRequest> request({String? coupon, String pkg = 'pkg_portrait', int slot = 0}) async => BookingRequest(
        customerId: Seed.demoUserId,
        packageId: pkg,
        schedule: EventSchedule(date: await freeDate(), slot: EventSlots.all[slot]),
        location: const EventLocation(division: 'Dhaka', district: 'Dhaka', area: 'Dhanmondi', detail: 'House 1, Road 2'),
        contact: const ContactInfo(name: 'Demo', phone: '01712345678', email: 'ignored@x.com'),
        couponCode: coupon,
        paymentMethod: PaymentMethod.cashOnSite,
      );

  test('new bookings start as Pending Confirmation with server-side pricing', () async {
    final b = await bookings.create(await request());
    expect(b.status, BookingStatus.pendingConfirmation);
    expect(b.pricing.total, 12000);
    expect(b.contact.email, 'demo@jamcon.app'); // registered email, not the client-supplied one
    expect(b.items, isNotEmpty);
  });

  test('coupon is applied and validated by the same rules', () async {
    final b = await bookings.create(await request(coupon: 'welcome10'));
    expect(b.pricing.discount, 1200);
    expect(b.pricing.total, 10800);
    await expectLater(bookings.create(await request(coupon: 'EID25', slot: 2)), throwsA(isA<ValidationFailure>()));
    await expectLater(bookings.create(await request(coupon: 'WELCOME10', slot: 3)), throwsA(isA<ValidationFailure>())); // per-user limit
  });

  test('customer may cancel while pending, but not after admin confirms', () async {
    final b = await bookings.create(await request());
    await bookings.confirm(b.id, admin);
    await expectLater(bookings.cancelByCustomer(bookingId: b.id, customerId: Seed.demoUserId), throwsA(isA<PolicyFailure>()));
    final cancelled = await bookings.cancelByAdmin(b.id, admin, reason: 'Studio closed');
    expect(cancelled.status, BookingStatus.cancelledByAdmin);
    expect(cancelled.cancellation!.reason, 'Studio closed');

    final p = await bookings.create(await request(pkg: 'pkg_birthday'));
    final c = await bookings.cancelByCustomer(bookingId: p.id, customerId: Seed.demoUserId, reason: 'Oops');
    expect(c.status, BookingStatus.cancelledByCustomer);
    expect(c.cancellation!.cancelledBy, Actor.customer);
  });

  test("a customer cannot cancel someone else's booking", () async {
    final b = await bookings.create(await request());
    await expectLater(bookings.cancelByCustomer(bookingId: b.id, customerId: 'usr_other'), throwsA(isA<UnauthorizedFailure>()));
  });

  test('roles without permission cannot manage orders or packages', () async {
    final b = await bookings.create(await request());
    expect(() => bookings.confirm(b.id, support), throwsA(isA<UnauthorizedFailure>()));
    final p = db.packages.first;
    await expectLater(packages.save(p.copyWith(name: 'Hacked'), support), throwsA(isA<UnauthorizedFailure>()));
  });

  test('admin confirmation is visible to the customer stream', () async {
    final b = await bookings.create(await request());
    await bookings.confirm(b.id, admin);
    final mine = await bookings.watchCustomerBookings(Seed.demoUserId).first;
    expect(mine.firstWhere((x) => x.id == b.id).status, BookingStatus.confirmed);
  });

  test('custom package stores a price snapshot that survives later price edits', () async {
    final req = BookingRequest(
      customerId: Seed.demoUserId,
      items: const {'svc_photo': 2, 'svc_drone': 1},
      schedule: EventSchedule(date: await freeDate(), slot: EventSlots.all[1]),
      location: const EventLocation(division: 'Dhaka', district: 'Dhaka', area: 'A', detail: 'Venue address'),
      contact: const ContactInfo(name: 'Demo', phone: '01712345678', email: 'x@x.com'),
      paymentMethod: PaymentMethod.cashOnSite,
    );
    final b = await bookings.create(req);
    expect(b.packageId, isNull);
    expect(b.pricing.total, 2 * 3500 + 9000);
    final svc = db.services.firstWhere((s) => s.id == 'svc_photo');
    db.services = [for (final s in db.services) s.id == 'svc_photo' ? svc.copyWith(unitPrice: 99999) : s];
    final again = await bookings.watchBooking(b.id).first;
    expect(again!.pricing.total, 2 * 3500 + 9000);
  });

  test('double booking of a slot is rejected', () async {
    final req = await request();
    await bookings.create(req);
    await expectLater(bookings.create(req), throwsA(isA<ValidationFailure>()));
  });

  test('online payment must be confirmed before booking', () async {
    final base = await request();
    final req = BookingRequest(
      customerId: base.customerId,
      packageId: base.packageId,
      schedule: base.schedule,
      location: base.location,
      contact: base.contact,
      paymentMethod: PaymentMethod.online,
    );
    await expectLater(bookings.create(req), throwsA(isA<PolicyFailure>()));
  });

  test('profile update changes name/phone/address but never the email', () async {
    final u = await users.updateProfile(Seed.demoUserId, name: 'New Name', phone: '01811111111', address: 'Somewhere');
    expect(u.name, 'New Name');
    expect(u.email, 'demo@jamcon.app');
    await expectLater(users.updateProfile(Seed.demoUserId, name: '', phone: '01811111111', address: ''), throwsA(isA<ValidationFailure>()));
  });

  test('deleting an account removes profile data and cancels pending bookings', () async {
    final b = await bookings.create(await request());
    await users.deleteAccount(Seed.demoUserId);
    expect(db.users.any((u) => u.id == Seed.demoUserId), isFalse);
    expect(db.wishlists.containsKey(Seed.demoUserId), isFalse);
    expect(db.bookings.firstWhere((x) => x.id == b.id).status, BookingStatus.cancelledByCustomer);
  });

  test('a service used by a package cannot be deleted', () async {
    final svc = MockServiceManagementService(db);
    await expectLater(svc.delete('svc_photo', admin), throwsA(isA<PolicyFailure>()));
  });

  test('coupon service validate mirrors validator', () async {
    final ok = await coupons.validate(code: 'FLAT2000', subtotal: 25000, customerId: Seed.demoUserId);
    expect(ok.isOk, isTrue);
    expect(ok.discount, 2000);
    final bad = await coupons.validate(code: 'SOLDOUT', subtotal: 25000, customerId: Seed.demoUserId);
    expect(bad.isOk, isFalse);
  });

  test('database snapshot round-trips through JSON persistence', () async {
    final store = LocalStore.memory();
    final first = MockDatabase.open(store);
    await MockBookingService(first).create(await request());
    final reopened = MockDatabase.open(store);
    expect(reopened.bookings.length, first.bookings.length);
    expect(reopened.packages.length, first.packages.length);
  });
}

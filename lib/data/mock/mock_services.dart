import 'dart:convert';
import 'dart:math';

import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/utils/paginated.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/data/mock/mock_database.dart';
import 'package:jamcon/data/mock/mock_latency.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/booking_policy.dart';
import 'package:jamcon/domain/rules/coupon_validator.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/domain/rules/pricing_engine.dart';
import 'package:jamcon/domain/rules/revenue_calculator.dart';
import 'package:jamcon/domain/services/services.dart';

void _need(Session actor, Permission p) {
  if (!actor.can(p)) throw const UnauthorizedFailure('You do not have permission to perform this action.');
}

void _releaseCoupon(MockDatabase db, Booking b) {
  final code = b.coupon?.code;
  if (code == null) return;
  db.coupons = [
    for (final c in db.coupons)
      c.code == code && c.usedCount > 0 ? c.copyWith(usedCount: c.usedCount - 1) : c,
  ];
}

// ───────────────────────────── Auth ─────────────────────────────
class MockAuthService implements AuthService {
  MockAuthService(this._db);
  final MockDatabase _db;
  static const _sessionKey = 'session_v1';

  @override
  Session? restore() {
    final raw = _db.store.getString(_sessionKey);
    if (raw == null) return null;
    try {
      final s = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final exists = s.isAdmin ? _db.admins.any((a) => a.id == s.userId) : _db.users.any((u) => u.id == s.userId);
      return exists ? s : null;
    } catch (_) {
      return null;
    }
  }

  Session _start(Session s) {
    _db.store.setString(_sessionKey, jsonEncode(s.toJson()));
    return s;
  }

  @override
  Future<Session> login({required String email, required String password, required bool asAdmin}) async {
    await MockLatency.wait(400);
    final e = email.trim().toLowerCase();
    if (e.isEmpty || password.isEmpty) throw const ValidationFailure('Enter your email and password');
    if (asAdmin) {
      final a = _db.admins.firstWhereOrNull((x) => x.email == e);
      if (a == null || _db.passwords['admin:$e'] != password) throw const UnauthorizedFailure('Invalid admin credentials');
      return _start(Session(userId: a.id, name: a.name, email: a.email, role: a.role));
    }
    final u = _db.users.firstWhereOrNull((x) => x.email == e);
    if (u == null || _db.passwords[e] != password) throw const UnauthorizedFailure('Incorrect email or password');
    if (u.status == AccountStatus.suspended) throw const UnauthorizedFailure('Your account has been suspended. Please contact support.');
    return _start(Session(userId: u.id, name: u.name, email: u.email));
  }

  @override
  Future<String> register({required String name, required String email, required String phone, required String password}) async {
    await MockLatency.wait(400);
    final e = email.trim().toLowerCase();
    if (name.trim().isEmpty || Validators.email(e) != null || !Validators.isPhone(phone.trim()) || password.length < 6) {
      throw const ValidationFailure('Please check your details and try again');
    }
    if (_db.users.any((u) => u.email == e)) throw const ValidationFailure('An account with this email already exists');
    _db.pendingUsers[e] = AppUser(id: _db.nextId('usr'), name: name.trim(), email: e, phone: phone.trim(), createdAt: DateTime.now());
    _db.pendingPasswords[e] = password;
    _db.otps[e] = MockDatabase.demoOtp;
    return e;
  }

  @override
  Future<Session> verifyOtp({required String email, required String code}) async {
    await MockLatency.wait(350);
    final e = email.trim().toLowerCase();
    final pending = _db.pendingUsers[e];
    if (pending == null) throw const NotFoundFailure('No pending registration found. Please register again.');
    if (_db.otps[e] != code.trim()) throw const ValidationFailure('Invalid verification code');
    _db.users = [..._db.users, pending];
    _db.passwords[e] = _db.pendingPasswords[e] ?? '';
    _db.pendingUsers.remove(e);
    _db.pendingPasswords.remove(e);
    _db.otps.remove(e);
    _db.commit();
    return _start(Session(userId: pending.id, name: pending.name, email: pending.email));
  }

  @override
  Future<void> resendOtp(String email) async {
    await MockLatency.wait(300);
    _db.otps[email.trim().toLowerCase()] = MockDatabase.demoOtp;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await MockLatency.wait(400);
    final e = email.trim().toLowerCase();
    if (Validators.email(e) != null) throw const ValidationFailure('Enter a valid email address');
    if (_db.users.any((u) => u.email == e)) _db.otps[e] = MockDatabase.demoOtp; // never reveal whether the account exists
  }

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await MockLatency.wait(400);
    final e = email.trim().toLowerCase();
    if (newPassword.length < 6) throw const ValidationFailure('Use at least 6 characters');
    if (_db.otps[e] != code.trim() || !_db.users.any((u) => u.email == e)) throw const ValidationFailure('Invalid verification code');
    _db.passwords[e] = newPassword;
    _db.otps.remove(e);
    _db.commit();
  }

  @override
  Future<void> logout() async {
    _db.store.remove(_sessionKey);
  }
}

// ───────────────────────────── Users ─────────────────────────────
class MockUserService implements UserService {
  MockUserService(this._db);
  final MockDatabase _db;

  @override
  Stream<AppUser?> watchUser(String id) => _db.watch(() => _db.users.firstWhereOrNull((u) => u.id == id));

  @override
  Stream<List<AppUser>> watchCustomers({String query = '', AccountStatus? status}) => _db.watch(() {
        final q = query.trim().toLowerCase();
        final list = _db.users.where((u) {
          if (status != null && u.status != status) return false;
          if (q.isEmpty) return true;
          return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q) || u.phone.contains(q) || u.id.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Future<AppUser> updateProfile(String id, {required String name, required String phone, required String address}) async {
    await MockLatency.wait();
    if (name.trim().isEmpty) throw const ValidationFailure('Name is required');
    if (!Validators.isPhone(phone.trim())) throw const ValidationFailure('Enter a valid BD mobile number');
    final u = _db.users.firstWhereOrNull((x) => x.id == id);
    if (u == null) throw const NotFoundFailure('Account not found');
    final updated = u.copyWith(name: name.trim(), phone: phone.trim(), address: address.trim()); // email cannot change
    _db.users = [for (final x in _db.users) x.id == id ? updated : x];
    _db.commit();
    return updated;
  }

  @override
  Future<void> deleteAccount(String id) async {
    await MockLatency.wait(500);
    final u = _db.users.firstWhereOrNull((x) => x.id == id);
    if (u == null) throw const NotFoundFailure('Account not found');
    final now = DateTime.now();
    // Pending bookings are cancelled; other bookings stay as business records (a backend would anonymise them).
    _db.bookings = [
      for (final b in _db.bookings)
        if (b.customerId == id && BookingPolicy.canCustomerCancel(b))
          () {
            _releaseCoupon(_db, b);
            return BookingPolicy.apply(b, BookingStatus.cancelledByCustomer, Actor.customer, now: now, by: 'Customer', reason: 'Account deleted');
          }()
        else
          b,
    ];
    _db.users = _db.users.where((x) => x.id != id).toList();
    _db.passwords.remove(u.email);
    _db.wishlists = Map.of(_db.wishlists)..remove(id);
    _db.support = _db.support.where((s) => s.userId != id).toList();
    _db.commit();
  }
}

// ───────────────────────────── Catalog ─────────────────────────────
class MockPackageService implements PackageService {
  MockPackageService(this._db);
  final MockDatabase _db;

  @override
  Stream<List<Package>> watchAll() => _db.watch(() => List.of(_db.packages));

  @override
  Future<Package> save(Package p, Session actor) async {
    await MockLatency.wait();
    _need(actor, Permission.managePackages);
    if (p.name.trim().isEmpty) throw const ValidationFailure('Package name is required');
    if (p.description.trim().isEmpty) throw const ValidationFailure('Description is required');
    if (p.basePrice <= 0) throw const ValidationFailure('Price must be greater than zero');
    if (p.promoPrice != null && (p.promoPrice! <= 0 || p.promoPrice! >= p.basePrice)) {
      throw const ValidationFailure('Promotional price must be lower than the regular price');
    }
    if (p.serviceIds.isEmpty) throw const ValidationFailure('Select at least one included service');
    if (p.id.isEmpty) {
      final created = Package(
        id: _db.nextId('pkg'),
        name: p.name.trim(),
        description: p.description.trim(),
        imageKey: p.imageKey,
        serviceIds: p.serviceIds,
        basePrice: p.basePrice,
        promoPrice: p.promoPrice,
        isActive: p.isActive,
        isFeatured: p.isFeatured,
      );
      _db.packages = [..._db.packages, created];
      _db.commit();
      return created;
    }
    if (!_db.packages.any((x) => x.id == p.id)) throw const NotFoundFailure('Package not found');
    _db.packages = [for (final x in _db.packages) x.id == p.id ? p : x];
    _db.commit();
    return p;
  }

  @override
  Future<void> delete(String id, Session actor) async {
    await MockLatency.wait();
    _need(actor, Permission.managePackages);
    _db.packages = _db.packages.where((p) => p.id != id).toList();
    _db.wishlists = {for (final e in _db.wishlists.entries) e.key: e.value.where((x) => x != id).toList()};
    _db.commit();
  }
}

class MockServiceManagementService implements ServiceManagementService {
  MockServiceManagementService(this._db);
  final MockDatabase _db;

  @override
  Stream<List<Service>> watchAll() => _db.watch(() => List.of(_db.services));

  @override
  Future<Service> save(Service s, Session actor) async {
    await MockLatency.wait();
    _need(actor, Permission.manageServices);
    if (s.name.trim().isEmpty) throw const ValidationFailure('Service name is required');
    if (s.category.trim().isEmpty) throw const ValidationFailure('Category is required');
    if (s.unitPrice <= 0) throw const ValidationFailure('Price must be greater than zero');
    if (s.maxQty < 1) throw const ValidationFailure('Max quantity must be at least 1');
    if (s.id.isEmpty) {
      final created = Service(
        id: _db.nextId('svc'),
        category: s.category,
        name: s.name.trim(),
        description: s.description.trim(),
        imageKey: s.imageKey,
        unitPrice: s.unitPrice,
        unitLabel: s.unitLabel,
        maxQty: s.maxQty,
        isActive: s.isActive,
      );
      _db.services = [..._db.services, created];
      _db.commit();
      return created;
    }
    if (!_db.services.any((x) => x.id == s.id)) throw const NotFoundFailure('Service not found');
    _db.services = [for (final x in _db.services) x.id == s.id ? s : x];
    _db.commit();
    return s;
  }

  @override
  Future<void> delete(String id, Session actor) async {
    await MockLatency.wait();
    _need(actor, Permission.manageServices);
    final usedBy = _db.packages.firstWhereOrNull((p) => p.serviceIds.contains(id));
    if (usedBy != null) {
      throw PolicyFailure('This service is included in "${usedBy.name}". Remove it from the package first, or deactivate the service instead.');
    }
    _db.services = _db.services.where((s) => s.id != id).toList();
    _db.commit();
  }
}

// ───────────────────────────── Bookings ─────────────────────────────
class MockBookingService implements BookingService {
  MockBookingService(this._db);
  final MockDatabase _db;

  List<String> _free(DateTime date) {
    final d = dateOnly(date);
    if (d.isBefore(dateOnly(DateTime.now()))) return const [];
    final taken = _db.bookings.where((b) => !b.status.isCancelled && sameDay(b.schedule.date, d)).map((b) => b.schedule.slot).toSet();
    return EventSlots.all.where((s) => !taken.contains(s)).toList();
  }

  @override
  Future<List<String>> freeSlots(DateTime date) async {
    await MockLatency.wait(100);
    return _free(date);
  }

  @override
  Future<Set<DateTime>> fullyBookedDates() async {
    await MockLatency.wait(100);
    final byDay = <DateTime, Set<String>>{};
    for (final b in _db.bookings) {
      if (b.status.isCancelled) continue;
      (byDay[dateOnly(b.schedule.date)] ??= <String>{}).add(b.schedule.slot);
    }
    return {for (final e in byDay.entries) if (e.value.length >= EventSlots.all.length) e.key};
  }

  @override
  Future<Booking> create(BookingRequest r) async {
    await MockLatency.wait(500);
    final user = _db.users.firstWhereOrNull((u) => u.id == r.customerId);
    if (user == null) throw const UnauthorizedFailure('Please sign in again');
    if (user.status == AccountStatus.suspended) throw const UnauthorizedFailure('Your account is suspended');

    final c = r.contact;
    if (c.name.trim().isEmpty) throw const ValidationFailure('Customer name is required');
    if (!Validators.isPhone(c.phone.trim())) throw const ValidationFailure('Enter a valid contact number');
    if (c.altPhone.trim().isNotEmpty && !Validators.isPhone(c.altPhone.trim())) throw const ValidationFailure('Enter a valid alternative number');
    final l = r.location;
    if ([l.division, l.district, l.area, l.detail].any((s) => s.trim().isEmpty)) throw const ValidationFailure('Complete the event location');
    if (dateOnly(r.schedule.date).isBefore(dateOnly(DateTime.now()))) throw const ValidationFailure('Event date cannot be in the past');
    if (!_free(r.schedule.date).contains(r.schedule.slot)) {
      throw const ValidationFailure('This time slot is no longer available. Please choose another.');
    }

    // Pricing is always computed here, from the catalogue — never trusted from the client.
    List<BookingItem> items;
    int subtotal;
    String? pkgId;
    String pkgName;
    if (r.packageId != null) {
      final p = _db.packages.firstWhereOrNull((x) => x.id == r.packageId);
      if (p == null) throw const NotFoundFailure('Package not found');
      if (!p.isActive) throw const ValidationFailure('This package is no longer available');
      items = PricingEngine.snapshot({for (final id in p.serviceIds) id: 1}, _db.services, includeInactive: true);
      subtotal = p.price;
      pkgId = p.id;
      pkgName = p.name;
    } else {
      items = PricingEngine.snapshot(r.items, _db.services);
      if (items.isEmpty) throw const ValidationFailure('Select at least one service');
      subtotal = PricingEngine.subtotalOf(items);
      pkgName = 'Custom Package';
    }

    CouponSnapshot? cs;
    var discount = 0;
    final code = (r.couponCode ?? '').trim();
    if (code.isNotEmpty) {
      final usage = _db.bookings.where((b) => b.customerId == user.id && !b.status.isCancelled && b.coupon?.code.toUpperCase() == code.toUpperCase()).length;
      final check = CouponValidator.validate(code: code, coupons: _db.coupons, subtotal: subtotal, now: DateTime.now(), userUsage: usage);
      if (!check.isOk) throw ValidationFailure(check.message ?? 'Invalid coupon');
      discount = check.discount;
      final cp = check.coupon!;
      cs = CouponSnapshot(code: cp.code, type: cp.type, value: cp.value, discount: discount);
      _db.coupons = [for (final x in _db.coupons) x.id == cp.id ? x.copyWith(usedCount: x.usedCount + 1) : x];
    }
    final pricing = PricingEngine.price(subtotal: subtotal, discount: discount);

    if (r.paymentMethod == PaymentMethod.online && !r.paymentConfirmed) {
      throw const PolicyFailure('Online payment must be completed before the booking is placed.');
    }
    final now = DateTime.now();
    final id = _db.nextId('bk');
    final booking = Booking(
      id: id,
      code: 'BK-${now.year}-${_db.seq.toString().padLeft(5, '0')}',
      customerId: user.id,
      packageId: pkgId,
      packageName: pkgName,
      items: items,
      schedule: EventSchedule(date: dateOnly(r.schedule.date), slot: r.schedule.slot),
      location: l,
      contact: ContactInfo(name: c.name.trim(), phone: c.phone.trim(), email: user.email, altPhone: c.altPhone.trim(), notes: c.notes.trim()),
      coupon: cs,
      pricing: pricing,
      payment: Payment(
        method: r.paymentMethod,
        status: r.paymentMethod == PaymentMethod.online ? PaymentStatus.paid : PaymentStatus.pending,
        amount: pricing.total,
        provider: r.paymentProvider,
        reference: r.paymentReference,
      ),
      status: BookingStatus.pendingConfirmation, // always starts as Pending Confirmation
      history: [StatusEvent(status: BookingStatus.pendingConfirmation, at: now, by: 'Customer')],
      createdAt: now,
    );
    _db.bookings = [..._db.bookings, booking];
    _db.commit();
    return booking;
  }

  @override
  Stream<Booking?> watchBooking(String id) => _db.watch(() => _db.bookings.firstWhereOrNull((b) => b.id == id));

  @override
  Stream<List<Booking>> watchCustomerBookings(String customerId) => _db.watch(() {
        final l = _db.bookings.where((b) => b.customerId == customerId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return l;
      });

  @override
  Stream<Paginated<Booking>> watchAllBookings(BookingFilter f, Session actor) => _db.watch(() {
        _need(actor, Permission.manageOrders);
        final q = f.query.trim().toLowerCase();
        final all = _db.bookings.where((b) {
          if (f.status != null && b.status != f.status) return false;
          if (f.eventDate != null && !sameDay(b.schedule.date, f.eventDate!)) return false;
          if (q.isEmpty) return true;
          return b.code.toLowerCase().contains(q) || b.id.toLowerCase().contains(q) || b.contact.name.toLowerCase().contains(q) || b.packageName.toLowerCase().contains(q);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final end = min(all.length, f.page * f.pageSize);
        return Paginated(items: all.sublist(0, end), total: all.length, page: f.page, pageSize: f.pageSize);
      });

  Future<Booking> _transition(String id, BookingStatus to, Actor actor, {required String by, String? reason}) async {
    await MockLatency.wait();
    final b = _db.bookings.firstWhereOrNull((x) => x.id == id);
    if (b == null) throw const NotFoundFailure('Booking not found');
    var updated = BookingPolicy.apply(b, to, actor, now: DateTime.now(), by: by, reason: reason);
    if (to == BookingStatus.completed) updated = updated.copyWith(payment: updated.payment.copyWith(status: PaymentStatus.paid));
    if (to.isCancelled) _releaseCoupon(_db, b);
    _db.bookings = [for (final x in _db.bookings) x.id == id ? updated : x];
    _db.commit();
    return updated;
  }

  @override
  Future<Booking> cancelByCustomer({required String bookingId, required String customerId, String? reason}) async {
    final b = _db.bookings.firstWhereOrNull((x) => x.id == bookingId);
    if (b != null && b.customerId != customerId) throw const UnauthorizedFailure('This booking belongs to another account');
    return _transition(bookingId, BookingStatus.cancelledByCustomer, Actor.customer, by: 'Customer', reason: reason);
  }

  @override
  Future<Booking> confirm(String bookingId, Session actor) {
    _need(actor, Permission.manageOrders);
    return _transition(bookingId, BookingStatus.confirmed, Actor.admin, by: 'Admin: ${actor.name}');
  }

  @override
  Future<Booking> cancelByAdmin(String bookingId, Session actor, {String? reason}) {
    _need(actor, Permission.manageOrders);
    return _transition(bookingId, BookingStatus.cancelledByAdmin, Actor.admin, by: 'Admin: ${actor.name}', reason: reason);
  }

  @override
  Future<Booking> complete(String bookingId, Session actor) {
    _need(actor, Permission.manageOrders);
    return _transition(bookingId, BookingStatus.completed, Actor.admin, by: 'Admin: ${actor.name}');
  }
}

// ───────────────────────────── Coupons / wishlist / payments ─────────────────────────────
class MockCouponService implements CouponService {
  MockCouponService(this._db);
  final MockDatabase _db;

  @override
  Stream<List<Coupon>> watchAll() => _db.watch(() => List.of(_db.coupons));

  @override
  Future<CouponCheck> validate({required String code, required int subtotal, required String customerId}) async {
    await MockLatency.wait(250);
    final up = code.trim().toUpperCase();
    final usage = _db.bookings.where((b) => b.customerId == customerId && !b.status.isCancelled && b.coupon?.code.toUpperCase() == up).length;
    return CouponValidator.validate(code: code, coupons: _db.coupons, subtotal: subtotal, now: DateTime.now(), userUsage: usage);
  }

  @override
  Future<Coupon> save(Coupon c, Session actor) async {
    await MockLatency.wait();
    _need(actor, Permission.manageCoupons);
    final code = c.code.trim().toUpperCase();
    if (code.isEmpty) throw const ValidationFailure('Coupon code is required');
    if (_db.coupons.any((x) => x.code.toUpperCase() == code && x.id != c.id)) throw const ValidationFailure('A coupon with this code already exists');
    if (c.value <= 0) throw const ValidationFailure('Discount value must be greater than zero');
    if (c.type == CouponType.percent && c.value > 100) throw const ValidationFailure('Percentage cannot exceed 100');
    if (c.minOrder < 0 || c.usageLimit < 0 || c.perUserLimit < 0) throw const ValidationFailure('Limits cannot be negative');
    final clean = c.copyWith(code: code);
    if (c.id.isEmpty) {
      final created = Coupon(
        id: _db.nextId('cpn'),
        code: code,
        description: clean.description,
        type: clean.type,
        value: clean.value,
        maxDiscount: clean.maxDiscount,
        minOrder: clean.minOrder,
        expiresAt: clean.expiresAt,
        usageLimit: clean.usageLimit,
        perUserLimit: clean.perUserLimit,
        usedCount: 0,
        isActive: clean.isActive,
      );
      _db.coupons = [..._db.coupons, created];
      _db.commit();
      return created;
    }
    if (!_db.coupons.any((x) => x.id == c.id)) throw const NotFoundFailure('Coupon not found');
    _db.coupons = [for (final x in _db.coupons) x.id == c.id ? clean : x];
    _db.commit();
    return clean;
  }

  @override
  Future<void> delete(String id, Session actor) async {
    await MockLatency.wait();
    _need(actor, Permission.manageCoupons);
    _db.coupons = _db.coupons.where((c) => c.id != id).toList();
    _db.commit();
  }
}

class MockWishlistService implements WishlistService {
  MockWishlistService(this._db);
  final MockDatabase _db;

  @override
  Stream<List<String>> watchIds(String userId) => _db.watch(() => List<String>.of(_db.wishlists[userId] ?? const []));

  @override
  Future<bool> toggle(String userId, String packageId) async {
    // intentionally no latency: wishlist feels instant (optimistic).
    final cur = List<String>.of(_db.wishlists[userId] ?? const []);
    final had = cur.remove(packageId);
    if (!had) cur.insert(0, packageId);
    _db.wishlists = {..._db.wishlists, userId: cur};
    _db.commit();
    return !had;
  }
}

class MockPaymentService implements PaymentService {
  @override
  Future<PaymentResult> charge({required int amount, required PaymentProvider provider, required String credential}) async {
    await MockLatency.wait(1200);
    final c = credential.trim();
    if (c.length < 4) return const PaymentResult(success: false, message: 'Invalid PIN / card details.');
    if (c.endsWith('0000')) {
      return const PaymentResult(success: false, message: 'Payment declined by the provider (demo: credentials ending in 0000 always fail).');
    }
    return PaymentResult(success: true, reference: 'TXN${100000 + Random().nextInt(899999)}', message: 'Payment successful');
  }
}

// ───────────────────────────── Support / admin / analytics ─────────────────────────────
class MockSupportService implements SupportService {
  MockSupportService(this._db);
  final MockDatabase _db;

  @override
  Future<SupportRequest> submit(SupportRequest r) async {
    await MockLatency.wait(400);
    if (r.name.trim().isEmpty || Validators.email(r.email) != null || !Validators.isPhone(r.phone.trim())) {
      throw const ValidationFailure('Please check your contact details');
    }
    if (r.subject.trim().isEmpty) throw const ValidationFailure('Subject is required');
    if (r.message.trim().length < 10) throw const ValidationFailure('Please describe your request in a bit more detail');
    final created = SupportRequest(
      id: _db.nextId('sup'),
      userId: r.userId,
      name: r.name.trim(),
      email: r.email.trim(),
      phone: r.phone.trim(),
      category: r.category,
      subject: r.subject.trim(),
      message: r.message.trim(),
      createdAt: DateTime.now(),
    );
    _db.support = [..._db.support, created];
    _db.commit();
    return created;
  }

  @override
  Stream<List<SupportRequest>> watchAll({SupportCategory? category, SupportStatus? status}) => _db.watch(() {
        final l = _db.support.where((s) => (category == null || s.category == category) && (status == null || s.status == status)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return l;
      });

  Future<SupportRequest> _update(String id, SupportRequest Function(SupportRequest) fn) async {
    await MockLatency.wait(200);
    final cur = _db.support.firstWhereOrNull((x) => x.id == id);
    if (cur == null) throw const NotFoundFailure('Request not found');
    final updated = fn(cur);
    _db.support = [for (final x in _db.support) x.id == id ? updated : x];
    _db.commit();
    return updated;
  }

  @override
  Future<SupportRequest> updateStatus(String id, SupportStatus status, Session actor) {
    _need(actor, Permission.manageSupport);
    return _update(id, (s) => s.copyWith(status: status));
  }

  @override
  Future<SupportRequest> addNote(String id, String note, Session actor) {
    _need(actor, Permission.manageSupport);
    if (note.trim().isEmpty) throw const ValidationFailure('Write a note first');
    return _update(id, (s) => s.copyWith(notes: [...s.notes, '[${Fmt.dateTime(DateTime.now())} · ${actor.name}] ${note.trim()}']));
  }
}

class MockAdminService implements AdminService {
  MockAdminService(this._db);
  final MockDatabase _db;

  @override
  Stream<AdminUser?> watchAdmin(String id) => _db.watch(() => _db.admins.firstWhereOrNull((a) => a.id == id));

  @override
  Future<AdminUser> updateProfile(String id, {required String name, required String phone}) async {
    await MockLatency.wait();
    if (name.trim().isEmpty) throw const ValidationFailure('Name is required');
    if (phone.trim().isNotEmpty && !Validators.isPhone(phone.trim())) throw const ValidationFailure('Enter a valid phone number');
    final a = _db.admins.firstWhereOrNull((x) => x.id == id);
    if (a == null) throw const NotFoundFailure('Admin not found');
    final updated = a.copyWith(name: name.trim(), phone: phone.trim()); // email & role are not editable here
    _db.admins = [for (final x in _db.admins) x.id == id ? updated : x];
    _db.commit();
    return updated;
  }
}

class MockAnalyticsService implements AnalyticsService {
  MockAnalyticsService(this._db);
  final MockDatabase _db;

  @override
  Stream<DashboardStats> watchDashboard(Session actor) => _db.watch(() {
        _need(actor, Permission.viewDashboard);
        final orders = List<Booking>.of(_db.bookings)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final customers = List<AppUser>.of(_db.users)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return DashboardStats(
          revenue: RevenueCalculator.compute(_db.bookings),
          totalCustomers: _db.users.length,
          recentOrders: orders.take(6).toList(),
          recentCustomers: customers.take(5).toList(),
        );
      });

  @override
  Stream<RevenueSummary> watchRevenue(Session actor) => _db.watch(() {
        _need(actor, Permission.viewRevenue);
        return RevenueCalculator.compute(_db.bookings);
      });
}

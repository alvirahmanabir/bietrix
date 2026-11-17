import 'dart:math';

import 'package:jamcon/data/mock/mock_database.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/coupon_validator.dart';
import 'package:jamcon/domain/rules/pricing_engine.dart';

/// Realistic dummy data. Demo logins:
///   customer: demo@jamcon.app / demo123
///   admins  : super@ | admin@ | orders@ | support@jamcon.app / admin123
abstract final class Seed {
  static const demoUserId = 'usr_demo';

  static void populate(MockDatabase db) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rnd = Random(7);

    db.services = List.of(const [
      Service(id: 'svc_photo', category: 'Photography', name: 'Event Photography', description: 'Professional coverage of your event by a senior photographer. Includes basic colour grading.', imageKey: 'camera', unitPrice: 3500, unitLabel: 'hour', maxQty: 10),
      Service(id: 'svc_candid', category: 'Photography', name: 'Candid Portrait Session', description: 'Relaxed, natural portraits of the couple, family or individuals.', imageKey: 'portrait', unitPrice: 5000, unitLabel: 'session', maxQty: 3),
      Service(id: 'svc_second', category: 'Photography', name: 'Second Photographer', description: 'An additional photographer to capture every angle and moment.', imageKey: 'camera', unitPrice: 2000, unitLabel: 'hour', maxQty: 10),
      Service(id: 'svc_cine', category: 'Videography', name: 'Cinematic Videography', description: '4K cinematic coverage with stabilised gimbal shots.', imageKey: 'video', unitPrice: 6000, unitLabel: 'hour', maxQty: 10),
      Service(id: 'svc_highlight', category: 'Videography', name: 'Highlight Reel (3-5 min)', description: 'A beautifully edited highlight film with licensed music.', imageKey: 'video', unitPrice: 8000, unitLabel: 'film'),
      Service(id: 'svc_live', category: 'Videography', name: 'Live Streaming Setup', description: 'Multi-camera live stream for guests who cannot attend.', imageKey: 'live', unitPrice: 12000, unitLabel: 'event'),
      Service(id: 'svc_drone', category: 'Aerial', name: 'Drone Aerial Coverage', description: 'Licensed drone pilot for stunning aerial photos and video.', imageKey: 'drone', unitPrice: 9000, unitLabel: 'flight', maxQty: 2),
      Service(id: 'svc_edit', category: 'Editing & Prints', name: 'Professional Photo Editing', description: 'Advanced retouching and colour correction, per 50 photos.', imageKey: 'editing', unitPrice: 1500, unitLabel: 'pack of 50', maxQty: 20),
      Service(id: 'svc_album', category: 'Editing & Prints', name: 'Premium Photo Album', description: '30-page hand-bound album with a linen cover.', imageKey: 'album', unitPrice: 6500, unitLabel: 'album', maxQty: 5),
      Service(id: 'svc_print', category: 'Editing & Prints', name: 'Canvas Print (16x24)', description: 'Gallery-quality canvas print, ready to hang.', imageKey: 'album', unitPrice: 2800, unitLabel: 'print', maxQty: 10),
      Service(id: 'svc_lights', category: 'Add-ons', name: 'Studio Lighting Kit', description: 'Portable studio lighting for flawless indoor shots.', imageKey: 'studio', unitPrice: 4000, unitLabel: 'setup'),
      Service(id: 'svc_express', category: 'Add-ons', name: 'Express Delivery (48h)', description: 'Edited files delivered within 48 hours. Currently unavailable.', imageKey: 'editing', unitPrice: 3000, unitLabel: 'event', isActive: false),
    ]);

    db.packages = List.of(const [
      Package(id: 'pkg_wedding', name: 'Wedding Signature', description: 'Our flagship full-day wedding package: two photographers, cinematic film, drone coverage and a premium album.', imageKey: 'wedding', serviceIds: ['svc_photo', 'svc_second', 'svc_cine', 'svc_highlight', 'svc_drone', 'svc_album', 'svc_edit'], basePrice: 85000, promoPrice: 74999, isFeatured: true),
      Package(id: 'pkg_corporate', name: 'Corporate Event Pro', description: 'Conferences, launches and seminars covered end-to-end with photo, video and live streaming.', imageKey: 'corporate', serviceIds: ['svc_photo', 'svc_cine', 'svc_live', 'svc_edit'], basePrice: 48000, promoPrice: 42000, isFeatured: true),
      Package(id: 'pkg_portrait', name: 'Portrait Studio Session', description: 'A relaxed studio session with professional lighting, retouching and a framed print.', imageKey: 'portrait', serviceIds: ['svc_candid', 'svc_lights', 'svc_edit', 'svc_print'], basePrice: 12000, isFeatured: true),
      Package(id: 'pkg_birthday', name: 'Birthday Bash', description: 'Capture every smile: photo coverage, a highlight reel and edited photos.', imageKey: 'birthday', serviceIds: ['svc_photo', 'svc_highlight', 'svc_edit'], basePrice: 22000),
      Package(id: 'pkg_holud', name: 'Holud & Mehendi Special', description: 'Colourful pre-wedding ceremonies covered with two photographers and a highlight film.', imageKey: 'festival', serviceIds: ['svc_photo', 'svc_second', 'svc_candid', 'svc_highlight', 'svc_edit'], basePrice: 38000, promoPrice: 34500),
      Package(id: 'pkg_festival', name: 'Seasonal Festival Pack', description: 'Limited seasonal offering. Currently inactive.', imageKey: 'festival', serviceIds: ['svc_photo', 'svc_edit'], basePrice: 15000, isActive: false),
    ]);

    db.coupons = [
      Coupon(id: 'cpn_1', code: 'WELCOME10', description: '10% off your first booking (max ৳3,000)', type: CouponType.percent, value: 10, maxDiscount: 3000, minOrder: 10000, expiresAt: today.add(const Duration(days: 120)), usageLimit: 500, perUserLimit: 1, usedCount: 18),
      Coupon(id: 'cpn_2', code: 'FLAT2000', description: '৳2,000 off orders above ৳20,000', type: CouponType.fixed, value: 2000, minOrder: 20000, expiresAt: today.add(const Duration(days: 60)), usageLimit: 200, perUserLimit: 3, usedCount: 9),
      Coupon(id: 'cpn_3', code: 'VIP5000', description: '৳5,000 off orders above ৳50,000', type: CouponType.fixed, value: 5000, minOrder: 50000, expiresAt: today.add(const Duration(days: 90)), usageLimit: 100, perUserLimit: 2, usedCount: 4),
      Coupon(id: 'cpn_4', code: 'EID25', description: 'Eid special - 25% off (expired)', type: CouponType.percent, value: 25, maxDiscount: 8000, minOrder: 15000, expiresAt: today.subtract(const Duration(days: 45)), usageLimit: 300, perUserLimit: 1, usedCount: 112),
      Coupon(id: 'cpn_5', code: 'SOLDOUT', description: 'Flash deal - fully redeemed', type: CouponType.percent, value: 15, minOrder: 5000, expiresAt: today.add(const Duration(days: 30)), usageLimit: 10, perUserLimit: 1, usedCount: 10),
      Coupon(id: 'cpn_6', code: 'PAUSED', description: 'Paused campaign (inactive)', type: CouponType.fixed, value: 1000, minOrder: 0, expiresAt: today.add(const Duration(days: 30)), isActive: false),
    ];

    db.admins = List.of(const [
      AdminUser(id: 'adm_1', name: 'Nadia Rahman', email: 'super@jamcon.app', phone: '01711000001', role: AdminRole.superAdmin),
      AdminUser(id: 'adm_2', name: 'Tanvir Ahmed', email: 'admin@jamcon.app', phone: '01711000002', role: AdminRole.admin),
      AdminUser(id: 'adm_3', name: 'Farhan Kabir', email: 'orders@jamcon.app', phone: '01711000003', role: AdminRole.orderManager),
      AdminUser(id: 'adm_4', name: 'Sumaiya Islam', email: 'support@jamcon.app', phone: '01711000004', role: AdminRole.customerSupport),
    ]);
    for (final a in db.admins) {
      db.passwords['admin:${a.email}'] = 'admin123';
    }

    // Customers
    const first = ['Rafiq', 'Anika', 'Tasnim', 'Imran', 'Nusrat', 'Sabbir', 'Mehjabin', 'Arif', 'Lamia', 'Shuvo', 'Farzana', 'Rony', 'Maliha', 'Kamrul', 'Sadia', 'Jahid', 'Tania', 'Mahin', 'Ishrat', 'Zubair', 'Rima', 'Fahim', 'Priya', 'Asif'];
    const last = ['Hossain', 'Chowdhury', 'Akter', 'Rahman', 'Islam', 'Khan', 'Sultana', 'Uddin', 'Sarker', 'Ahmed'];
    db.users = [
      AppUser(id: demoUserId, name: 'Demo Customer', email: 'demo@jamcon.app', phone: '01712345678', address: 'House 12, Road 5, Dhanmondi, Dhaka', createdAt: today.subtract(const Duration(days: 200))),
    ];
    db.passwords['demo@jamcon.app'] = 'demo123';
    for (var i = 0; i < first.length; i++) {
      final n = '${first[i]} ${last[rnd.nextInt(last.length)]}';
      final email = '${first[i].toLowerCase()}${i + 1}@mail.com';
      db.users.add(AppUser(
        id: db.nextId('usr'),
        name: n,
        email: email,
        phone: '017${(10000000 + rnd.nextInt(89999999))}',
        address: 'Dhaka, Bangladesh',
        status: i == 5 ? AccountStatus.suspended : AccountStatus.active,
        createdAt: today.subtract(Duration(days: 3 + rnd.nextInt(190)), ),
      ));
      db.passwords[email] = 'pass1234';
    }

    // Bookings
    final used = <String>{};
    final activePkgs = db.packages.where((p) => p.isActive).toList();
    final activeSvcs = db.services.where((s) => s.isActive).toList();
    final welcome = db.coupons.first;

    Booking make(AppUser u, DateTime event, String slot, BookingStatus status, {int? pkgIndex}) {
      final custom = pkgIndex == null && rnd.nextInt(3) == 0;
      List<BookingItem> items;
      int subtotal;
      String? pkgId;
      String pkgName;
      if (!custom) {
        final p = activePkgs[pkgIndex ?? rnd.nextInt(activePkgs.length)];
        items = PricingEngine.snapshot({for (final id in p.serviceIds) id: 1}, db.services, includeInactive: true);
        subtotal = p.price;
        pkgId = p.id;
        pkgName = p.name;
      } else {
        final picks = (List<Service>.of(activeSvcs)..shuffle(rnd)).take(2 + rnd.nextInt(3));
        items = PricingEngine.snapshot({for (final s in picks) s.id: 1 + rnd.nextInt(min(4, s.maxQty))}, db.services);
        subtotal = PricingEngine.subtotalOf(items);
        pkgId = null;
        pkgName = 'Custom Package';
      }
      CouponSnapshot? cs;
      var discount = 0;
      if (u.id != demoUserId && subtotal >= welcome.minOrder && rnd.nextInt(4) == 0) {
        discount = CouponValidator.discountFor(welcome, subtotal);
        cs = CouponSnapshot(code: welcome.code, type: welcome.type, value: welcome.value, discount: discount);
      }
      final pricing = PricingEngine.price(subtotal: subtotal, discount: discount);
      final isFuture = !event.isBefore(today);
      var created = isFuture
          ? now.subtract(Duration(days: rnd.nextInt(6), hours: rnd.nextInt(20)))
          : event.subtract(Duration(days: 4 + rnd.nextInt(25)));
      if (created.isAfter(now)) created = now;
      final online = rnd.nextBool();
      final seqId = db.nextId('bk');
      final seqNum = db.seq;
      final history = <StatusEvent>[StatusEvent(status: BookingStatus.pendingConfirmation, at: created, by: 'Customer')];
      Cancellation? cancellation;
      var payStatus = online ? PaymentStatus.paid : PaymentStatus.pending;
      if (status == BookingStatus.confirmed || status == BookingStatus.completed) {
        history.add(StatusEvent(status: BookingStatus.confirmed, at: created.add(const Duration(hours: 20)), by: 'Admin: Tanvir Ahmed'));
      }
      if (status == BookingStatus.completed) {
        history.add(StatusEvent(status: BookingStatus.completed, at: event.add(const Duration(days: 1)), by: 'Admin: Tanvir Ahmed'));
        payStatus = PaymentStatus.paid;
      }
      if (status.isCancelled) {
        final byAdmin = status == BookingStatus.cancelledByAdmin;
        final at = created.add(const Duration(hours: 30));
        cancellation = Cancellation(
          cancelledBy: byAdmin ? Actor.admin : Actor.customer,
          cancelledAt: at.isAfter(now) ? now : at,
          reason: byAdmin ? 'Photographer unavailable on the requested date.' : (rnd.nextBool() ? 'Event postponed.' : null),
        );
        history.add(StatusEvent(status: status, at: cancellation.cancelledAt, by: byAdmin ? 'Admin: Tanvir Ahmed' : 'Customer'));
      }
      final div = BdGeoPick.pick(rnd);
      return Booking(
        id: seqId,
        code: 'BK-${now.year}-${seqNum.toString().padLeft(5, '0')}',
        customerId: u.id,
        packageId: pkgId,
        packageName: pkgName,
        items: items,
        schedule: EventSchedule(date: event, slot: slot),
        location: EventLocation(division: div.$1, district: div.$2, area: 'Central Area', detail: 'House ${1 + rnd.nextInt(80)}, Road ${1 + rnd.nextInt(20)}'),
        contact: ContactInfo(name: u.name, phone: u.phone, email: u.email, notes: rnd.nextInt(3) == 0 ? 'Please arrive 30 minutes early.' : ''),
        coupon: cs,
        pricing: pricing,
        payment: Payment(
          method: online ? PaymentMethod.online : PaymentMethod.cashOnSite,
          status: payStatus,
          amount: pricing.total,
          provider: online ? PaymentProvider.values[rnd.nextInt(3)] : null,
          reference: online ? 'TXN${100000 + rnd.nextInt(899999)}' : null,
        ),
        status: status,
        cancellation: cancellation,
        history: history,
        createdAt: created,
      );
    }

    void add(AppUser u, DateTime event, BookingStatus s, {int? pkgIndex}) {
      for (var t = 0; t < 30; t++) {
        final slot = EventSlots.all[rnd.nextInt(EventSlots.all.length)];
        final key = '${event.toIso8601String()}|$slot';
        if (used.contains(key)) continue;
        used.add(key);
        db.bookings.add(make(u, event, slot, s, pkgIndex: pkgIndex));
        return;
      }
    }

    final demo = db.users.first;
    final others = db.users.skip(1).toList();
    // Demo customer's own history (covers every status)
    add(demo, today.add(const Duration(days: 12)), BookingStatus.pendingConfirmation, pkgIndex: 3);
    add(demo, today.add(const Duration(days: 20)), BookingStatus.confirmed, pkgIndex: 0);
    add(demo, today.subtract(const Duration(days: 30)), BookingStatus.completed, pkgIndex: 2);
    add(demo, today.subtract(const Duration(days: 55)), BookingStatus.cancelledByAdmin, pkgIndex: 1);
    add(demo, today.subtract(const Duration(days: 80)), BookingStatus.cancelledByCustomer, pkgIndex: 3);

    // One fully booked date so the calendar shows an unavailable day
    final fullDay = today.add(const Duration(days: 9));
    for (final slot in EventSlots.all) {
      used.add('${fullDay.toIso8601String()}|$slot');
      db.bookings.add(make(others[rnd.nextInt(others.length)], fullDay, slot, BookingStatus.confirmed));
    }

    // Historic + upcoming bookings
    for (var i = 0; i < 95; i++) {
      final u = others[rnd.nextInt(others.length)];
      final past = i < 78;
      if (past) {
        final r = rnd.nextInt(100);
        add(u, today.subtract(Duration(days: 2 + rnd.nextInt(180))), r < 86 ? BookingStatus.completed : (r < 94 ? BookingStatus.cancelledByCustomer : BookingStatus.cancelledByAdmin));
      } else {
        final r = rnd.nextInt(100);
        add(u, today.add(Duration(days: 2 + rnd.nextInt(45))), r < 40 ? BookingStatus.pendingConfirmation : (r < 90 ? BookingStatus.confirmed : BookingStatus.cancelledByCustomer));
      }
    }
    db.bookings.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Support requests
    const subjects = {
      SupportCategory.packageInquiry: 'Can I add a second videographer to the wedding package?',
      SupportCategory.customPackageRequest: 'Need a custom plan for a 2-day event',
      SupportCategory.bookingAssistance: 'Unable to select my preferred date',
      SupportCategory.paymentIssue: 'Online payment deducted but booking pending',
      SupportCategory.generalSupport: 'Do you cover events outside Dhaka?',
      SupportCategory.other: 'Feedback about the app',
    };
    var i = 0;
    for (final e in subjects.entries) {
      final u = others[i * 3 % others.length];
      db.support.add(SupportRequest(
        id: db.nextId('sup'),
        userId: u.id,
        name: u.name,
        email: u.email,
        phone: u.phone,
        category: e.key,
        subject: e.value,
        message: 'Hello team, ${e.value} Please let me know how to proceed. Thank you!',
        status: SupportStatus.values[i % 3],
        notes: i % 3 == 1 ? ['[${now.day}/${now.month}] Called customer, waiting for details.'] : const [],
        createdAt: now.subtract(Duration(days: i + 1, hours: i * 3)),
      ));
      i++;
    }

    db.wishlists[demoUserId] = ['pkg_wedding', 'pkg_portrait'];
  }
}

abstract final class BdGeoPick {
  static (String, String) pick(Random r) {
    const opts = [('Dhaka', 'Dhaka'), ('Dhaka', 'Gazipur'), ('Chattogram', 'Chattogram'), ('Sylhet', 'Sylhet'), ('Rajshahi', 'Rajshahi'), ('Khulna', 'Khulna')];
    return opts[r.nextInt(opts.length)];
  }
}

import 'package:jamcon/domain/models/enums.dart';

class BookingItem {
  const BookingItem({required this.serviceId, required this.name, required this.unitPrice, required this.qty, this.unitLabel = ''});
  final String serviceId;
  final String name;
  final String unitLabel;
  final int unitPrice;
  final int qty;
  int get lineTotal => unitPrice * qty;

  Map<String, dynamic> toJson() => {'serviceId': serviceId, 'name': name, 'unitLabel': unitLabel, 'unitPrice': unitPrice, 'qty': qty};
  factory BookingItem.fromJson(Map<String, dynamic> j) => BookingItem(
        serviceId: j['serviceId'] as String,
        name: j['name'] as String,
        unitLabel: (j['unitLabel'] as String?) ?? '',
        unitPrice: j['unitPrice'] as int,
        qty: j['qty'] as int,
      );
}

class EventSchedule {
  const EventSchedule({required this.date, required this.slot});
  final DateTime date;
  final String slot;
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'slot': slot};
  factory EventSchedule.fromJson(Map<String, dynamic> j) =>
      EventSchedule(date: DateTime.parse(j['date'] as String), slot: j['slot'] as String);
}

class EventLocation {
  const EventLocation({required this.division, required this.district, required this.area, required this.detail});
  final String division;
  final String district;
  final String area;
  final String detail;
  String get full => '$detail, $area, $district, $division';
  Map<String, dynamic> toJson() => {'division': division, 'district': district, 'area': area, 'detail': detail};
  factory EventLocation.fromJson(Map<String, dynamic> j) => EventLocation(
        division: j['division'] as String,
        district: j['district'] as String,
        area: j['area'] as String,
        detail: j['detail'] as String,
      );
}

class ContactInfo {
  const ContactInfo({required this.name, required this.phone, required this.email, this.altPhone = '', this.notes = ''});
  final String name;
  final String phone;
  final String email;
  final String altPhone;
  final String notes;
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'email': email, 'altPhone': altPhone, 'notes': notes};
  factory ContactInfo.fromJson(Map<String, dynamic> j) => ContactInfo(
        name: j['name'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String,
        altPhone: (j['altPhone'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );
}

class CouponSnapshot {
  const CouponSnapshot({required this.code, required this.type, required this.value, required this.discount});
  final String code;
  final CouponType type;
  final int value;
  final int discount;
  Map<String, dynamic> toJson() => {'code': code, 'type': type.name, 'value': value, 'discount': discount};
  factory CouponSnapshot.fromJson(Map<String, dynamic> j) => CouponSnapshot(
        code: j['code'] as String,
        type: enumByName(CouponType.values, j['type'], CouponType.fixed),
        value: j['value'] as int,
        discount: j['discount'] as int,
      );
}

class Pricing {
  const Pricing({required this.subtotal, required this.discount, required this.total});
  final int subtotal;
  final int discount;
  final int total;
  Map<String, dynamic> toJson() => {'subtotal': subtotal, 'discount': discount, 'total': total};
  factory Pricing.fromJson(Map<String, dynamic> j) =>
      Pricing(subtotal: j['subtotal'] as int, discount: j['discount'] as int, total: j['total'] as int);
}

class Payment {
  const Payment({required this.method, required this.status, required this.amount, this.provider, this.reference});
  final PaymentMethod method;
  final PaymentStatus status;
  final int amount;
  final PaymentProvider? provider;
  final String? reference;

  Payment copyWith({PaymentStatus? status}) =>
      Payment(method: method, status: status ?? this.status, amount: amount, provider: provider, reference: reference);

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'status': status.name,
        'amount': amount,
        'provider': provider?.name,
        'reference': reference,
      };
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        method: enumByName(PaymentMethod.values, j['method'], PaymentMethod.cashOnSite),
        status: enumByName(PaymentStatus.values, j['status'], PaymentStatus.pending),
        amount: j['amount'] as int,
        provider: j['provider'] == null ? null : enumByName(PaymentProvider.values, j['provider'], PaymentProvider.card),
        reference: j['reference'] as String?,
      );
}

class Cancellation {
  const Cancellation({required this.cancelledBy, required this.cancelledAt, this.reason});
  final Actor cancelledBy;
  final DateTime cancelledAt;
  final String? reason;
  Map<String, dynamic> toJson() => {'cancelledBy': cancelledBy.name, 'cancelledAt': cancelledAt.toIso8601String(), 'reason': reason};
  factory Cancellation.fromJson(Map<String, dynamic> j) => Cancellation(
        cancelledBy: enumByName(Actor.values, j['cancelledBy'], Actor.customer),
        cancelledAt: DateTime.parse(j['cancelledAt'] as String),
        reason: j['reason'] as String?,
      );
}

class StatusEvent {
  const StatusEvent({required this.status, required this.at, required this.by});
  final BookingStatus status;
  final DateTime at;
  final String by;
  Map<String, dynamic> toJson() => {'status': status.name, 'at': at.toIso8601String(), 'by': by};
  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        status: enumByName(BookingStatus.values, j['status'], BookingStatus.pendingConfirmation),
        at: DateTime.parse(j['at'] as String),
        by: j['by'] as String,
      );
}

class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.customerId,
    this.packageId,
    required this.packageName,
    required this.items,
    required this.schedule,
    required this.location,
    required this.contact,
    this.coupon,
    required this.pricing,
    required this.payment,
    required this.status,
    this.cancellation,
    required this.history,
    required this.createdAt,
  });

  final String id;
  final String code; // human-readable booking ID shown in the UI, e.g. BK-2026-00042
  final String customerId;
  final String? packageId; // null => custom package
  final String packageName;
  final List<BookingItem> items; // price snapshot at booking time
  final EventSchedule schedule;
  final EventLocation location;
  final ContactInfo contact;
  final CouponSnapshot? coupon;
  final Pricing pricing;
  final Payment payment;
  final BookingStatus status;
  final Cancellation? cancellation;
  final List<StatusEvent> history;
  final DateTime createdAt;

  bool get isCustom => packageId == null;

  Booking copyWith({BookingStatus? status, Cancellation? cancellation, Payment? payment, List<StatusEvent>? history}) => Booking(
        id: id,
        code: code,
        customerId: customerId,
        packageId: packageId,
        packageName: packageName,
        items: items,
        schedule: schedule,
        location: location,
        contact: contact,
        coupon: coupon,
        pricing: pricing,
        payment: payment ?? this.payment,
        status: status ?? this.status,
        cancellation: cancellation ?? this.cancellation,
        history: history ?? this.history,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'customerId': customerId,
        'packageId': packageId,
        'packageName': packageName,
        'items': items.map((e) => e.toJson()).toList(),
        'schedule': schedule.toJson(),
        'location': location.toJson(),
        'contact': contact.toJson(),
        'coupon': coupon?.toJson(),
        'pricing': pricing.toJson(),
        'payment': payment.toJson(),
        'status': status.name,
        'cancellation': cancellation?.toJson(),
        'history': history.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        code: j['code'] as String,
        customerId: j['customerId'] as String,
        packageId: j['packageId'] as String?,
        packageName: j['packageName'] as String,
        items: (j['items'] as List).map((e) => BookingItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        schedule: EventSchedule.fromJson(Map<String, dynamic>.from(j['schedule'] as Map)),
        location: EventLocation.fromJson(Map<String, dynamic>.from(j['location'] as Map)),
        contact: ContactInfo.fromJson(Map<String, dynamic>.from(j['contact'] as Map)),
        coupon: j['coupon'] == null ? null : CouponSnapshot.fromJson(Map<String, dynamic>.from(j['coupon'] as Map)),
        pricing: Pricing.fromJson(Map<String, dynamic>.from(j['pricing'] as Map)),
        payment: Payment.fromJson(Map<String, dynamic>.from(j['payment'] as Map)),
        status: enumByName(BookingStatus.values, j['status'], BookingStatus.pendingConfirmation),
        cancellation: j['cancellation'] == null ? null : Cancellation.fromJson(Map<String, dynamic>.from(j['cancellation'] as Map)),
        history: (j['history'] as List).map((e) => StatusEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// What the client sends to create a booking. Prices are NOT sent — the service
/// recomputes everything (like a real backend must).
class BookingRequest {
  const BookingRequest({
    required this.customerId,
    this.packageId,
    this.items = const {},
    required this.schedule,
    required this.location,
    required this.contact,
    this.couponCode,
    required this.paymentMethod,
    this.paymentProvider,
    this.paymentReference,
    this.paymentConfirmed = false,
  });
  final String customerId;
  final String? packageId;
  final Map<String, int> items; // serviceId -> qty (custom package)
  final EventSchedule schedule;
  final EventLocation location;
  final ContactInfo contact;
  final String? couponCode;
  final PaymentMethod paymentMethod;
  final PaymentProvider? paymentProvider;
  final String? paymentReference;
  final bool paymentConfirmed;
}

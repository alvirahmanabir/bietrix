import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/rules/pricing_engine.dart';
import 'package:jamcon/features/common/queries.dart';

/// Everything entered across the booking steps. Persisted locally so a half-finished
/// booking survives an app restart. Prices are derived, never stored (except the
/// coupon discount that the CouponService validated for the current subtotal).
class BookingDraft {
  const BookingDraft({
    this.step = 0,
    this.packageId,
    this.items = const {},
    this.date,
    this.slot,
    this.division = '',
    this.district = '',
    this.area = '',
    this.detail = '',
    this.name = '',
    this.phone = '',
    this.altPhone = '',
    this.notes = '',
    this.couponCode,
    this.couponDiscount = 0,
    this.method = PaymentMethod.cashOnSite,
  });

  final int step;
  final String? packageId; // null + items => custom package
  final Map<String, int> items;
  final DateTime? date;
  final String? slot;
  final String division, district, area, detail;
  final String name, phone, altPhone, notes;
  final String? couponCode;
  final int couponDiscount;
  final PaymentMethod method;

  bool get hasSelection => packageId != null || items.isNotEmpty;

  BookingDraft copyWith({
    int? step,
    String? packageId,
    bool clearPackage = false,
    Map<String, int>? items,
    DateTime? date,
    String? slot,
    bool clearSchedule = false,
    String? division,
    String? district,
    String? area,
    String? detail,
    String? name,
    String? phone,
    String? altPhone,
    String? notes,
    String? couponCode,
    int? couponDiscount,
    bool clearCoupon = false,
    PaymentMethod? method,
  }) =>
      BookingDraft(
        step: step ?? this.step,
        packageId: clearPackage ? null : (packageId ?? this.packageId),
        items: items ?? this.items,
        date: clearSchedule ? null : (date ?? this.date),
        slot: clearSchedule ? null : (slot ?? this.slot),
        division: division ?? this.division,
        district: district ?? this.district,
        area: area ?? this.area,
        detail: detail ?? this.detail,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        altPhone: altPhone ?? this.altPhone,
        notes: notes ?? this.notes,
        couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
        couponDiscount: clearCoupon ? 0 : (couponDiscount ?? this.couponDiscount),
        method: method ?? this.method,
      );

  Map<String, dynamic> toJson() => {
        'step': step,
        'packageId': packageId,
        'items': items,
        'date': date?.toIso8601String(),
        'slot': slot,
        'division': division,
        'district': district,
        'area': area,
        'detail': detail,
        'name': name,
        'phone': phone,
        'altPhone': altPhone,
        'notes': notes,
        'couponCode': couponCode,
        'couponDiscount': couponDiscount,
        'method': method.name,
      };

  factory BookingDraft.fromJson(Map<String, dynamic> j) => BookingDraft(
        step: (j['step'] as int?) ?? 0,
        packageId: j['packageId'] as String?,
        items: {for (final e in ((j['items'] as Map?) ?? const {}).entries) e.key as String: e.value as int},
        date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
        slot: j['slot'] as String?,
        division: (j['division'] as String?) ?? '',
        district: (j['district'] as String?) ?? '',
        area: (j['area'] as String?) ?? '',
        detail: (j['detail'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        altPhone: (j['altPhone'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        couponCode: j['couponCode'] as String?,
        couponDiscount: (j['couponDiscount'] as int?) ?? 0,
        method: enumByName(PaymentMethod.values, j['method'], PaymentMethod.cashOnSite),
      );
}

class BookingDraftNotifier extends Notifier<BookingDraft> {
  static const _key = 'booking_draft_v1';

  @override
  BookingDraft build() {
    final raw = ref.read(localStoreProvider).getString(_key);
    if (raw == null) return const BookingDraft();
    try {
      return BookingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const BookingDraft();
    }
  }

  void _set(BookingDraft d) {
    state = d;
    ref.read(localStoreProvider).setString(_key, jsonEncode(d.toJson()));
  }

  /// Starts a fresh booking but keeps contact + location the customer already typed.
  BookingDraft _fresh() => BookingDraft(
        division: state.division,
        district: state.district,
        area: state.area,
        detail: state.detail,
        name: state.name,
        phone: state.phone,
        altPhone: state.altPhone,
      );

  void startWithPackage(String id) => _set(_fresh().copyWith(packageId: id));
  void startCustom(Map<String, int> items) => _set(_fresh().copyWith(items: Map.of(items)));

  void setStep(int s) => _set(state.copyWith(step: s));
  void setSchedule(DateTime date, {String? slot}) {
    final same = state.date != null && sameDay(state.date!, date);
    final keep = slot ?? (same ? state.slot : null);
    _set(state.copyWith(clearSchedule: true).copyWith(date: date, slot: keep));
  }

  void setLocation({String? division, String? district, String? area, String? detail}) =>
      _set(state.copyWith(division: division, district: district, area: area, detail: detail));
  void setContact({String? name, String? phone, String? altPhone, String? notes}) =>
      _set(state.copyWith(name: name, phone: phone, altPhone: altPhone, notes: notes));
  void applyCoupon(String code, int discount) => _set(state.copyWith(couponCode: code, couponDiscount: discount));
  void clearCoupon() => _set(state.copyWith(clearCoupon: true));
  void setMethod(PaymentMethod m) => _set(state.copyWith(method: m));

  void clear() {
    state = const BookingDraft();
    ref.read(localStoreProvider).remove(_key);
  }
}

final bookingDraftProvider = NotifierProvider<BookingDraftNotifier, BookingDraft>(BookingDraftNotifier.new);

class DraftSummary {
  const DraftSummary({required this.title, required this.items, required this.subtotal, required this.isCustom});
  final String title;
  final List<BookingItem> items;
  final int subtotal;
  final bool isCustom;
}

/// Derived from the draft + live catalogue (so admin price edits reflect before booking).
final draftSummaryProvider = Provider<DraftSummary?>((ref) {
  final d = ref.watch(bookingDraftProvider);
  final pkgs = ref.watch(packagesProvider).value;
  final svcs = ref.watch(servicesProvider).value;
  if (pkgs == null || svcs == null) return null;
  if (d.packageId != null) {
    final p = pkgs.firstWhereOrNull((x) => x.id == d.packageId);
    if (p == null || !p.isActive) return null;
    final items = PricingEngine.snapshot({for (final id in p.serviceIds) id: 1}, svcs, includeInactive: true);
    return DraftSummary(title: p.name, items: items, subtotal: p.price, isCustom: false);
  }
  if (d.items.isNotEmpty) {
    final items = PricingEngine.snapshot(d.items, svcs);
    if (items.isEmpty) return null;
    return DraftSummary(title: 'Custom Package', items: items, subtotal: PricingEngine.subtotalOf(items), isCustom: true);
  }
  return null;
});

final draftPricingProvider = Provider<Pricing?>((ref) {
  final s = ref.watch(draftSummaryProvider);
  if (s == null) return null;
  return PricingEngine.price(subtotal: s.subtotal, discount: ref.watch(bookingDraftProvider).couponDiscount);
});

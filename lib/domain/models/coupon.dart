import 'package:jamcon/domain/models/enums.dart';

class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    this.description = '',
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minOrder = 0,
    required this.expiresAt,
    this.usageLimit = 0,
    this.perUserLimit = 1,
    this.usedCount = 0,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String description;
  final CouponType type;
  final int value; // percent (1-100) or fixed BDT
  final int? maxDiscount; // cap for percent coupons
  final int minOrder;
  final DateTime expiresAt;
  final int usageLimit; // 0 = unlimited
  final int perUserLimit; // 0 = unlimited
  final int usedCount;
  final bool isActive;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);
  String get valueLabel => type == CouponType.percent ? '$value% OFF' : '৳$value OFF';

  Coupon copyWith({
    String? code,
    String? description,
    CouponType? type,
    int? value,
    int? maxDiscount,
    bool clearMax = false,
    int? minOrder,
    DateTime? expiresAt,
    int? usageLimit,
    int? perUserLimit,
    int? usedCount,
    bool? isActive,
  }) =>
      Coupon(
        id: id,
        code: code ?? this.code,
        description: description ?? this.description,
        type: type ?? this.type,
        value: value ?? this.value,
        maxDiscount: clearMax ? null : (maxDiscount ?? this.maxDiscount),
        minOrder: minOrder ?? this.minOrder,
        expiresAt: expiresAt ?? this.expiresAt,
        usageLimit: usageLimit ?? this.usageLimit,
        perUserLimit: perUserLimit ?? this.perUserLimit,
        usedCount: usedCount ?? this.usedCount,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'description': description,
        'type': type.name,
        'value': value,
        'maxDiscount': maxDiscount,
        'minOrder': minOrder,
        'expiresAt': expiresAt.toIso8601String(),
        'usageLimit': usageLimit,
        'perUserLimit': perUserLimit,
        'usedCount': usedCount,
        'isActive': isActive,
      };

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: j['id'] as String,
        code: j['code'] as String,
        description: (j['description'] as String?) ?? '',
        type: enumByName(CouponType.values, j['type'], CouponType.fixed),
        value: j['value'] as int,
        maxDiscount: j['maxDiscount'] as int?,
        minOrder: (j['minOrder'] as int?) ?? 0,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        usageLimit: (j['usageLimit'] as int?) ?? 0,
        perUserLimit: (j['perUserLimit'] as int?) ?? 1,
        usedCount: (j['usedCount'] as int?) ?? 0,
        isActive: (j['isActive'] as bool?) ?? true,
      );
}

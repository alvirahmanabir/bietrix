class Service {
  const Service({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    this.imageKey = 'studio',
    required this.unitPrice,
    this.unitLabel = 'item',
    this.maxQty = 1,
    this.isActive = true,
  });

  final String id;
  final String category;
  final String name;
  final String description;
  final String imageKey;
  final int unitPrice;
  final String unitLabel;
  final int maxQty;
  final bool isActive;

  bool get hasQuantity => maxQty > 1;

  Service copyWith({
    String? category,
    String? name,
    String? description,
    String? imageKey,
    int? unitPrice,
    String? unitLabel,
    int? maxQty,
    bool? isActive,
  }) =>
      Service(
        id: id,
        category: category ?? this.category,
        name: name ?? this.name,
        description: description ?? this.description,
        imageKey: imageKey ?? this.imageKey,
        unitPrice: unitPrice ?? this.unitPrice,
        unitLabel: unitLabel ?? this.unitLabel,
        maxQty: maxQty ?? this.maxQty,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'description': description,
        'imageKey': imageKey,
        'unitPrice': unitPrice,
        'unitLabel': unitLabel,
        'maxQty': maxQty,
        'isActive': isActive,
      };

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as String,
        category: j['category'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        imageKey: (j['imageKey'] as String?) ?? 'studio',
        unitPrice: j['unitPrice'] as int,
        unitLabel: (j['unitLabel'] as String?) ?? 'item',
        maxQty: (j['maxQty'] as int?) ?? 1,
        isActive: (j['isActive'] as bool?) ?? true,
      );
}

class Package {
  const Package({
    required this.id,
    required this.name,
    required this.description,
    this.imageKey = 'studio',
    required this.serviceIds,
    required this.basePrice,
    this.promoPrice,
    this.isActive = true,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String description;
  final String imageKey;
  final List<String> serviceIds;
  final int basePrice;
  final int? promoPrice;
  final bool isActive;
  final bool isFeatured;

  bool get hasPromo => promoPrice != null && promoPrice! < basePrice;
  int get price => hasPromo ? promoPrice! : basePrice;

  Package copyWith({
    String? name,
    String? description,
    String? imageKey,
    List<String>? serviceIds,
    int? basePrice,
    int? promoPrice,
    bool clearPromo = false,
    bool? isActive,
    bool? isFeatured,
  }) =>
      Package(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        imageKey: imageKey ?? this.imageKey,
        serviceIds: serviceIds ?? this.serviceIds,
        basePrice: basePrice ?? this.basePrice,
        promoPrice: clearPromo ? null : (promoPrice ?? this.promoPrice),
        isActive: isActive ?? this.isActive,
        isFeatured: isFeatured ?? this.isFeatured,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageKey': imageKey,
        'serviceIds': serviceIds,
        'basePrice': basePrice,
        'promoPrice': promoPrice,
        'isActive': isActive,
        'isFeatured': isFeatured,
      };

  factory Package.fromJson(Map<String, dynamic> j) => Package(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        imageKey: (j['imageKey'] as String?) ?? 'studio',
        serviceIds: (j['serviceIds'] as List).cast<String>(),
        basePrice: j['basePrice'] as int,
        promoPrice: j['promoPrice'] as int?,
        isActive: (j['isActive'] as bool?) ?? true,
        isFeatured: (j['isFeatured'] as bool?) ?? false,
      );
}

abstract final class ServiceCategories {
  static const all = ['Photography', 'Videography', 'Aerial', 'Editing & Prints', 'Add-ons'];
}

abstract final class ImageKeys {
  static const all = ['wedding', 'portrait', 'corporate', 'birthday', 'drone', 'video', 'album', 'studio', 'camera', 'editing', 'festival', 'live'];
}

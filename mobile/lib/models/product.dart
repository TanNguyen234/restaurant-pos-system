import '../config/api_config.dart';

class ProductAttribute {
  final int attributeId;
  final int productId;
  final String attributeGroup; // 'Size', 'Đường', 'Đá', 'Topping'
  final String attributeName;
  final double extraPrice;
  final bool isRequired;

  ProductAttribute({
    required this.attributeId,
    required this.productId,
    required this.attributeGroup,
    required this.attributeName,
    this.extraPrice = 0.0,
    this.isRequired = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAttribute &&
          runtimeType == other.runtimeType &&
          attributeId == other.attributeId &&
          attributeName == other.attributeName;

  @override
  int get hashCode => Object.hash(attributeId, attributeName);

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v.toString().toLowerCase() == 'true' || v.toString() == '1';
  }

  factory ProductAttribute.fromMap(Map<String, dynamic> map) {
    return ProductAttribute(
      attributeId: (map['attributeId'] ?? 0) as int,
      productId: (map['productId'] ?? 0) as int,
      attributeGroup: (map['attributeGroup'] ?? '').toString(),
      attributeName: (map['attributeName'] ?? '').toString(),
      extraPrice: (map['extraPrice'] as num?)?.toDouble() ?? 0.0,
      isRequired: _parseBool(map['isRequired']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attributeId': attributeId,
      'productId': productId,
      'attributeGroup': attributeGroup,
      'attributeName': attributeName,
      'extraPrice': extraPrice,
      'isRequired': isRequired,
    };
  }
}

class Product {
  final int productId;
  final int categoryId;
  final String? categoryName;
  final String productName;
  final double price;
  final String unit;
  final String? description;
  final String imageUrl;
  final List<String> images;
  final bool isAvailable;
  final bool isFeatured;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ProductAttribute> attributes;

  Product({
    required this.productId,
    required this.categoryId,
    this.categoryName,
    required this.productName,
    required this.price,
    this.unit = 'Ly',
    this.description,
    required this.imageUrl,
    this.images = const [],
    this.isAvailable = true,
    this.isFeatured = false,
    this.createdAt,
    this.updatedAt,
    this.attributes = const [],
  });

  List<String> get resolvedImages {
    if (images.isNotEmpty) return images.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (imageUrl.isNotEmpty) {
      return imageUrl
          .split(RegExp(r'[;|]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  String get primaryImageUrl {
    final list = resolvedImages;
    if (list.isNotEmpty) return list.first;
    return imageUrl.trim();
  }

  String get fullImageUrl {
    final img = primaryImageUrl;
    if (img.isEmpty) return '';
    if (img.startsWith('http://') || img.startsWith('https://')) return img;
    final base = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$base/images/products/$img';
  }

  List<String> get allFullImageUrls {
    final list = resolvedImages;
    if (list.isEmpty) return [];
    final base = ApiConfig.baseUrl.replaceAll('/api', '');
    return list.map((img) {
      if (img.startsWith('http://') || img.startsWith('https://')) return img;
      return '$base/images/products/$img';
    }).toList();
  }

  static bool _parseBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v.toString().toLowerCase() == 'true' || v.toString() == '1';
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    var attrsRaw = map['attributes'];
    List<ProductAttribute> attrs = [];
    if (attrsRaw is List) {
      attrs = attrsRaw
          .whereType<Map>()
          .map((a) => ProductAttribute.fromMap(Map<String, dynamic>.from(a)))
          .toList();
    }

    final rawImageUrl = (map['imageUrl'] ?? map['image_url'] ?? map['image'] ?? '').toString();
    final List<String> parsedImages;
    if (map['images'] is List && (map['images'] as List).isNotEmpty) {
      parsedImages = (map['images'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawImageUrl.isNotEmpty) {
      parsedImages = rawImageUrl.split(RegExp(r'[;|]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      parsedImages = const [];
    }

    return Product(
      productId: ((map['productId'] ?? map['id']) as num? ?? 0).toInt(),
      categoryId: ((map['categoryId'] ?? map['category_id']) as num? ?? 0).toInt(),
      categoryName: map['categoryName'] as String?,
      productName: (map['productName'] ?? map['name'] ?? '').toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      unit: (map['unit'] ?? 'Ly').toString(),
      description: map['description'] as String?,
      imageUrl: rawImageUrl,
      images: parsedImages,
      isAvailable: _parseBool(map['isAvailable'] ?? map['is_available'], fallback: true),
      isFeatured: _parseBool(map['isFeatured'] ?? map['is_featured'], fallback: false),
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
      attributes: attrs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'productName': productName,
      'price': price,
      'unit': unit,
      'description': description,
      'imageUrl': imageUrl,
      'images': images,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'attributes': attributes.map((a) => a.toMap()).toList(),
    };
  }
}

class PagedProductResult {
  final int totalItems;
  final int page;
  final int pageSize;
  final int totalPages;
  final List<Product> data;

  PagedProductResult({
    required this.totalItems,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.data,
  });

  factory PagedProductResult.fromMap(Map<String, dynamic> map) {
    var rawList = map['data'] as List? ?? map['items'] as List? ?? [];
    return PagedProductResult(
      totalItems: map['totalItems'] ?? 0,
      page: map['page'] ?? 1,
      pageSize: map['pageSize'] ?? 10,
      totalPages: map['totalPages'] ?? 0,
      data: rawList.map((p) => Product.fromMap(Map<String, dynamic>.from(p as Map))).toList(),
    );
  }
}

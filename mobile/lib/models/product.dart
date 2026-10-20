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

  factory ProductAttribute.fromMap(Map<String, dynamic> map) {
    return ProductAttribute(
      attributeId: map['attributeId'] ?? 0,
      productId: map['productId'] ?? 0,
      attributeGroup: map['attributeGroup'] ?? '',
      attributeName: map['attributeName'] ?? '',
      extraPrice: (map['extraPrice'] as num?)?.toDouble() ?? 0.0,
      isRequired: map['isRequired'] ?? false,
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
    this.unit = 'Phần',
    this.description,
    required this.imageUrl,
    this.isAvailable = true,
    this.isFeatured = false,
    this.createdAt,
    this.updatedAt,
    this.attributes = const [],
  });

  String get fullImageUrl {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) return imageUrl;
    return 'http://localhost:5138/images/products/$imageUrl';
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    var attrsRaw = map['attributes'];
    List<ProductAttribute> attrs = [];
    if (attrsRaw is List) {
      attrs = attrsRaw
          .whereType<Map<String, dynamic>>()
          .map((a) => ProductAttribute.fromMap(a))
          .toList();
    }

    return Product(
      productId: map['productId'] ?? map['id'] ?? 0,
      categoryId: (map['categoryId'] as num?)?.toInt() ?? 0,
      categoryName: map['categoryName'] as String?,
      productName: map['productName'] ?? map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? 'Phần',
      description: map['description'] as String?,
      imageUrl: map['imageUrl'] ?? map['image'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
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
    var rawList = map['data'] as List? ?? [];
    return PagedProductResult(
      totalItems: map['totalItems'] ?? 0,
      page: map['page'] ?? 1,
      pageSize: map['pageSize'] ?? 10,
      totalPages: map['totalPages'] ?? 0,
      data: rawList.map((p) => Product.fromMap(p as Map<String, dynamic>)).toList(),
    );
  }
}

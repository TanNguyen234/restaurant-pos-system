import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ProductRepository {
  static String baseUrl = "http://localhost:5138/api/product";
  static Duration timeoutDuration = const Duration(seconds: 4);

  // Fallback mock products for offline resilience & testing
  static final List<Product> _fallbackProducts = [
    Product(
      productId: 1,
      categoryId: 1,
      categoryName: 'Cà phê truyền thống',
      productName: 'Cà phê đen đá Đắk Lắk',
      price: 25000,
      unit: 'Ly',
      description: 'Hạt Robusta nguyên chất pha phin truyền thống, thơm đắng đậm vị',
      imageUrl: 'cafe_den_da.jpg',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 1, productId: 1, attributeGroup: 'Size', attributeName: 'Size M (Chuẩn)', extraPrice: 0),
        ProductAttribute(attributeId: 2, productId: 1, attributeGroup: 'Size', attributeName: 'Size L (+8k)', extraPrice: 8000),
        ProductAttribute(attributeId: 3, productId: 1, attributeGroup: 'Đường', attributeName: 'Không đường', extraPrice: 0),
        ProductAttribute(attributeId: 4, productId: 1, attributeGroup: 'Đường', attributeName: 'Ít đường (50%)', extraPrice: 0),
        ProductAttribute(attributeId: 5, productId: 1, attributeGroup: 'Đá', attributeName: 'Ít đá', extraPrice: 0),
        ProductAttribute(attributeId: 6, productId: 1, attributeGroup: 'Đá', attributeName: 'Đá riêng', extraPrice: 0),
      ],
    ),
    Product(
      productId: 2,
      categoryId: 1,
      categoryName: 'Cà phê truyền thống',
      productName: 'Cà phê sữa đá Sài Gòn',
      price: 29000,
      unit: 'Ly',
      description: 'Cà phê phin kết hợp sữa đặc ngọt béo thơm lừng hương vị Sài Gòn',
      imageUrl: 'cafe_sua_da.jpg',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 7, productId: 2, attributeGroup: 'Size', attributeName: 'Size M (Chuẩn)', extraPrice: 0),
        ProductAttribute(attributeId: 8, productId: 2, attributeGroup: 'Size', attributeName: 'Size L (+8k)', extraPrice: 8000),
        ProductAttribute(attributeId: 9, productId: 2, attributeGroup: 'Đá', attributeName: 'Bình thường', extraPrice: 0),
        ProductAttribute(attributeId: 10, productId: 2, attributeGroup: 'Đá', attributeName: 'Ít đá', extraPrice: 0),
      ],
    ),
    Product(
      productId: 3,
      categoryId: 1,
      categoryName: 'Cà phê truyền thống',
      productName: 'Bạc xỉu ba tầng sữa tươi',
      price: 35000,
      unit: 'Ly',
      description: 'Ba tầng đẹp mắt: sữa đặc, sữa tươi thanh trùng và lớp cà phê bồng bềnh',
      imageUrl: 'bac_xiu.jpg',
      isAvailable: true,
      isFeatured: false,
      attributes: [
        ProductAttribute(attributeId: 11, productId: 3, attributeGroup: 'Size', attributeName: 'Size M', extraPrice: 0),
        ProductAttribute(attributeId: 12, productId: 3, attributeGroup: 'Size', attributeName: 'Size L', extraPrice: 8000),
      ],
    ),
    Product(
      productId: 4,
      categoryId: 1,
      categoryName: 'Cà phê truyền thống',
      productName: 'Cà phê muối xứ Huế',
      price: 39000,
      unit: 'Ly',
      description: 'Cà phê nguyên chất kết hợp lớp kem sữa muối mặn mà béo ngậy đặc sản Huế',
      imageUrl: 'cafe_muoi.jpg',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 13, productId: 4, attributeGroup: 'Size', attributeName: 'Size M', extraPrice: 0),
        ProductAttribute(attributeId: 14, productId: 4, attributeGroup: 'Size', attributeName: 'Size L', extraPrice: 8000),
        ProductAttribute(attributeId: 15, productId: 4, attributeGroup: 'Topping', attributeName: 'Thêm kem muối (+10k)', extraPrice: 10000),
      ],
    ),
    Product(
      productId: 5,
      categoryId: 2,
      categoryName: 'Espresso & Cà phê Ý',
      productName: 'Espresso Single Shot',
      price: 35000,
      unit: 'Tách',
      description: 'Chiết xuất áp suất cao từ hạt Arabica Cầu Đất, lớp Crema vàng óng mượt mà',
      imageUrl: 'espresso.jpg',
      isAvailable: true,
      isFeatured: false,
    ),
    Product(
      productId: 6,
      categoryId: 2,
      categoryName: 'Espresso & Cà phê Ý',
      productName: 'Cappuccino Ý Thượng Hạng',
      price: 49000,
      unit: 'Tách',
      description: 'Sự hòa quyện tuyệt vời giữa Espresso hảo hạng và bọt sữa tươi tạo hình Latte Art',
      imageUrl: 'cappuccino.jpg',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 16, productId: 6, attributeGroup: 'Size', attributeName: 'Nóng', extraPrice: 0),
        ProductAttribute(attributeId: 17, productId: 6, attributeGroup: 'Size', attributeName: 'Đá (+5k)', extraPrice: 5000),
      ],
    ),
    Product(
      productId: 7,
      categoryId: 3,
      categoryName: 'Trà trái cây & Trà sữa',
      productName: 'Trà Đào Cam Sả Tươi',
      price: 42000,
      unit: 'Ly',
      description: 'Trà đen hảo hạng ủ lạnh cùng đào miếng giòn ngọt, cam vàng tươi và hương sả nồng nàn',
      imageUrl: 'tra_dao_cam_sa.jpg',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 18, productId: 7, attributeGroup: 'Size', attributeName: 'Size M', extraPrice: 0),
        ProductAttribute(attributeId: 19, productId: 7, attributeGroup: 'Size', attributeName: 'Size L (+8k)', extraPrice: 8000),
        ProductAttribute(attributeId: 20, productId: 7, attributeGroup: 'Đường', attributeName: '50% đường', extraPrice: 0),
        ProductAttribute(attributeId: 21, productId: 7, attributeGroup: 'Topping', attributeName: 'Thêm đào miếng (+10k)', extraPrice: 10000),
      ],
    ),
    Product(
      productId: 8,
      categoryId: 3,
      categoryName: 'Trà trái cây & Trà sữa',
      productName: 'Trà Vải Hoa Lài Thanh Mát',
      price: 45000,
      unit: 'Ly',
      description: 'Trà lài thơm ngát kết hợp cùng trái vải tươi mọng nước và thạch giòn sần sật',
      imageUrl: 'tra_vai_lai.jpg',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 22, productId: 8, attributeGroup: 'Size', attributeName: 'Size M', extraPrice: 0),
        ProductAttribute(attributeId: 23, productId: 8, attributeGroup: 'Size', attributeName: 'Size L (+8k)', extraPrice: 8000),
        ProductAttribute(attributeId: 24, productId: 8, attributeGroup: 'Topping', attributeName: 'Thêm thạch nha đam (+8k)', extraPrice: 8000),
      ],
    ),
    Product(
      productId: 9,
      categoryId: 4,
      categoryName: 'Bánh ngọt & Tráng miệng',
      productName: 'Bánh Tiramisu Phô Mai Mascarpone',
      price: 38000,
      unit: 'Phần',
      description: 'Lớp bánh xốp thấm rượu cà phê xen kẽ phô mai Mascarpone mềm mịn và bột cacao',
      imageUrl: 'tiramisu.jpg',
      isAvailable: true,
      isFeatured: true,
    ),
    Product(
      productId: 10,
      categoryId: 4,
      categoryName: 'Bánh ngọt & Tráng miệng',
      productName: 'Bánh Croissant Bơ Tỏi Nướng',
      price: 32000,
      unit: 'Cái',
      description: 'Bánh sừng bò ngàn lớp thơm phức mùi bơ Pháp cao cấp và sốt bơ tỏi thơm lừng giòn rụm',
      imageUrl: 'croissant.jpg',
      isAvailable: true,
      isFeatured: false,
    ),
  ];

  /// Lấy danh sách sản phẩm có phân trang, lọc theo danh mục, tìm kiếm và sắp xếp.
  static Future<PagedProductResult> getProducts({
    int? categoryId,
    String? search,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (categoryId != null && categoryId > 0) {
        queryParams['categoryId'] = categoryId.toString();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (sortBy != null && sortBy.trim().isNotEmpty) {
        queryParams['sortBy'] = sortBy.trim();
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return PagedProductResult.fromMap(decoded);
      }
    } catch (_) {
      // Fallback offline
    }

    // Xử lý Offline fallback
    var filtered = _fallbackProducts.where((p) {
      if (categoryId != null && categoryId > 0 && p.categoryId != categoryId) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final kw = search.trim().toLowerCase();
        final matchName = p.productName.toLowerCase().contains(kw);
        final matchDesc = p.description?.toLowerCase().contains(kw) ?? false;
        if (!matchName && !matchDesc) return false;
      }
      return true;
    }).toList();

    // Sắp xếp fallback
    if (sortBy == 'price_asc') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (sortBy == 'price_desc') {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    } else if (sortBy == 'name_asc') {
      filtered.sort((a, b) => a.productName.compareTo(b.productName));
    }

    final totalItems = filtered.length;
    final totalPages = (totalItems / pageSize).ceil();
    final startIndex = (page - 1) * pageSize;
    final pagedData = (startIndex < totalItems)
        ? filtered.skip(startIndex).take(pageSize).toList()
        : <Product>[];

    return PagedProductResult(
      totalItems: totalItems,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
      data: pagedData,
    );
  }

  /// Lấy danh sách sản phẩm nổi bật
  static Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/featured?limit=$limit');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded.map((p) => Product.fromMap(p as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback
    }

    return _fallbackProducts.where((p) => p.isFeatured && p.isAvailable).take(limit).toList();
  }

  /// Lấy chi tiết sản phẩm kèm thuộc tính
  static Future<Product?> getProductById(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/$id');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return Product.fromMap(decoded);
      }
    } catch (_) {
      // Fallback
    }

    try {
      return _fallbackProducts.firstWhere((p) => p.productId == id);
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách sản phẩm liên quan cùng danh mục có phân trang
  static Future<PagedProductResult> getRelatedProducts(
    int id, {
    int page = 1,
    int pageSize = 6,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/related/$id?page=$page&pageSize=$pageSize');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return PagedProductResult.fromMap(decoded);
      }
    } catch (_) {
      // Fallback
    }

    Product? current;
    try {
      current = _fallbackProducts.firstWhere((p) => p.productId == id);
    } catch (_) {
      current = null;
    }

    final catId = current?.categoryId ?? 1;
    final related = _fallbackProducts.where((p) => p.categoryId == catId && p.productId != id).toList();
    final totalItems = related.length;
    final totalPages = (totalItems / pageSize).ceil();
    final startIndex = (page - 1) * pageSize;
    final pagedData = (startIndex < totalItems)
        ? related.skip(startIndex).take(pageSize).toList()
        : <Product>[];

    return PagedProductResult(
      totalItems: totalItems,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
      data: pagedData,
    );
  }

  /// Thêm món ăn mới kèm hỗ trợ multipart upload ảnh
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      if (imageBytes != null && imageBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageFileName ?? 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var created = Product.fromMap(jsonDecode(utf8.decode(response.bodyBytes)));
        return {'success': true, 'product': created, 'message': 'Thêm sản phẩm thành công'};
      } else {
        var errJson = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errJson['error'] ?? 'Thêm sản phẩm thất bại'};
      }
    } catch (e) {
      // Fallback thêm cục bộ vào RAM
      final newId = (_fallbackProducts.map((p) => p.productId).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final newProd = Product(
        productId: newId,
        categoryId: int.tryParse(data['CategoryId']?.toString() ?? '1') ?? 1,
        productName: data['ProductName']?.toString() ?? 'Món mới',
        price: double.tryParse(data['Price']?.toString() ?? '0') ?? 0.0,
        unit: data['Unit']?.toString() ?? 'Phần',
        description: data['Description']?.toString(),
        imageUrl: 'default_product.png',
        isAvailable: true,
        isFeatured: data['IsFeatured'] == true || data['IsFeatured'] == 'true',
      );
      _fallbackProducts.insert(0, newProd);
      return {'success': true, 'product': newProd, 'message': 'Đã thêm sản phẩm (chế độ dự phòng)'};
    }
  }

  /// Cập nhật món ăn kèm hỗ trợ upload ảnh mới
  static Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/$id'));
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      if (imageBytes != null && imageBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageFileName ?? 'product_update_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var updated = Product.fromMap(jsonDecode(utf8.decode(response.bodyBytes)));
        return {'success': true, 'product': updated, 'message': 'Cập nhật món thành công'};
      } else {
        var errJson = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errJson['error'] ?? 'Cập nhật món thất bại'};
      }
    } catch (e) {
      // Fallback cập nhật RAM
      final idx = _fallbackProducts.indexWhere((p) => p.productId == id);
      if (idx != -1) {
        final existing = _fallbackProducts[idx];
        _fallbackProducts[idx] = Product(
          productId: id,
          categoryId: int.tryParse(data['CategoryId']?.toString() ?? '') ?? existing.categoryId,
          categoryName: existing.categoryName,
          productName: data['ProductName']?.toString() ?? existing.productName,
          price: double.tryParse(data['Price']?.toString() ?? '') ?? existing.price,
          unit: data['Unit']?.toString() ?? existing.unit,
          description: data['Description']?.toString() ?? existing.description,
          imageUrl: existing.imageUrl,
          isAvailable: existing.isAvailable,
          isFeatured: data['IsFeatured'] != null ? (data['IsFeatured'] == true || data['IsFeatured'] == 'true') : existing.isFeatured,
          attributes: existing.attributes,
        );
        return {'success': true, 'product': _fallbackProducts[idx], 'message': 'Cập nhật món thành công (chế độ dự phòng)'};
      }
      return {'success': false, 'message': 'Không tìm thấy sản phẩm'};
    }
  }

  /// Xóa món ăn (kiểm tra ràng buộc đơn hàng)
  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    try {
      var response = await http
          .delete(Uri.parse('$baseUrl/$id'), headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        _fallbackProducts.removeWhere((p) => p.productId == id);
        return {'success': true, 'message': 'Đã xóa món thành công'};
      } else {
        var errJson = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errJson['error'] ?? 'Không thể xóa món ăn!',
        };
      }
    } catch (e) {
      _fallbackProducts.removeWhere((p) => p.productId == id);
      return {'success': true, 'message': 'Đã xóa món (chế độ dự phòng)'};
    }
  }
}

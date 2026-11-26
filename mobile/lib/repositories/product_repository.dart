import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';
import '../utils/database_helper.dart';

class ProductRepository {
  static String baseUrl = '${ApiConfig.baseUrl}/api/product';
  static Duration timeoutDuration = const Duration(seconds: 10);

  static String? _extractMessage(List<int> bodyBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map) {
        return (decoded['message'] ?? decoded['error'])?.toString();
      }
    } catch (_) {}
    return null;
  }

  static Product _parseProductResponse(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is Map) {
      final raw = decoded['data'] ?? decoded['product'] ?? decoded;
      return Product.fromMap(Map<String, dynamic>.from(raw as Map));
    }
    throw const FormatException('Dữ liệu sản phẩm không đúng định dạng');
  }

  /// Danh sách từ bộ nhớ đệm offline, có áp dụng ô tìm kiếm để không hiện lẫn món không liên quan.
  static Future<PagedProductResult?> _cachedResult(int? categoryId, String? search) async {
    final cached = await DatabaseHelper().getCachedProducts(categoryId: categoryId);
    if (cached.isEmpty) return null;
    var products = cached.map((e) => Product.fromMap(e)).toList();
    final kw = search?.trim().toLowerCase() ?? '';
    if (kw.isNotEmpty) {
      products = products.where((p) => p.productName.toLowerCase().contains(kw)).toList();
    }
    return PagedProductResult(
      data: products,
      totalItems: products.length,
      page: 1,
      pageSize: products.length,
      totalPages: 1,
      fromCache: true,
    );
  }

  /// Lấy danh sách sản phẩm phân trang kèm tìm kiếm, lọc danh mục và sắp xếp
  static Future<PagedProductResult> getProducts({
    int page = 1,
    int pageSize = 10,
    int? categoryId,
    String? search,
    String? sortBy,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (categoryId != null && categoryId > 0) queryParams['categoryId'] = categoryId.toString();
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (sortBy != null && sortBy.trim().isNotEmpty) queryParams['sortBy'] = sortBy.trim();

    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final res = await ApiConfig.get(uri).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        final result = PagedProductResult.fromMap(Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
        unawaited(DatabaseHelper().cacheProducts(result.data.map((p) => p.toMap()).toList()));
        return result;
      }
    } catch (_) {
      final cached = await _cachedResult(categoryId, search);
      if (cached != null) return cached;
      rethrow;
    }
    final cachedFallback = await _cachedResult(categoryId, search);
    if (cachedFallback != null) return cachedFallback;
    throw StateError('Không tải được danh sách sản phẩm');
  }

  /// Lấy danh sách món nổi bật / bán chạy
  static Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    try {
      final res = await ApiConfig.get(Uri.parse('$baseUrl/featured?limit=$limit')).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        final list = data.map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        unawaited(DatabaseHelper().cacheProducts(list.map((p) => p.toMap()).toList()));
        return list;
      }
    } catch (_) {
      final cached = await DatabaseHelper().getCachedProducts();
      if (cached.isNotEmpty) {
        return cached.map((e) => Product.fromMap(e)).take(limit).toList();
      }
      rethrow;
    }
    final cached = await DatabaseHelper().getCachedProducts();
    if (cached.isNotEmpty) {
      return cached.map((e) => Product.fromMap(e)).take(limit).toList();
    }
    throw StateError('Không tải được món nổi bật');
  }

  /// Lấy chi tiết sản phẩm kèm thuộc tính (Attributes / Topping / Size)
  static Future<Product> getProductDetail(int id) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tìm thấy sản phẩm (HTTP ${res.statusCode})');
    return _parseProductResponse(res.bodyBytes);
  }

  /// Lấy danh sách sản phẩm liên quan
  static Future<PagedProductResult> getRelatedProducts(
    int id, {
    int page = 1,
    int pageSize = 6,
  }) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/related/$id?page=$page&pageSize=$pageSize')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tải được sản phẩm liên quan (HTTP ${res.statusCode})');
    return PagedProductResult.fromMap(Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
  }

  /// Thêm món ăn mới kèm hỗ trợ multipart upload ảnh (đơn hoặc nhiều ảnh)
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
    List<Uint8List>? multipleImageBytes,
    List<String>? multipleFileNames,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(baseUrl));
      req.headers.addAll(await ApiConfig.authHeaders());
      data.forEach((key, value) {
        if (value != null) req.fields[key] = value.toString();
      });
      if (multipleImageBytes != null && multipleImageBytes.isNotEmpty) {
        for (int i = 0; i < multipleImageBytes.length; i++) {
          final name = (multipleFileNames != null && i < multipleFileNames.length) ? multipleFileNames[i] : 'product_$i.jpg';
          req.files.add(http.MultipartFile.fromBytes('files', multipleImageBytes[i], filename: name));
        }
      } else if (imageBytes != null && imageBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFileName ?? 'product.jpg'));
      }
      final stream = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'success': true,
          'product': _parseProductResponse(res.bodyBytes),
          'message': _extractMessage(res.bodyBytes) ?? 'Đã thêm sản phẩm',
        };
      }
      return {
        'success': false,
        'message': _extractMessage(res.bodyBytes) ?? 'Không thể tạo sản phẩm (HTTP ${res.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': ApiConfig.describeError(e, 'Thêm sản phẩm')};
    }
  }

  /// Cập nhật món ăn kèm hỗ trợ upload ảnh mới
  static Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
    List<Uint8List>? multipleImageBytes,
    List<String>? multipleFileNames,
  }) async {
    try {
      final req = http.MultipartRequest('PUT', Uri.parse('$baseUrl/$id'));
      req.headers.addAll(await ApiConfig.authHeaders());
      data.forEach((key, value) {
        if (value != null) req.fields[key] = value.toString();
      });
      if (multipleImageBytes != null && multipleImageBytes.isNotEmpty) {
        for (int i = 0; i < multipleImageBytes.length; i++) {
          final name = (multipleFileNames != null && i < multipleFileNames.length) ? multipleFileNames[i] : 'product_$i.jpg';
          req.files.add(http.MultipartFile.fromBytes('files', multipleImageBytes[i], filename: name));
        }
      } else if (imageBytes != null && imageBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFileName ?? 'product.jpg'));
      }
      final stream = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        return {
          'success': true,
          'product': _parseProductResponse(res.bodyBytes),
          'message': _extractMessage(res.bodyBytes) ?? 'Đã cập nhật sản phẩm',
        };
      }
      return {
        'success': false,
        'message': _extractMessage(res.bodyBytes) ?? 'Không thể sửa sản phẩm (HTTP ${res.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': ApiConfig.describeError(e, 'Cập nhật sản phẩm')};
    }
  }

  /// Upload nhiều ảnh vào bộ sưu tập món ăn
  static Future<Map<String, dynamic>> uploadProductImages(
    int productId,
    List<Uint8List> imageBytesList, {
    List<String>? fileNames,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/$productId/upload-images'));
      req.headers.addAll(await ApiConfig.authHeaders());
      for (int i = 0; i < imageBytesList.length; i++) {
        final name = (fileNames != null && i < fileNames.length) ? fileNames[i] : 'image_$i.jpg';
        req.files.add(http.MultipartFile.fromBytes('files', imageBytesList[i], filename: name));
      }
      final stream = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        return {'success': true, ...Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map)};
      }
      return {'success': false, 'message': _extractMessage(res.bodyBytes) ?? 'Lỗi upload ảnh (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không thể upload ảnh: $e'};
    }
  }

  /// Xóa 1 ảnh khỏi bộ sưu tập của món
  static Future<Map<String, dynamic>> deleteProductImage(int productId, String imageName) async {
    try {
      final uri = Uri.parse('$baseUrl/$productId/images').replace(queryParameters: {'imageName': imageName});
      final res = await ApiConfig.delete(uri).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return {'success': true, ...Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map)};
      }
      return {'success': false, 'message': _extractMessage(res.bodyBytes) ?? 'Không thể xóa ảnh (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xóa ảnh: $e'};
    }
  }

  /// Xóa món ăn (kiểm tra ràng buộc đơn hàng)
  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    try {
      final res = await ApiConfig.delete(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
      final serverMsg = _extractMessage(res.bodyBytes);
      return {
        'success': res.statusCode == 200,
        'message': serverMsg ?? (res.statusCode == 200 ? 'Đã xóa sản phẩm' : 'Không thể xóa sản phẩm (HTTP ${res.statusCode})'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể xóa sản phẩm: $e'};
    }
  }

  /// Bật/tắt trạng thái hết món 1-chạm (PUT /api/product/{id}/toggle-availability)
  static Future<Map<String, dynamic>> toggleAvailability(int productId) async {
    try {
      final res = await ApiConfig.put(
        Uri.parse('$baseUrl/$productId/toggle-availability'),
      ).timeout(timeoutDuration);

      final data = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? (res.statusCode == 200 ? 'Thành công' : 'Thất bại'),
        'isAvailable': data['isAvailable'] as bool?,
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể cập nhật trạng thái món: $e'};
    }
  }

  /// Thêm thuộc tính Size / Topping cho món (POST /api/product/{id}/attributes)
  static Future<Map<String, dynamic>> addAttribute({
    required int productId,
    required String attributeGroup,
    required String attributeName,
    double extraPrice = 0,
    bool isRequired = false,
  }) async {
    try {
      final res = await ApiConfig.post(
        Uri.parse('$baseUrl/$productId/attributes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'attributeGroup': attributeGroup,
          'attributeName': attributeName,
          'extraPrice': extraPrice,
          'isRequired': isRequired,
        }),
      ).timeout(timeoutDuration);
      final data = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? (res.statusCode == 200 ? 'Đã thêm thuộc tính' : 'Thất bại'),
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi thêm thuộc tính: $e'};
    }
  }

  /// Xóa thuộc tính Size / Topping (DELETE /api/product/attributes/{attrId})
  static Future<Map<String, dynamic>> deleteAttribute(int attrId) async {
    try {
      final res = await ApiConfig.delete(
        Uri.parse('$baseUrl/attributes/$attrId'),
      ).timeout(timeoutDuration);
      final data = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? (res.statusCode == 200 ? 'Đã xóa thuộc tính' : 'Thất bại'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xóa thuộc tính: $e'};
    }
  }
}

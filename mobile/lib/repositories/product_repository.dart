import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';

class ProductRepository {
  static String baseUrl = '${ApiConfig.baseUrl}/api/product';
  static Duration timeoutDuration = const Duration(seconds: 10);

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

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final res = await http.get(uri).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tải được danh sách sản phẩm (HTTP ${res.statusCode})');
    return PagedProductResult.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Lấy danh sách món nổi bật / bán chạy
  static Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    final res = await http.get(Uri.parse('$baseUrl/featured?limit=$limit')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tải được món nổi bật (HTTP ${res.statusCode})');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return data.map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Lấy chi tiết sản phẩm kèm thuộc tính (Attributes / Topping / Size)
  static Future<Product> getProductDetail(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tìm thấy sản phẩm (HTTP ${res.statusCode})');
    return Product.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Lấy danh sách sản phẩm liên quan
  static Future<PagedProductResult> getRelatedProducts(
    int id, {
    int page = 1,
    int pageSize = 6,
  }) async {
    final res = await http.get(Uri.parse('$baseUrl/related/$id?page=$page&pageSize=$pageSize')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tải được sản phẩm liên quan (HTTP ${res.statusCode})');
    return PagedProductResult.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
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
      final stream = await req.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'product': Product.fromMap(jsonDecode(utf8.decode(res.bodyBytes))), 'message': 'Đã thêm sản phẩm'};
      }
      return {'success': false, 'message': 'Không thể tạo sản phẩm (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không thể thêm sản phẩm: $e'};
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
      final stream = await req.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        return {'success': true, 'product': Product.fromMap(jsonDecode(utf8.decode(res.bodyBytes))), 'message': 'Đã cập nhật sản phẩm'};
      }
      return {'success': false, 'message': 'Không thể sửa sản phẩm (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không thể cập nhật sản phẩm: $e'};
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
      for (int i = 0; i < imageBytesList.length; i++) {
        final name = (fileNames != null && i < fileNames.length) ? fileNames[i] : 'image_$i.jpg';
        req.files.add(http.MultipartFile.fromBytes('files', imageBytesList[i], filename: name));
      }
      final stream = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        return {'success': true, ...jsonDecode(utf8.decode(res.bodyBytes))};
      }
      return {'success': false, 'message': 'Lỗi upload ảnh (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không thể upload ảnh: $e'};
    }
  }

  /// Xóa 1 ảnh khỏi bộ sưu tập của món
  static Future<Map<String, dynamic>> deleteProductImage(int productId, String imageName) async {
    try {
      final uri = Uri.parse('$baseUrl/$productId/images').replace(queryParameters: {'imageName': imageName});
      final res = await http.delete(uri).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return {'success': true, ...jsonDecode(utf8.decode(res.bodyBytes))};
      }
      return {'success': false, 'message': 'Không thể xóa ảnh (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xóa ảnh: $e'};
    }
  }

  /// Xóa món ăn (kiểm tra ràng buộc đơn hàng)
  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
      return {'success': res.statusCode == 200, 'message': res.statusCode == 200 ? 'Đã xóa sản phẩm' : 'Không thể xóa sản phẩm (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không thể xóa sản phẩm: $e'};
    }
  }
}

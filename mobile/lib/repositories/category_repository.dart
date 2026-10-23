import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../config/api_config.dart';

class CategoryRepository {
  static String baseUrl = ApiConfig.baseUrl + '/api/category';
  static Duration timeoutDuration = const Duration(seconds: 4);

  static Future<List<Category>?> getCategories() async {
    final res = await http.get(Uri.parse(baseUrl)).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Danh mục chưa tải được (HTTP ${res.statusCode})');
    final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.map((e) => Category.fromMap(e)).toList();
  }

  static Future<Category?> getCategoryById(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw StateError('Danh mục chưa tải được (HTTP ${res.statusCode})');
    return Category.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(baseUrl));
      data.forEach((key, value) {
        if (value != null) req.fields[key] = value.toString();
      });
      if (imageBytes != null && imageBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFileName ?? 'category.png'));
      }
      final stream = await req.send().timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'category': Category.fromMap(jsonDecode(utf8.decode(res.bodyBytes))), 'message': 'Đã thêm danh mục'};
      }
      return {'success': false, 'message': 'Máy chủ từ chối tạo danh mục (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không lưu được danh mục: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateCategory(
    int id,
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      final req = http.MultipartRequest('PUT', Uri.parse('$baseUrl/$id'));
      data.forEach((key, value) {
        if (value != null) req.fields[key] = value.toString();
      });
      if (imageBytes != null && imageBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFileName ?? 'category.png'));
      }
      final stream = await req.send().timeout(const Duration(seconds: 12));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        return {'success': true, 'category': Category.fromMap(jsonDecode(utf8.decode(res.bodyBytes))), 'message': 'Đã sửa danh mục'};
      }
      return {'success': false, 'message': 'Máy chủ từ chối cập nhật (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không cập nhật được danh mục: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
      return {'success': res.statusCode == 200, 'message': res.statusCode == 200 ? 'Đã xóa danh mục' : 'Xóa danh mục thất bại (HTTP ${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Không thể xóa danh mục: $e'};
    }
  }
}

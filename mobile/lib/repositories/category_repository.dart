import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/category.dart';
import '../utils/database_helper.dart';

class CategoryRepository {
  static String baseUrl = '${ApiConfig.baseUrl}/api/category';
  static Duration timeoutDuration = const Duration(seconds: 6);

  static String? _extractMessage(List<int> bodyBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map) {
        return (decoded['message'] ?? decoded['error'])?.toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Category>?> getCategories({bool includeInactive = false}) async {
    try {
      final uri = includeInactive
          ? Uri.parse(baseUrl).replace(queryParameters: {'includeInactive': 'true'})
          : Uri.parse(baseUrl);
      final res = await ApiConfig.get(uri).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        final cats = data.map((e) => Category.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        if (!includeInactive) {
          unawaited(DatabaseHelper().cacheCategories(cats.map((c) => c.toMap()).toList()));
        }
        return cats;
      }
    } catch (_) {
      final cached = await DatabaseHelper().getCachedCategories();
      if (cached.isNotEmpty) {
        return cached.map((e) => Category.fromMap(e)).toList();
      }
      rethrow;
    }
    final cached = await DatabaseHelper().getCachedCategories();
    if (cached.isNotEmpty) {
      return cached.map((e) => Category.fromMap(e)).toList();
    }
    throw StateError('Danh mục chưa tải được');
  }

  static Future<Category?> getCategoryById(int id) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw StateError('Danh mục chưa tải được (HTTP ${res.statusCode})');
    return Category.fromMap(Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
  }

  static Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(baseUrl));
      req.headers.addAll(await ApiConfig.authHeaders());
      data.forEach((key, value) {
        if (value != null) req.fields[key] = value.toString();
      });
      if (imageBytes != null && imageBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFileName ?? 'category.png'));
      }
      final stream = await req.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final map = decoded is Map && decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'])
            : Map<String, dynamic>.from(decoded as Map);
        return {'success': true, 'category': Category.fromMap(map), 'message': 'Đã thêm danh mục'};
      }
      return {
        'success': false,
        'message': _extractMessage(res.bodyBytes) ?? 'Máy chủ từ chối tạo danh mục (HTTP ${res.statusCode})',
      };
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
      req.headers.addAll(await ApiConfig.authHeaders());
      data.forEach((key, value) {
        if (value != null) req.fields[key] = value.toString();
      });
      if (imageBytes != null && imageBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFileName ?? 'category.png'));
      }
      final stream = await req.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(stream);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final map = decoded is Map && decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'])
            : Map<String, dynamic>.from(decoded as Map);
        return {'success': true, 'category': Category.fromMap(map), 'message': 'Đã sửa danh mục'};
      }
      return {
        'success': false,
        'message': _extractMessage(res.bodyBytes) ?? 'Máy chủ từ chối cập nhật (HTTP ${res.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không cập nhật được danh mục: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      final res = await ApiConfig.delete(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
      final serverMsg = _extractMessage(res.bodyBytes);
      return {
        'success': res.statusCode == 200,
        'message': serverMsg ?? (res.statusCode == 200 ? 'Đã xóa danh mục' : 'Xóa danh mục thất bại (HTTP ${res.statusCode})'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể xóa danh mục: $e'};
    }
  }
}

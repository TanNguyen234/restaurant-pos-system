import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/category.dart';

class CategoryRepository {
  static String baseUrl = "http://localhost:5138/api/category";
  static Duration timeoutDuration = const Duration(seconds: 4);

  // Fallback mock categories matching RestaurantPosDb.sql
  static final List<Category> _fallbackCategories = [
    Category(
      id: 1,
      name: 'Cà phê truyền thống',
      title: 'Cà phê phin Robusta Đắk Lắk',
      description: 'Đậm đà hương vị nguyên bản cà phê rang mộc Tây Nguyên',
      icon: 'traditional_coffee.png',
      sortOrder: 1,
      isActive: true,
    ),
    Category(
      id: 2,
      name: 'Espresso & Cà phê Ý',
      title: 'Cà phê pha máy chuẩn vị Ý',
      description: 'Hương thơm nồng nàn từ hạt Arabica Cầu Đất nguyên chất',
      icon: 'espresso_italy.png',
      sortOrder: 2,
      isActive: true,
    ),
    Category(
      id: 3,
      name: 'Trà trái cây & Trà sữa',
      title: 'Trà thanh nhiệt hoa quả tươi',
      description: 'Trà đào, trà vải, trà lài kết hợp trái cây tươi giòn ngọt',
      icon: 'fruit_tea.png',
      sortOrder: 3,
      isActive: true,
    ),
    Category(
      id: 4,
      name: 'Bánh ngọt & Tráng miệng',
      title: 'Bánh Âu nướng tươi trong ngày',
      description: 'Tiramisu béo ngậy, Croissant ngàn lớp thơm lừng bơ Pháp',
      icon: 'bakery_dessert.png',
      sortOrder: 4,
      isActive: true,
    ),
    Category(
      id: 5,
      name: 'Điểm tâm & Món ăn nhẹ',
      title: 'Món ăn sáng và ăn vặt',
      description: 'Bánh mì chảo, xúc xích Đức nướng và khoai tây chiên giòn',
      icon: 'breakfast_snack.png',
      sortOrder: 5,
      isActive: true,
    ),
  ];

  static Future<List<Category>?> getCategories() async {
    try {
      var response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((p) => Category.fromMap(p)).toList();
      }
    } catch (_) {
      // Fallback
    }
    return List<Category>.from(_fallbackCategories);
  }

  static Future<Category?> getCategoryById(int id) async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        return Category.fromMap(data);
      }
    } catch (_) {
      // Fallback
    }

    try {
      return _fallbackCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> createCategory(
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
          filename: imageFileName ?? 'category_${DateTime.now().millisecondsSinceEpoch}.png',
        ));
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var created = Category.fromMap(jsonDecode(utf8.decode(response.bodyBytes)));
        return {'success': true, 'category': created, 'message': 'Thêm danh mục thành công'};
      } else {
        var errJson = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errJson['error'] ?? 'Thêm danh mục thất bại'};
      }
    } catch (e) {
      final newId = (_fallbackCategories.map((c) => c.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final newCat = Category(
        id: newId,
        name: data['Name']?.toString() ?? 'Danh mục mới',
        title: data['Title']?.toString() ?? '',
        description: data['Description']?.toString() ?? '',
        icon: 'default_category.png',
        sortOrder: int.tryParse(data['SortOrder']?.toString() ?? '0') ?? 0,
        isActive: true,
      );
      _fallbackCategories.add(newCat);
      return {'success': true, 'category': newCat, 'message': 'Đã thêm danh mục (chế độ dự phòng)'};
    }
  }

  static Future<Map<String, dynamic>> updateCategory(
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
          filename: imageFileName ?? 'category_update_${DateTime.now().millisecondsSinceEpoch}.png',
        ));
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var updated = Category.fromMap(jsonDecode(utf8.decode(response.bodyBytes)));
        return {'success': true, 'category': updated, 'message': 'Cập nhật danh mục thành công'};
      } else {
        var errJson = jsonDecode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errJson['error'] ?? 'Cập nhật danh mục thất bại'};
      }
    } catch (e) {
      final idx = _fallbackCategories.indexWhere((c) => c.id == id);
      if (idx != -1) {
        final existing = _fallbackCategories[idx];
        _fallbackCategories[idx] = Category(
          id: id,
          name: data['Name']?.toString() ?? existing.name,
          title: data['Title']?.toString() ?? existing.title,
          description: data['Description']?.toString() ?? existing.description,
          icon: existing.icon,
          sortOrder: int.tryParse(data['SortOrder']?.toString() ?? '') ?? existing.sortOrder,
          isActive: true,
        );
        return {'success': true, 'category': _fallbackCategories[idx], 'message': 'Cập nhật danh mục thành công (chế độ dự phòng)'};
      }
      return {'success': false, 'message': 'Không tìm thấy danh mục'};
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      var response = await http
          .delete(Uri.parse('$baseUrl/$id'), headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        _fallbackCategories.removeWhere((c) => c.id == id);
        return {'success': true, 'message': 'Đã xóa danh mục thành công'};
      } else {
        var errJson = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errJson['error'] ?? 'Không thể xóa danh mục vì vẫn còn sản phẩm!',
        };
      }
    } catch (e) {
      _fallbackCategories.removeWhere((c) => c.id == id);
      return {'success': true, 'message': 'Đã xóa danh mục (chế độ dự phòng)'};
    }
  }
}

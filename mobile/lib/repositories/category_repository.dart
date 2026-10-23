import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/category.dart';

class CategoryRepository {
  // Platform-aware default host: 10.0.2.2:5138 for Android emulator, localhost:5138 for Windows/Web/Desktop
  static String defaultHost =
      (!kIsWeb && Platform.isAndroid) ? '10.0.2.2:5138' : 'localhost:5138';

  // URL trỏ tới ASP.NET Core 10 Web API
  static String baseUrl = "http://$defaultHost/api/category";
  static Duration timeoutDuration = const Duration(seconds: 4);

  static Future<List<Category>?> getCategories() async {
    try {
      var rs = await http.get(
        Uri.parse(baseUrl),
        headers: {'content-type': "application/json"},
      ).timeout(timeoutDuration);

      if (rs.statusCode == 200) {
        List<dynamic> data = jsonDecode(rs.body);
        return data.map((p) => Category.fromMap(p)).toList();
      }
    } catch (_) {
      // Bỏ qua lỗi kết nối hoặc xử lý thông báo ngoại lệ
    }
    return null;
  }
}

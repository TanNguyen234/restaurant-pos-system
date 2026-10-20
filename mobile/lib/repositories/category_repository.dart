import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';

class CategoryRepository {
  // URL trỏ tới ASP.NET Core 10 Web API
  // Đối với máy ảo Android dùng 10.0.2.2, đối với Windows/Web/Máy thật dùng localhost hoặc IP LAN
  static const String baseUrl = "http://localhost:5138/api/category";

  static Future<List<Category>?> getCategories() async {
    try {
      var rs = await http.get(
        Uri.parse(baseUrl),
        headers: {'content-type': "application/json"},
      );

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

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/area.dart';
import '../models/dining_table.dart';

class TableRepository {
  // Platform-aware default host: 10.0.2.2:5138 for Android emulator, localhost:5138 for Windows/Web/Desktop
  static String defaultHost =
      (!kIsWeb && Platform.isAndroid) ? '10.0.2.2:5138' : 'localhost:5138';

  // Base URL pointing to backend Table API
  static String baseUrl = "http://$defaultHost/api/table";
  static Duration timeoutDuration = const Duration(seconds: 4);

  /// Lấy danh sách tất cả các khu vực (GET /api/table/areas)
  static Future<List<Area>> getAreas() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/areas'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Area.fromMap(item)).toList();
      } else {
        throw Exception(
            'Lỗi máy chủ khi tải danh sách khu vực (HTTP ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách khu vực: $e');
    }
  }

  /// Lấy danh sách bàn theo khu vực (GET /api/table/by-area/{areaId})
  static Future<List<DiningTable>> getTablesByArea(int areaId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/by-area/$areaId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => DiningTable.fromMap(item)).toList();
      } else {
        throw Exception(
            'Lỗi máy chủ khi tải danh sách bàn theo khu vực (HTTP ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách bàn theo khu vực: $e');
    }
  }

  /// Lấy toàn bộ danh sách bàn (GET /api/table)
  static Future<List<DiningTable>> getAllTables() async {
    try {
      final response = await http
          .get(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => DiningTable.fromMap(item)).toList();
      } else {
        throw Exception(
            'Lỗi máy chủ khi tải toàn bộ danh sách bàn (HTTP ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Không thể tải toàn bộ danh sách bàn: $e');
    }
  }

  /// Cập nhật trạng thái bàn (PUT /api/table/{id}/status)
  /// Trạng thái: 0: Trống, 1: Có khách, 2: Chờ phục vụ / Đã đặt trước
  /// Trả về true NẾU VÀ CHỈ NẾU backend server phản hồi HTTP 200 OK
  static Future<bool> updateStatus(int tableId, int newStatus) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/$tableId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(timeoutDuration);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Chuyển bàn từ bàn nguồn sang bàn đích (POST /api/table/transfer)
  /// Trả về true NẾU VÀ CHỈ NẾU backend server phản hồi HTTP 200 OK
  static Future<bool> transferTable(int fromTableId, int toTableId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transfer'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fromTableId': fromTableId,
              'toTableId': toTableId,
            }),
          )
          .timeout(timeoutDuration);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import '../models/area.dart';
import '../models/dining_table.dart';

class TableRepository {
  // Base URL pointing to backend Table API
  static String baseUrl = ApiConfig.baseUrl + '/api/table';
  static Duration timeoutDuration = const Duration(seconds: 4);

  // In-memory fallback cache when backend is offline


  /// Lấy danh sách tất cả các khu vực (GET /api/table/areas)
  static Future<List<Area>> getAreas() async {
    final response = await ApiConfig.get(Uri.parse('$baseUrl/areas')).timeout(timeoutDuration);
    if (response.statusCode != 200) throw StateError('Tải khu vực thất bại (HTTP ${response.statusCode})');
    final List<dynamic> items = jsonDecode(utf8.decode(response.bodyBytes));
    return items.map((e) => Area.fromMap(e)).toList();
  }

  /// Lấy danh sách bàn theo khu vực (GET /api/table/by-area/{areaId})
  static Future<List<DiningTable>> getTablesByArea(int areaId) async {
    final response = await ApiConfig.get(Uri.parse('$baseUrl/by-area/$areaId')).timeout(timeoutDuration);
    if (response.statusCode != 200) throw StateError('Tải bàn thất bại (HTTP ${response.statusCode})');
    final List<dynamic> items = jsonDecode(utf8.decode(response.bodyBytes));
    return items.map((e) => DiningTable.fromMap(e)).toList();
  }

  /// Lấy toàn bộ danh sách bàn (GET /api/table)
  static Future<List<DiningTable>> getAllTables() async {
    final response = await ApiConfig.get(Uri.parse(baseUrl)).timeout(timeoutDuration);
    if (response.statusCode != 200) throw StateError('Tải bàn thất bại (HTTP ${response.statusCode})');
    final List<dynamic> items = jsonDecode(utf8.decode(response.bodyBytes));
    return items.map((e) => DiningTable.fromMap(e)).toList();
  }

  /// Cập nhật trạng thái bàn (PUT /api/table/{id}/status)
  /// Trạng thái: 0: Trống, 1: Có khách, 2: Chờ phục vụ / Đã đặt trước
  static Future<bool> updateStatus(int tableId, int newStatus) async {
    try {
      final response = await ApiConfig.put(Uri.parse('$baseUrl/$tableId/status'),headers: {'Content-Type': 'application/json'},body:jsonEncode({'status':newStatus})).timeout(timeoutDuration);
      return response.statusCode == 200;
    } catch (_) { return false; }
  }

  /// Chuyển bàn từ bàn nguồn sang bàn đích (POST /api/table/transfer)
  static Future<bool> transferTable(int fromTableId, int toTableId) async {
    try {
      final response = await ApiConfig.post(Uri.parse('$baseUrl/transfer'), headers: {'Content-Type': 'application/json'},
       body:jsonEncode({'fromTableId':fromTableId,'toTableId':toTableId})).timeout(timeoutDuration);
      return response.statusCode == 200;
    } catch (_) { return false; }
  }
}

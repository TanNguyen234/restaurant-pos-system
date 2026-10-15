import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/area.dart';
import '../models/dining_table.dart';

class TableRepository {
  // Base URL pointing to backend Table API
  static String baseUrl = "http://localhost:5138/api/table";
  static Duration timeoutDuration = const Duration(seconds: 4);

  // In-memory fallback cache when backend is offline
  static final List<Area> _fallbackAreas = [
    Area(
      id: 1,
      name: 'Tầng 1 - Phòng lạnh',
      description: 'Khu vực máy lạnh trong nhà, gần quầy pha chế',
      sortOrder: 1,
      isActive: true,
    ),
    Area(
      id: 2,
      name: 'Tầng 2 - Ban công',
      description: 'Khu vực ngoài trời thoáng mát hướng phố',
      sortOrder: 2,
      isActive: true,
    ),
    Area(
      id: 3,
      name: 'Sân vườn nhiệt đới',
      description: 'Không gian xanh mát sân vườn, hồ cá koi',
      sortOrder: 3,
      isActive: true,
    ),
    Area(
      id: 4,
      name: 'Phòng VIP',
      description: 'Phòng tiệc máy lạnh riêng tư, có sofa cao cấp',
      sortOrder: 4,
      isActive: true,
    ),
  ];

  static final List<DiningTable> _fallbackTables = [
    // Tầng 1
    DiningTable(id: 1, areaId: 1, name: 'Bàn T1-01', capacity: 2, status: 0),
    DiningTable(id: 2, areaId: 1, name: 'Bàn T1-02', capacity: 4, status: 1, currentOrderId: 101),
    DiningTable(id: 3, areaId: 1, name: 'Bàn T1-03', capacity: 4, status: 0),
    DiningTable(id: 4, areaId: 1, name: 'Bàn T1-04', capacity: 6, status: 2),
    DiningTable(id: 5, areaId: 1, name: 'Bàn T1-05', capacity: 4, status: 1, currentOrderId: 102),
    DiningTable(id: 6, areaId: 1, name: 'Bàn T1-06', capacity: 8, status: 0),

    // Tầng 2
    DiningTable(id: 7, areaId: 2, name: 'Bàn T2-01', capacity: 2, status: 0),
    DiningTable(id: 8, areaId: 2, name: 'Bàn T2-02', capacity: 4, status: 1, currentOrderId: 103),
    DiningTable(id: 9, areaId: 2, name: 'Bàn T2-03', capacity: 4, status: 0),
    DiningTable(id: 10, areaId: 2, name: 'Bàn T2-04', capacity: 6, status: 0),

    // Sân vườn
    DiningTable(id: 11, areaId: 3, name: 'Vườn V-01', capacity: 4, status: 0),
    DiningTable(id: 12, areaId: 3, name: 'Vườn V-02', capacity: 6, status: 1, currentOrderId: 104),
    DiningTable(id: 13, areaId: 3, name: 'Vườn V-03', capacity: 4, status: 2),
    DiningTable(id: 14, areaId: 3, name: 'Vườn V-04', capacity: 10, status: 0),

    // Phòng VIP
    DiningTable(id: 15, areaId: 4, name: 'VIP Hoàng Gia', capacity: 12, status: 1, currentOrderId: 105),
    DiningTable(id: 16, areaId: 4, name: 'VIP Dạ Yến', capacity: 8, status: 0),
    DiningTable(id: 17, areaId: 4, name: 'VIP Doanh Nhân', capacity: 16, status: 2),
  ];

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
        final areas = data.map((item) => Area.fromMap(item)).toList();
        if (areas.isNotEmpty) return areas;
      }
    } catch (_) {
      // Backend offline or unreachable, fallback to default seed areas
    }
    return List<Area>.from(_fallbackAreas);
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
      }
    } catch (_) {
      // Backend offline
    }

    return _fallbackTables.where((t) => t.areaId == areaId).toList();
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
      }
    } catch (_) {
      // Backend offline
    }

    return List<DiningTable>.from(_fallbackTables);
  }

  /// Cập nhật trạng thái bàn (PUT /api/table/{id}/status)
  /// Trạng thái: 0: Trống, 1: Có khách, 2: Chờ phục vụ / Đã đặt trước
  static Future<bool> updateStatus(int tableId, int newStatus) async {
    bool remoteSuccess = false;
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/$tableId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        remoteSuccess = true;
      }
    } catch (_) {
      // Backend offline, apply fallback locally
    }

    // Always synchronize local fallback cache
    final index = _fallbackTables.indexWhere((t) => t.id == tableId);
    if (index != -1) {
      final current = _fallbackTables[index];
      _fallbackTables[index] = current.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    }

    return remoteSuccess || index != -1;
  }

  /// Chuyển bàn từ bàn nguồn sang bàn đích (POST /api/table/transfer)
  static Future<bool> transferTable(int fromTableId, int toTableId) async {
    bool remoteSuccess = false;
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

      if (response.statusCode == 200) {
        remoteSuccess = true;
      }
    } catch (_) {
      // Backend offline
    }

    // Synchronize local fallback cache
    final fromIdx = _fallbackTables.indexWhere((t) => t.id == fromTableId);
    final toIdx = _fallbackTables.indexWhere((t) => t.id == toTableId);

    if (fromIdx != -1 && toIdx != -1) {
      final fromTable = _fallbackTables[fromIdx];
      final toTable = _fallbackTables[toIdx];

      // To table takes from table's status and order
      _fallbackTables[toIdx] = toTable.copyWith(
        status: fromTable.status,
        currentOrderId: fromTable.currentOrderId,
        updatedAt: DateTime.now(),
      );

      // From table is now available (0)
      _fallbackTables[fromIdx] = fromTable.copyWith(
        status: 0,
        currentOrderId: null,
        updatedAt: DateTime.now(),
      );
    }

    return remoteSuccess || (fromIdx != -1 && toIdx != -1);
  }
}

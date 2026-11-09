import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/area.dart';
import '../models/dining_table.dart';

class TableRepository {
  static String? _baseUrl;
  /// Base URL pointing dynamically to backend Table API
  static String get baseUrl => _baseUrl ?? '${ApiConfig.baseUrl}/api/table';
  static set baseUrl(String value) => _baseUrl = value;
  static Duration timeoutDuration = const Duration(seconds: 4);

  static Future<Map<String, String>> _getHeaders() async {
    final auth = await ApiConfig.authHeaders();
    return {
      'Content-Type': 'application/json',
      ...auth,
    };
  }

  /// Lấy danh sách tất cả các khu vực (GET /api/table/areas)
  static Future<List<Area>> getAreas() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/areas'),
            headers: headers,
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
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/by-area/$areaId'),
            headers: headers,
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
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(baseUrl),
            headers: headers,
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
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/$tableId/status'),
            headers: headers,
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
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/transfer'),
            headers: headers,
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

  /// Gộp bàn từ bàn nguồn vào bàn đích (POST /api/table/merge)
  static Future<Map<String, dynamic>> mergeTables(int fromTableId, int toTableId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/merge'),
            headers: headers,
            body: jsonEncode({
              'fromTableId': fromTableId,
              'toTableId': toTableId,
            }),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? (response.statusCode == 200 ? 'Gộp bàn thành công' : 'Gộp bàn thất bại'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Tách món ăn từ bàn nguồn sang bàn đích trống mới (POST /api/table/split)
  static Future<Map<String, dynamic>> splitTable(
      int fromTableId, int toTableId, List<int> orderDetailIds) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/split'),
            headers: headers,
            body: jsonEncode({
              'fromTableId': fromTableId,
              'toTableId': toTableId,
              'orderDetailIds': orderDetailIds,
            }),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? (response.statusCode == 200 ? 'Tách bàn thành công' : 'Tách bàn thất bại'),
        'newOrderId': data['newOrderId'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Đặt bàn trước (POST /api/table/reserve)
  static Future<Map<String, dynamic>> reserveTable({
    required int tableId,
    required String customerName,
    required String phoneNumber,
    int guestCount = 2,
    DateTime? arrivalTime,
    double? depositAmount,
    String? note,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/reserve'),
            headers: headers,
            body: jsonEncode({
              'tableId': tableId,
              'customerName': customerName,
              'phoneNumber': phoneNumber,
              'guestCount': guestCount,
              'arrivalTime': (arrivalTime ?? DateTime.now().add(const Duration(hours: 2))).toIso8601String(),
              'depositAmount': depositAmount ?? 0,
              'note': note,
            }),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? (response.statusCode == 200 ? 'Đặt bàn thành công' : 'Đặt bàn thất bại'),
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Lấy danh sách đặt bàn (GET /api/table/reservations)
  static Future<List<Map<String, dynamic>>> getReservations({DateTime? fromDate}) async {
    try {
      final headers = await _getHeaders();
      final uri = fromDate != null
          ? Uri.parse('$baseUrl/reservations?fromDate=${fromDate.toIso8601String()}')
          : Uri.parse('$baseUrl/reservations');

      final response = await http.get(uri, headers: headers).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final List<dynamic> list = res['data'] ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Khách đến nhận bàn đã đặt trước (PUT /api/table/reservation/{id}/check-in)
  static Future<Map<String, dynamic>> checkInReservation(int reservationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/reservation/$reservationId/check-in'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? (response.statusCode == 200 ? 'Nhận bàn thành công' : 'Nhận bàn thất bại'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Hủy đặt bàn (DELETE /api/table/reservation/{id})
  static Future<Map<String, dynamic>> cancelReservation(int reservationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/reservation/$reservationId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? (response.statusCode == 200 ? 'Hủy đặt bàn thành công' : 'Hủy đặt bàn thất bại'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Lấy thông tin đơn hàng hiện tại của bàn (GET /api/order/by-table/{tableId})
  static Future<Map<String, dynamic>?> getActiveOrderByTable(int tableId) async {
    try {
      final headers = await _getHeaders();
      final orderHost = baseUrl.replaceAll('/api/table', '/api/order');
      final response = await http
          .get(
            Uri.parse('$orderHost/by-table/$tableId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['hasActiveOrder'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tạo bàn mới (POST /api/table)
  static Future<Map<String, dynamic>> createTable({
    required int areaId,
    required String tableName,
    int capacity = 4,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: headers,
            body: jsonEncode({
              'areaId': areaId,
              'tableName': tableName,
              'capacity': capacity,
            }),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Tạo bàn thành công' : 'Thất bại'),
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Cập nhật thông tin bàn (PUT /api/table/{id})
  static Future<Map<String, dynamic>> updateTable(
    int tableId, {
    int? areaId,
    String? tableName,
    int? capacity,
    int? status,
  }) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> updateData = {};
      if (areaId != null) updateData['areaId'] = areaId;
      if (tableName != null) updateData['tableName'] = tableName;
      if (capacity != null) updateData['capacity'] = capacity;
      if (status != null) updateData['status'] = status;

      final response = await http
          .put(
            Uri.parse('$baseUrl/$tableId'),
            headers: headers,
            body: jsonEncode(updateData),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Cập nhật bàn thành công' : 'Thất bại'),
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Xóa bàn ăn (DELETE /api/table/{id})
  static Future<Map<String, dynamic>> deleteTable(int tableId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/$tableId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Xóa bàn thành công' : 'Xóa bàn thất bại'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Tạo khu vực mới (POST /api/table/area)
  static Future<Map<String, dynamic>> createArea({
    required String areaName,
    String? description,
    int sortOrder = 0,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/area'),
            headers: headers,
            body: jsonEncode({
              'areaName': areaName,
              'description': description,
              'sortOrder': sortOrder,
            }),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Tạo khu vực thành công' : 'Thất bại'),
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Cập nhật khu vực (PUT /api/table/area/{id})
  static Future<Map<String, dynamic>> updateArea(
    int areaId, {
    required String areaName,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/area/$areaId'),
            headers: headers,
            body: jsonEncode({
              'areaName': areaName,
              'description': description,
              'sortOrder': sortOrder,
              'isActive': isActive,
            }),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Cập nhật khu vực thành công' : 'Thất bại'),
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Xóa khu vực (DELETE /api/table/area/{id})
  static Future<Map<String, dynamic>> deleteArea(int areaId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/area/$areaId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Xóa khu vực thành công' : 'Xóa khu vực thất bại'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }
}

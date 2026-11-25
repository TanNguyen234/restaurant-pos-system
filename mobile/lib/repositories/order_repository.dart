import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/offline_sync_service.dart';
import '../utils/database_helper.dart';

class OrderRepository {
  static String baseUrl = '${ApiConfig.baseUrl}/api/order';
  static String paymentBaseUrl = '${ApiConfig.baseUrl}/api/payment';
  static String kdsBaseUrl = '${ApiConfig.baseUrl}/api/kds';
  static Duration timeoutDuration = const Duration(seconds: 6);
  static const Uuid _uuid = Uuid();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Map<String, dynamic> _decodeMap(List<int> bodyBytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  /// Tạo đơn hàng mới từ giỏ hàng.
  /// - Online: gọi `POST /api/order` kèm `idempotencyKey` chống trùng đơn.
  /// - Mất mạng (`ClientException`): tự động xếp vào hàng đợi cục bộ SQLite / WebStorage.
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    final payload = Map<String, dynamic>.from(orderData);
    payload['idempotencyKey'] = (payload['idempotencyKey']?.toString().trim().isNotEmpty == true)
        ? payload['idempotencyKey']
        : _uuid.v4();

    try {
      final res = await ApiConfig.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(timeoutDuration);

      final d = _decodeMap(res.bodyBytes);
      if (res.statusCode != 200 || d['success'] == false) {
        return {
          'success': false,
          'isOffline': false,
          'message': d['message']?.toString() ?? d['error']?.toString() ?? 'Máy chủ từ chối đơn (HTTP ${res.statusCode})',
        };
      }

      return {
        'success': true,
        'isOffline': false,
        'orderId': d['orderId'],
        'orderCode': d['orderCode'],
        'totalAmount': d['totalAmount'],
        'discountAmount': d['discountAmount'],
        'finalAmount': d['finalAmount'],
        'message': d['message']?.toString() ?? 'Tạo đơn thành công',
        'data': d['data'],
      };
    } on TimeoutException {
      return {
        'success': false,
        'isOffline': false,
        'message': 'Máy chủ không phản hồi kịp lúc. Kiểm tra đơn hàng trước khi thử lại để tránh đặt trùng.',
      };
    } on http.ClientException {
      return _queuePendingOrder(payload);
    } catch (_) {
      return _queuePendingOrder(payload);
    }
  }

  Future<Map<String, dynamic>> _queuePendingOrder(Map<String, dynamic> d) async {
    final items = d['items'];
    if (items is! List || items.isEmpty) {
      return {'success': false, 'isOffline': false, 'message': 'Giỏ hàng không hợp lệ'};
    }
    final id = await _dbHelper.saveOfflineOrder({
      'idempotency_key': d['idempotencyKey'] ?? _uuid.v4(),
      'table_id': d['tableId'],
      'customer_name': d['customerName'] ?? 'Khách lẻ',
      'phone_number': d['phoneNumber'],
      'order_type': d['orderType'] ?? 1,
      'note': d['note'],
      'discount_code': d['discountCode'],
      'total_amount': (d['totalAmount'] as num?)?.toDouble() ?? 0.0,
      'items_json': jsonEncode(items),
    });
    await OfflineSyncService().refreshUnsyncedCount();
    return {
      'success': true,
      'isOffline': true,
      'orderId': id,
      'orderCode': 'PENDING-$id',
      'message': 'Đã lưu vào hàng đợi ngoại tuyến (PENDING-$id), sẽ tự đồng bộ khi có mạng.',
    };
  }

  /// Lấy danh sách quản trị đơn hàng cho Admin & Thu ngân kèm bộ lọc & Top món bán chạy
  Future<Map<String, dynamic>> getAdminOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? status,
    String? search,
  }) async {
    final q = <String, String>{};
    if (fromDate != null) q['fromDate'] = fromDate.toIso8601String();
    if (toDate != null) q['toDate'] = toDate.toIso8601String();
    if (status != null) q['status'] = '$status';
    if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();

    final res = await ApiConfig.get(Uri.parse('$baseUrl/admin').replace(queryParameters: q))
        .timeout(timeoutDuration);
    if (res.statusCode != 200) {
      throw StateError('Không tải được đơn hàng (HTTP ${res.statusCode})');
    }

    final d = _decodeMap(res.bodyBytes);
    final orders = (d['orders'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final topProducts = (d['topProducts'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return {
      'totalOrders': d['totalOrders'] ?? orders.length,
      'totalRevenue': (d['totalRevenue'] as num? ?? 0).toDouble(),
      'orders': orders,
      'topProducts': topProducts,
    };
  }

  /// Tra cứu đơn hàng theo mã đơn hoặc số điện thoại (Barem 5.9)
  Future<List<OrderModel>> lookupOrders(String? query) async {
    final uri = (query != null && query.trim().isNotEmpty)
        ? Uri.parse('$baseUrl/lookup').replace(queryParameters: {'query': query.trim()})
        : Uri.parse('$baseUrl/lookup');
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    if (res.statusCode != 200) {
      throw StateError('Không thể tra cứu đơn hàng (HTTP ${res.statusCode})');
    }
    final d = _decodeMap(res.bodyBytes);
    final rawList = d['items'] ?? d['data'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Lấy đơn hàng đang phục vụ của bàn
  Future<OrderModel?> getActiveOrderByTable(int tableId) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/by-table/$tableId')).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw StateError('Không tải được đơn của bàn (HTTP ${res.statusCode})');
    }
    final d = _decodeMap(res.bodyBytes);
    if (d['hasActiveOrder'] == true && d['data'] is Map) {
      return OrderModel.fromMap(Map<String, dynamic>.from(d['data'] as Map));
    }
    return null;
  }

  /// Thêm món vào đơn hàng hiện có (`POST /api/order/{id}/add-items` - body là List JSON)
  Future<Map<String, dynamic>> addItemsToOrder(
    int orderId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final res = await ApiConfig.post(
        Uri.parse('$baseUrl/$orderId/add-items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(items),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] != false,
        'message': d['message']?.toString() ?? (res.statusCode == 200 ? 'Đã thêm món vào đơn' : 'Không thể thêm món'),
        'data': d['data'] is Map ? OrderModel.fromMap(Map<String, dynamic>.from(d['data'] as Map)) : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi thêm món vào đơn: $e'};
    }
  }

  /// Áp dụng giảm giá thủ công tại quầy thu ngân (`PUT /api/order/{id}/discount`)
  Future<Map<String, dynamic>> applyManualDiscount({
    required int orderId,
    double? discountPercent,
    double? discountAmount,
    String? reason,
  }) async {
    try {
      final res = await ApiConfig.put(
        Uri.parse('$baseUrl/$orderId/discount'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'discountPercent': discountPercent,
          'discountAmount': discountAmount,
          'reason': reason,
        }),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] != false,
        'message': d['message']?.toString() ?? (res.statusCode == 200 ? 'Đã áp dụng chiết khấu' : 'Không thể áp dụng giảm giá'),
        'data': d['data'] is Map ? OrderModel.fromMap(Map<String, dynamic>.from(d['data'] as Map)) : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi áp dụng giảm giá: $e'};
    }
  }

  /// Lấy chi tiết đơn hàng theo ID
  Future<OrderModel?> getOrderById(int orderId) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/$orderId')).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw StateError('Không tải được đơn hàng (HTTP ${res.statusCode})');
    return OrderModel.fromMap(_decodeMap(res.bodyBytes));
  }

  /// Cập nhật trạng thái đơn hàng (0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy)
  Future<bool> updateOrderStatus(int orderId, int newStatus) async {
    try {
      final res = await ApiConfig.put(
        Uri.parse('$baseUrl/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      ).timeout(timeoutDuration);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Lấy danh sách các món ăn cần chế biến cho màn hình Bếp / Pha chế (KDS)
  Future<List<KdsItemModel>> getKdsActiveItems() async {
    final res = await ApiConfig.get(Uri.parse('$kdsBaseUrl/active-orders')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Màn hình bếp không khả dụng (HTTP ${res.statusCode})');
    final List<dynamic> d = jsonDecode(utf8.decode(res.bodyBytes));
    return d.map((e) => KdsItemModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Cập nhật trạng thái chế biến món ăn trên màn hình KDS (0 -> 1 -> 2 -> 3)
  Future<bool> updateCookingStatus(int orderDetailId, int cookingStatus) async {
    try {
      final res = await ApiConfig.put(
        Uri.parse('$kdsBaseUrl/order-detail/$orderDetailId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cookingStatus': cookingStatus}),
      ).timeout(timeoutDuration);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Báo hủy món từ màn hình Bếp (`POST /api/kds/{orderDetailId}/void`)
  Future<Map<String, dynamic>> voidKdsItem({
    required int orderDetailId,
    required String reason,
    int voidQuantity = 0,
  }) async {
    try {
      final res = await ApiConfig.post(
        Uri.parse('$kdsBaseUrl/$orderDetailId/void'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason, 'voidQuantity': voidQuantity}),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] != false,
        'message': d['message']?.toString() ?? (res.statusCode == 200 ? 'Đã báo hủy món' : 'Không thể hủy món'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi báo hủy món: $e'};
    }
  }

  /// Xác nhận thanh toán đơn hàng (Tiền mặt, VietQR, VNPay) - hỗ trợ trả từng phần (Split Payment)
  Future<Map<String, dynamic>> confirmPayment({
    required int orderId,
    required String paymentMethod,
    required double amount,
    String? transactionRef,
    String? note,
  }) async {
    try {
      final res = await ApiConfig.post(
        Uri.parse('$paymentBaseUrl/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'paymentMethod': paymentMethod,
          'amount': amount,
          'transactionRef': transactionRef,
          'note': note,
        }),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      if (res.statusCode != 200 || d['success'] == false) {
        return {
          'success': false,
          'message': d['message']?.toString() ?? 'Thanh toán chưa được xác nhận (HTTP ${res.statusCode})',
        };
      }
      return {
        'success': true,
        'message': d['message']?.toString() ?? 'Thanh toán thành công',
        'paymentId': d['paymentId'],
        'data': d['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không kết nối được thanh toán: $e'};
    }
  }

  /// Lấy thông tin mã VietQR NAPAS 247 động (hỗ trợ custom amount cho tách bill)
  Future<VietQrModel?> getVietQr(int orderId, {double? amount}) async {
    final uri = (amount != null && amount > 0)
        ? Uri.parse('$paymentBaseUrl/vietqr/$orderId').replace(queryParameters: {'amount': amount.toStringAsFixed(0)})
        : Uri.parse('$paymentBaseUrl/vietqr/$orderId');
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw StateError('VietQR không khả dụng (HTTP ${res.statusCode})');
    final d = _decodeMap(res.bodyBytes);
    return d['success'] == true && d['data'] is Map
        ? VietQrModel.fromMap(Map<String, dynamic>.from(d['data'] as Map))
        : null;
  }

  /// Tạo URL thanh toán VNPay Sandbox
  Future<String?> createVnpayUrl(int orderId, double amount, String orderInfo) async {
    final res = await ApiConfig.post(
      Uri.parse('$paymentBaseUrl/create-vnpay-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'orderId': orderId, 'amount': amount, 'orderInfo': orderInfo}),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'VNPay không khả dụng (HTTP ${res.statusCode})');
    }
    return d['paymentUrl']?.toString();
  }

  /// Hủy món ăn trong đơn hàng có lý do (POST /api/order/{id}/void-item)
  Future<Map<String, dynamic>> voidOrderItem({
    required int orderId,
    required int orderDetailId,
    required String reason,
    int voidQuantity = 1,
  }) async {
    try {
      final res = await ApiConfig.post(
        Uri.parse('$baseUrl/$orderId/void-item'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderDetailId': orderDetailId,
          'reason': reason,
          'voidQuantity': voidQuantity,
        }),
      ).timeout(timeoutDuration);

      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] == true,
        'message': d['message']?.toString() ?? (res.statusCode == 200 ? 'Hủy món thành công' : 'Thất bại'),
        'data': d['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi khi hủy món: $e'};
    }
  }

  /// Hủy đơn chưa thanh toán để khôi phục giỏ hàng / đổi luồng đặt (POST /api/order/{id}/cancel-unpaid)
  Future<Map<String, dynamic>> cancelUnpaidOrder(int orderId) async {
    try {
      final res = await ApiConfig.post(
        Uri.parse('$baseUrl/$orderId/cancel-unpaid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] == true,
        'message': d['message']?.toString() ?? (res.statusCode == 200 ? 'Đã hủy đơn' : 'Không thể hủy đơn'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối khi hủy đơn: $e'};
    }
  }

  /// Đặt món tự phục vụ qua mã QR tại bàn (POST /api/order/qr-self-order)
  Future<Map<String, dynamic>> createQrSelfOrder(Map<String, dynamic> orderData) async {
    final payload = Map<String, dynamic>.from(orderData);
    payload['idempotencyKey'] = (payload['idempotencyKey']?.toString().trim().isNotEmpty == true)
        ? payload['idempotencyKey']
        : _uuid.v4();
    try {
      final res = await ApiConfig.post(
        Uri.parse('$baseUrl/qr-self-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] == true,
        'isOffline': false,
        'orderId': d['orderId'],
        'orderCode': d['orderCode'],
        'totalAmount': d['totalAmount'],
        'discountAmount': d['discountAmount'],
        'finalAmount': d['finalAmount'],
        'message': d['message']?.toString() ?? 'Gửi đơn QR thất bại (HTTP ${res.statusCode})',
        'data': d['data'],
      };
    } catch (e) {
      return {'success': false, 'isOffline': false, 'message': 'Không gửi được đơn QR: $e'};
    }
  }

  /// Lấy dữ liệu biểu đồ phân tích doanh thu theo ngày/giờ/kênh thanh toán
  Future<Map<String, dynamic>> getAnalytics({int days = 7}) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/analytics?days=$days')).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'Không tải được dữ liệu phân tích');
    }
    return d;
  }

  /// Xuất báo cáo CSV đơn hàng
  Future<String> exportOrdersCsv({DateTime? fromDate, DateTime? toDate, int? status}) async {
    final q = <String, String>{};
    if (fromDate != null) q['fromDate'] = fromDate.toIso8601String();
    if (toDate != null) q['toDate'] = toDate.toIso8601String();
    if (status != null) q['status'] = '$status';
    final uri = Uri.parse('$baseUrl/export-csv').replace(queryParameters: q.isEmpty ? null : q);
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    if (res.statusCode != 200) {
      throw StateError('Không xuất được file CSV (HTTP ${res.statusCode})');
    }
    return utf8.decode(res.bodyBytes);
  }
}

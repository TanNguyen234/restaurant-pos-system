import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/offline_sync_service.dart';
import '../services/qr_table_session.dart';
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

      if (res.statusCode == 401) {
        return {
          'success': false,
          'isOffline': false,
          'sessionExpired': true,
          'message': 'Phiên đăng nhập đã hết hạn hoặc không hợp lệ. Vui lòng đăng nhập lại (giỏ hàng được giữ nguyên).',
        };
      }

      final d = _decodeMap(res.bodyBytes);
      if (res.statusCode != 200 || d['success'] == false) {
        return {
          'success': false,
          'isOffline': false,
          'message': d['message']?.toString() ?? d['error']?.toString() ?? 'Máy chủ từ chối đơn (HTTP ${res.statusCode})',
        };
      }

      final oid = d['orderId'] as int?;
      final guestToken = d['guestToken']?.toString();
      if (oid != null && guestToken != null && guestToken.isNotEmpty) {
        await QrTableSession.instance.saveGuestToken(oid, guestToken);
      }

      return {
        'success': true,
        'isOffline': false,
        'orderId': d['orderId'],
        'orderCode': d['orderCode'],
        'totalAmount': d['totalAmount'],
        'discountAmount': d['discountAmount'],
        'finalAmount': d['finalAmount'],
        'guestToken': guestToken,
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
    } catch (e) {
      if (_isNetworkTransportError(e)) {
        return _queuePendingOrder(payload);
      }
      return {
        'success': false,
        'isOffline': false,
        'message': 'Lỗi xử lý đơn hàng: $e',
      };
    }
  }

  bool _isNetworkTransportError(Object error) {
    if (error is http.ClientException) return true;
    final msg = error.toString();
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup') ||
        msg.contains('HandshakeException') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Connection closed');
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
    final guestToken = await QrTableSession.instance.getGuestToken(orderId);
    final res = await ApiConfig.get(
      Uri.parse('$baseUrl/$orderId'),
      headers: {
        if (guestToken != null && guestToken.isNotEmpty) 'X-Guest-Token': guestToken,
      },
    ).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw StateError('Không tải được đơn hàng (HTTP ${res.statusCode})');
    return OrderModel.fromMap(_decodeMap(res.bodyBytes));
  }

  /// Món bếp / pha chế đã làm xong, đang chờ phục vụ bưng ra bàn (cookingStatus = 2).
  Future<List<KdsItemModel>> getReadyToServeItems() async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/ready-to-serve')).timeout(timeoutDuration);
    if (res.statusCode != 200) throw StateError('Không tải được danh sách món chờ bưng (HTTP ${res.statusCode})');
    final List<dynamic> d = jsonDecode(utf8.decode(res.bodyBytes));
    return d.map((e) => KdsItemModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Phục vụ xác nhận đã giao một món ra bàn (cookingStatus 2 -> 3).
  Future<Map<String, dynamic>> serveItem(int orderDetailId) async {
    try {
      final res = await ApiConfig.put(Uri.parse('$baseUrl/detail/$orderDetailId/serve')).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] != false,
        'message': d['message']?.toString() ?? 'Không cập nhật được trạng thái giao món (HTTP ${res.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không kết nối được máy chủ: $e'};
    }
  }

  /// Phục vụ / thu ngân báo đã bưng các món bếp làm xong ra bàn (cookingStatus 2 -> 3).
  Future<Map<String, dynamic>> serveReadyItems(int orderId) async {
    try {
      final res = await ApiConfig.put(Uri.parse('$baseUrl/$orderId/serve-ready')).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      return {
        'success': res.statusCode == 200 && d['success'] != false,
        'message': d['message']?.toString() ?? 'Không cập nhật được trạng thái giao món (HTTP ${res.statusCode})',
        'servedCount': d['servedCount'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Không kết nối được máy chủ: $e'};
    }
  }

  /// Lấy đơn hàng dạng map thô (cùng cấu trúc `data` của /by-table) để POS thu ngân nạp lại hoá đơn không gắn bàn.
  Future<Map<String, dynamic>?> getOrderMapById(int orderId) async {
    try {
      final res = await ApiConfig.get(Uri.parse('$baseUrl/$orderId')).timeout(timeoutDuration);
      if (res.statusCode != 200) return null;
      final d = _decodeMap(res.bodyBytes);
      return d.isEmpty ? null : d;
    } catch (_) {
      return null;
    }
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
    bool allowUnserved = false,
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
          if (allowUnserved) 'allowUnserved': true,
        }),
      ).timeout(timeoutDuration);
      final d = _decodeMap(res.bodyBytes);
      if (res.statusCode != 200 || d['success'] == false) {
        return {
          'success': false,
          'errorCode': d['errorCode'],
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
    final guestToken = await QrTableSession.instance.getGuestToken(orderId);
    final res = await ApiConfig.get(
      uri,
      headers: {
        if (guestToken != null && guestToken.isNotEmpty) 'X-Guest-Token': guestToken,
      },
    ).timeout(timeoutDuration);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw StateError('VietQR không khả dụng (HTTP ${res.statusCode})');
    final d = _decodeMap(res.bodyBytes);
    return d['success'] == true && d['data'] is Map
        ? VietQrModel.fromMap(Map<String, dynamic>.from(d['data'] as Map))
        : null;
  }

  /// Tải ảnh VietQR PNG qua proxy Backend (tránh lỗi CORS trên Flutter Web CanvasKit)
  Future<Uint8List?> getVietQrImageBytes(int orderId, {double? amount}) async {
    final uri = (amount != null && amount > 0)
        ? Uri.parse('$paymentBaseUrl/vietqr/$orderId/image').replace(queryParameters: {'amount': amount.toStringAsFixed(0)})
        : Uri.parse('$paymentBaseUrl/vietqr/$orderId/image');
    final guestToken = await QrTableSession.instance.getGuestToken(orderId);
    final res = await ApiConfig.get(
      uri,
      headers: {
        if (guestToken != null && guestToken.isNotEmpty) 'X-Guest-Token': guestToken,
      },
    ).timeout(timeoutDuration);
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && ct.startsWith('image/')) {
      return res.bodyBytes;
    }
    return null;
  }

  /// Tạo URL thanh toán VNPay Sandbox
  Future<String?> createVnpayUrl(int orderId, double amount, String orderInfo) async {
    final guestToken = await QrTableSession.instance.getGuestToken(orderId);
    final res = await ApiConfig.post(
      Uri.parse('$paymentBaseUrl/create-vnpay-url'),
      headers: {
        'Content-Type': 'application/json',
        if (guestToken != null && guestToken.isNotEmpty) 'X-Guest-Token': guestToken,
      },
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
      final guestToken = await QrTableSession.instance.getGuestToken(orderId);
      final res = await ApiConfig.post(
        Uri.parse('$baseUrl/$orderId/cancel-unpaid'),
        headers: {
          'Content-Type': 'application/json',
          if (guestToken != null && guestToken.isNotEmpty) 'X-Guest-Token': guestToken,
        },
        body: jsonEncode({
          if (guestToken != null && guestToken.isNotEmpty) 'guestToken': guestToken,
        }),
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
      final oid = d['orderId'] as int?;
      final guestToken = d['guestToken']?.toString();
      if (oid != null && guestToken != null && guestToken.isNotEmpty) {
        await QrTableSession.instance.saveGuestToken(oid, guestToken);
      }
      return {
        'success': res.statusCode == 200 && d['success'] == true,
        'isOffline': false,
        'orderId': d['orderId'],
        'orderCode': d['orderCode'],
        'totalAmount': d['totalAmount'],
        'discountAmount': d['discountAmount'],
        'finalAmount': d['finalAmount'],
        'guestToken': guestToken,
        'message': d['message']?.toString() ?? 'Gửi đơn QR thất bại (HTTP ${res.statusCode})',
        'data': d['data'],
      };
    } catch (e) {
      return {'success': false, 'isOffline': false, 'message': 'Không gửi được đơn QR: $e'};
    }
  }

  /// Lấy dữ liệu biểu đồ phân tích doanh thu theo ngày/giờ/kênh thanh toán
  Future<Map<String, dynamic>> getAnalytics({
    int days = 7,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final queryParams = <String, String>{
      'days': '$days',
      if (fromDate != null) 'fromDate': fromDate.toIso8601String(),
      if (toDate != null) 'toDate': toDate.toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/analytics').replace(queryParameters: queryParams);
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'Không tải được dữ liệu phân tích');
    }
    return d;
  }

  /// Xuất báo cáo CSV đơn hàng (bytes gốc kèm UTF-8 BOM + tên file gợi ý)
  Future<({Uint8List bytes, String fileName, String csvText})> exportOrdersCsvBytes({
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
    final uri = Uri.parse('$baseUrl/export-csv').replace(queryParameters: q.isEmpty ? null : q);
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    if (res.statusCode != 200) {
      throw StateError('Không xuất được file CSV (HTTP ${res.statusCode})');
    }
    String fileName = 'orders_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final cd = res.headers['content-disposition'];
    if (cd != null && cd.isNotEmpty) {
      final m = RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(cd);
      if (m != null && m.group(1) != null && m.group(1)!.trim().isNotEmpty) {
        fileName = m.group(1)!.trim();
      }
    }
    return (
      bytes: res.bodyBytes,
      fileName: fileName,
      csvText: utf8.decode(res.bodyBytes, allowMalformed: true),
    );
  }

  /// Xuất báo cáo CSV đơn hàng dạng chuỗi
  Future<String> exportOrdersCsv({DateTime? fromDate, DateTime? toDate, int? status, String? search}) async {
    final bundle = await exportOrdersCsvBytes(
      fromDate: fromDate,
      toDate: toDate,
      status: status,
      search: search,
    );
    return bundle.csvText;
  }
}

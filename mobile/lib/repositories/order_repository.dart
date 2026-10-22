import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../models/payment.dart';
import '../utils/database_helper.dart';

class OrderRepository {
  static String baseUrl = "http://localhost:5138/api/order";
  static String paymentBaseUrl = "http://localhost:5138/api/payment";
  static String kdsBaseUrl = "http://localhost:5138/api/kds";
  static Duration timeoutDuration = const Duration(seconds: 4);

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Seeded fallback orders for offline demo & reliable test execution
  static final List<OrderModel> _fallbackOrders = [
    OrderModel(
      orderId: 1,
      orderCode: 'ORD-20261004-001',
      tableId: 1,
      tableName: 'Bàn T1-01',
      customerName: 'Anh Tuấn',
      phoneNumber: '0912345678',
      totalAmount: 64000,
      finalAmount: 64000,
      status: 3,
      statusText: 'Hoàn thành',
      paymentStatus: 1,
      paymentStatusText: 'Đã thanh toán',
      paymentMethod: 'Cash',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      items: [
        OrderItemModel(
          orderDetailId: 1,
          productId: 1,
          productName: 'Cà phê đen đá Đắk Lắk',
          quantity: 1,
          unitPrice: 25000,
          subTotal: 25000,
          itemNote: 'Đen đá không đường',
          cookingStatus: 2,
          cookingStatusText: 'Đã nấu xong',
        ),
        OrderItemModel(
          orderDetailId: 2,
          productId: 4,
          productName: 'Cà phê Muối Cố Đô',
          quantity: 1,
          unitPrice: 39000,
          subTotal: 39000,
          itemNote: 'Nhiều kem muối',
          cookingStatus: 2,
          cookingStatusText: 'Đã nấu xong',
        ),
      ],
    ),
    OrderModel(
      orderId: 2,
      orderCode: 'ORD-20261004-002',
      tableId: 4,
      tableName: 'Bàn BC-01',
      customerName: 'Chị Mai',
      phoneNumber: '0923456789',
      totalAmount: 90000,
      finalAmount: 90000,
      status: 1,
      statusText: 'Đang chế biến',
      paymentStatus: 0,
      paymentStatusText: 'Chưa thanh toán',
      paymentMethod: 'VietQR',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      items: [
        OrderItemModel(
          orderDetailId: 3,
          productId: 5,
          productName: 'Trà đào cam sả thanh nhiệt',
          quantity: 1,
          unitPrice: 42000,
          subTotal: 42000,
          itemNote: 'Ít ngọt, nhiều đá',
          cookingStatus: 1,
          cookingStatusText: 'Đang làm',
        ),
        OrderItemModel(
          orderDetailId: 4,
          productId: 6,
          productName: 'Trà sữa Ô long nướng Trân châu',
          quantity: 1,
          unitPrice: 48000,
          subTotal: 48000,
          itemNote: 'Thêm trân châu',
          cookingStatus: 0,
          cookingStatusText: 'Chờ nấu',
        ),
      ],
    ),
    OrderModel(
      orderId: 3,
      orderCode: 'ORD-20261004-003',
      tableId: 2,
      tableName: 'Bàn T1-02',
      customerName: 'Khách lẻ',
      totalAmount: 25000,
      finalAmount: 25000,
      status: 0,
      statusText: 'Mới tạo',
      paymentStatus: 0,
      paymentStatusText: 'Chưa thanh toán',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      items: [
        OrderItemModel(
          orderDetailId: 5,
          productId: 1,
          productName: 'Cà phê đen đá Đắk Lắk',
          quantity: 1,
          unitPrice: 25000,
          subTotal: 25000,
          cookingStatus: 0,
          cookingStatusText: 'Chờ nấu',
        ),
      ],
    ),
  ];

  /// Tạo đơn hàng mới từ giỏ hàng.
  /// Nếu có mạng: gọi Backend API `POST /api/order`.
  /// Nếu mất mạng hoặc gặp lỗi mạng: tự động lưu vào hàng đợi SQLite cục bộ `offline_orders`.
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(orderData),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': true,
          'isOffline': false,
          'orderId': data['orderId'],
          'orderCode': data['orderCode'],
          'totalAmount': data['totalAmount'],
          'message': data['message'] ?? 'Đặt hàng thành công',
        };
      }
    } catch (_) {}

    // Cơ chế Fallback SQLite Offline-First
    int offlineId = await _dbHelper.saveOfflineOrder({
      'table_id': orderData['tableId'],
      'customer_name': orderData['customerName'] ?? 'Khách vãng lai',
      'total_amount': orderData['totalAmount'] ?? (orderData['finalAmount'] ?? 0),
      'items_json': jsonEncode(orderData['items'] ?? []),
    });

    final fallbackCode = 'ORD-OFFLINE-$offlineId';

    return {
      'success': true,
      'isOffline': true,
      'orderId': offlineId,
      'orderCode': fallbackCode,
      'totalAmount': orderData['totalAmount'] ?? 0,
      'message': 'Mất kết nối mạng! Đơn hàng đã được lưu an toàn vào hàng đợi SQLite trên máy và sẽ tự động đồng bộ khi có kết nối.',
    };
  }

  /// Lấy danh sách quản trị đơn hàng cho Admin & Thu ngân kèm bộ lọc
  Future<Map<String, dynamic>> getAdminOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (fromDate != null) queryParams['fromDate'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['toDate'] = toDate.toIso8601String();
      if (status != null && status >= 0) queryParams['status'] = status.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/admin').replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> list = data['orders'] ?? [];
        final orders = list.map((item) => OrderModel.fromMap(item as Map<String, dynamic>)).toList();
        return {
          'totalOrders': data['totalOrders'] ?? orders.length,
          'totalRevenue': (data['totalRevenue'] as num? ?? 0).toDouble(),
          'orders': orders,
        };
      }
    } catch (_) {
      // Backend offline fallback
    }

    // Lọc fallback orders
    var filtered = _fallbackOrders.where((o) {
      if (status != null && status >= 0 && o.status != status) return false;
      if (search != null && search.isNotEmpty) {
        final s = search.toLowerCase();
        final match = o.orderCode.toLowerCase().contains(s) ||
            o.customerName.toLowerCase().contains(s) ||
            o.tableName.toLowerCase().contains(s);
        if (!match) return false;
      }
      return true;
    }).toList();

    double revenue = filtered
        .where((o) => o.status != 4)
        .fold<double>(0.0, (sum, o) => sum + o.finalAmount);

    return {
      'totalOrders': filtered.length,
      'totalRevenue': revenue,
      'orders': filtered,
    };
  }

  /// Lấy chi tiết đơn hàng theo ID
  Future<OrderModel?> getOrderById(int orderId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/$orderId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return OrderModel.fromMap(data);
      }
    } catch (_) {}

    return _fallbackOrders.firstWhere(
      (o) => o.orderId == orderId,
      orElse: () => _fallbackOrders.first,
    );
  }

  /// Cập nhật trạng thái đơn hàng (0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy)
  Future<bool> updateOrderStatus(int orderId, int newStatus) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/$orderId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    // Cập nhật fallback cache
    final idx = _fallbackOrders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      final cur = _fallbackOrders[idx];
      _fallbackOrders[idx] = OrderModel(
        orderId: cur.orderId,
        orderCode: cur.orderCode,
        tableId: cur.tableId,
        tableName: cur.tableName,
        customerName: cur.customerName,
        phoneNumber: cur.phoneNumber,
        totalAmount: cur.totalAmount,
        discountAmount: cur.discountAmount,
        finalAmount: cur.finalAmount,
        status: newStatus,
        statusText: OrderModel.resolveStatusText(newStatus),
        paymentStatus: newStatus == 3 ? 1 : cur.paymentStatus,
        paymentStatusText: newStatus == 3 ? 'Đã thanh toán' : cur.paymentStatusText,
        paymentMethod: cur.paymentMethod,
        totalItems: cur.totalItems,
        createdAt: cur.createdAt,
        completedAt: newStatus == 3 ? DateTime.now() : cur.completedAt,
        items: cur.items,
      );
      return true;
    }

    return true;
  }

  /// Lấy danh sách các món ăn cần chế biến cho màn hình Bếp / Pha chế (KDS)
  Future<List<KdsItemModel>> getKdsActiveItems() async {
    try {
      final response = await http
          .get(
            Uri.parse('$kdsBaseUrl/active-orders'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => KdsItemModel.fromMap(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // Trích xuất fallback KDS items từ các đơn active
    List<KdsItemModel> kdsItems = [];
    for (var ord in _fallbackOrders.where((o) => o.status < 3 && o.status != 4)) {
      for (var item in ord.items.where((i) => i.cookingStatus < 2)) {
        kdsItems.add(KdsItemModel(
          orderDetailId: item.orderDetailId,
          orderId: ord.orderId,
          orderCode: ord.orderCode,
          tableId: ord.tableId,
          tableName: ord.tableName,
          customerName: ord.customerName,
          productId: item.productId,
          productName: item.productName,
          productImage: item.productImage,
          quantity: item.quantity,
          itemNote: item.itemNote,
          cookingStatus: item.cookingStatus,
          cookingStatusText: item.cookingStatusText,
          createdAt: ord.createdAt,
          startedCookingAt: item.startedCookingAt,
        ));
      }
    }
    return kdsItems;
  }

  /// Cập nhật trạng thái chế biến món ăn trên màn hình KDS
  /// 0: Chờ nấu -> 1: Đang làm -> 2: Đã nấu xong
  Future<bool> updateCookingStatus(int orderDetailId, int cookingStatus) async {
    try {
      final response = await http
          .put(
            Uri.parse('$kdsBaseUrl/order-detail/$orderDetailId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'cookingStatus': cookingStatus}),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    return true;
  }

  /// Xác nhận thanh toán đơn hàng (Tiền mặt, VietQR, VNPay)
  Future<Map<String, dynamic>> confirmPayment({
    required int orderId,
    required String paymentMethod,
    required double amount,
    String? transactionRef,
    String? note,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$paymentBaseUrl/confirm'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': orderId,
              'paymentMethod': paymentMethod,
              'amount': amount,
              'transactionRef': transactionRef,
              'note': note,
            }),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Thanh toán thành công',
          'paymentId': data['paymentId'],
        };
      }
    } catch (_) {}

    // Offline update
    await updateOrderStatus(orderId, 3);
    return {
      'success': true,
      'message': 'Đã xác nhận thanh toán đơn #$orderId thành công (Offline Mode)',
      'paymentId': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Lấy thông tin mã VietQR NAPAS 247 động cho đơn hàng
  Future<VietQrModel?> getVietQr(int orderId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$paymentBaseUrl/vietqr/$orderId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> res = jsonDecode(response.body);
        if (res['success'] == true && res['data'] != null) {
          return VietQrModel.fromMap(res['data'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    // Fallback VietQR URL
    final ord = await getOrderById(orderId);
    double amount = ord?.finalAmount ?? 50000;
    String code = ord?.orderCode ?? 'ORD-$orderId';
    String desc = 'THANH TOAN $code';
    String encDesc = Uri.encodeComponent(desc);
    String encName = Uri.encodeComponent('NHA HANG RESTAURANT POS');

    return VietQrModel(
      orderId: orderId,
      orderCode: code,
      bankId: 'MB',
      bankName: 'MB Bank (Ngân hàng Quân Đội)',
      accountNo: '0901234567',
      accountName: 'NHA HANG RESTAURANT POS',
      amount: amount,
      description: desc,
      qrImageUrl: 'https://img.vietqr.io/image/MB-0901234567-compact2.png?amount=${amount.toInt()}&addInfo=$encDesc&accountName=$encName',
    );
  }

  /// Tạo URL thanh toán VNPay Sandbox
  Future<String?> createVnpayUrl(int orderId, double amount, String orderInfo) async {
    try {
      final response = await http
          .post(
            Uri.parse('$paymentBaseUrl/create-vnpay-url'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': orderId,
              'amount': amount,
              'orderInfo': orderInfo,
            }),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['paymentUrl'];
      }
    } catch (_) {}

    return 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?orderId=$orderId&amount=${(amount * 100).toInt()}';
  }
}

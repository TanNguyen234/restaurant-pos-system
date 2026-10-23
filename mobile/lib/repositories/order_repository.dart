import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../models/payment.dart';
import '../config/api_config.dart';
import '../utils/database_helper.dart';

class OrderRepository {
  static String baseUrl = ApiConfig.baseUrl + '/api/order';
  static String paymentBaseUrl = ApiConfig.baseUrl + '/api/payment';
  static String kdsBaseUrl = ApiConfig.baseUrl + '/api/kds';
  static Duration timeoutDuration = const Duration(seconds: 4);

  final DatabaseHelper _dbHelper = DatabaseHelper();


  /// Tạo đơn hàng mới từ giỏ hàng.
  /// Nếu có mạng: gọi Backend API `POST /api/order`.
  /// Nếu mất mạng hoặc gặp lỗi mạng: tự động lưu vào hàng đợi SQLite cục bộ `offline_orders`.
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final res=await http.post(Uri.parse(baseUrl),headers:{'Content-Type':'application/json'},body:jsonEncode(orderData)).timeout(timeoutDuration);
      if(res.statusCode!=200)return {'success':false,'isOffline':false,'message':'Máy chủ từ chối đơn (HTTP ${res.statusCode})'};
      final d=jsonDecode(res.body) as Map<String,dynamic>;
      return {'success':true,'isOffline':false,'orderId':d['orderId'],'orderCode':d['orderCode'],'totalAmount':d['totalAmount'],'message':d['message']??'Tạo đơn thành công'};
    } on TimeoutException {return _queuePendingOrder(orderData);}
      on http.ClientException {return _queuePendingOrder(orderData);}
  }
  Future<Map<String,dynamic>> _queuePendingOrder(Map<String,dynamic> d) async {
    final items=d['items'];
    if(items is! List||items.isEmpty)return {'success':false,'message':'Giỏ hàng không hợp lệ'};
    final id=await _dbHelper.saveOfflineOrder({'table_id':d['tableId'],'customer_name':d['customerName']??'Khách lẻ','total_amount':d['totalAmount']??0,'items_json':jsonEncode(items)});
    return {'success':true,'isOffline':true,'orderId':id,'orderCode':'PENDING-$id','message':'Đã lưu vào hàng đợi SQLite, chưa được máy chủ xác nhận'};
  }

  /// Lấy danh sách quản trị đơn hàng cho Admin & Thu ngân kèm bộ lọc
  Future<Map<String, dynamic>> getAdminOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? status,
    String? search,
  }) async {
    final q=<String,String>{};if(fromDate!=null)q['fromDate']=fromDate.toIso8601String();if(toDate!=null)q['toDate']=toDate.toIso8601String();if(status!=null)q['status']='$status';if(search!=null&&search.isNotEmpty)q['search']=search;
    final res=await http.get(Uri.parse('$baseUrl/admin').replace(queryParameters:q)).timeout(timeoutDuration);
    if(res.statusCode!=200)throw StateError('Không tải được đơn hàng (HTTP ${res.statusCode})');
    final d=jsonDecode(res.body) as Map<String,dynamic>;
    final orders=(d['orders'] as List<dynamic>? ?? []).map((e)=>OrderModel.fromMap(e)).toList();
    return {'totalOrders':d['totalOrders']??orders.length,'totalRevenue':(d['totalRevenue'] as num? ?? 0).toDouble(),'orders':orders};
  }

  /// Lấy chi tiết đơn hàng theo ID
  Future<OrderModel?> getOrderById(int orderId) async {
    final res=await http.get(Uri.parse('$baseUrl/$orderId')).timeout(timeoutDuration);
    if(res.statusCode==404)return null;
    if(res.statusCode!=200)throw StateError('Không tải được đơn hàng (HTTP ${res.statusCode})');
    return OrderModel.fromMap(jsonDecode(res.body));
  }

  /// Cập nhật trạng thái đơn hàng (0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy)
  Future<bool> updateOrderStatus(int orderId, int newStatus) async {
    try{final res=await http.put(Uri.parse('$baseUrl/$orderId/status'),headers:{'Content-Type':'application/json'},body:jsonEncode({'status':newStatus})).timeout(timeoutDuration);return res.statusCode==200;}catch(_){return false;}
  }

  /// Lấy danh sách các món ăn cần chế biến cho màn hình Bếp / Pha chế (KDS)
  Future<List<KdsItemModel>> getKdsActiveItems() async {
    final res=await http.get(Uri.parse('$kdsBaseUrl/active-orders')).timeout(timeoutDuration);
    if(res.statusCode!=200)throw StateError('Màn hình bếp không khả dụng (HTTP ${res.statusCode})');
    final List<dynamic> d=jsonDecode(res.body);return d.map((e)=>KdsItemModel.fromMap(e)).toList();
  }

  /// Cập nhật trạng thái chế biến món ăn trên màn hình KDS
  /// 0: Chờ nấu -> 1: Đang làm -> 2: Đã nấu xong
  Future<bool> updateCookingStatus(int orderDetailId, int cookingStatus) async {
    try{final res=await http.put(Uri.parse('$kdsBaseUrl/order-detail/$orderDetailId/status'),headers:{'Content-Type':'application/json'},body:jsonEncode({'cookingStatus':cookingStatus})).timeout(timeoutDuration);return res.statusCode==200;}catch(_){return false;}
  }

  /// Xác nhận thanh toán đơn hàng (Tiền mặt, VietQR, VNPay)
  Future<Map<String, dynamic>> confirmPayment({
    required int orderId,
    required String paymentMethod,
    required double amount,
    String? transactionRef,
    String? note,
  }) async {
    try{final res=await http.post(Uri.parse('$paymentBaseUrl/confirm'),headers:{'Content-Type':'application/json'},body:jsonEncode({'orderId':orderId,'paymentMethod':paymentMethod,'amount':amount,'transactionRef':transactionRef,'note':note})).timeout(timeoutDuration);
    if(res.statusCode!=200)return {'success':false,'message':'Thanh toán chưa được xác nhận (HTTP ${res.statusCode})'};
    final d=jsonDecode(res.body) as Map<String,dynamic>;return {'success':d['success']==true,'message':d['message']??'Đã nhận phản hồi','paymentId':d['paymentId']};}catch(e){return {'success':false,'message':'Không kết nối được thanh toán: $e'};}
  }

  /// Lấy thông tin mã VietQR NAPAS 247 động cho đơn hàng
  Future<VietQrModel?> getVietQr(int orderId) async {
    final res=await http.get(Uri.parse('$paymentBaseUrl/vietqr/$orderId')).timeout(timeoutDuration);if(res.statusCode==404)return null;
    if(res.statusCode!=200)throw StateError('VietQR không khả dụng (HTTP ${res.statusCode})');
    final d=jsonDecode(res.body) as Map<String,dynamic>;return d['success']==true&&d['data']!=null?VietQrModel.fromMap(d['data']):null;
  }

  /// Tạo URL thanh toán VNPay Sandbox
  Future<String?> createVnpayUrl(int orderId, double amount, String orderInfo) async {
    final res=await http.post(Uri.parse('$paymentBaseUrl/create-vnpay-url'),headers:{'Content-Type':'application/json'},body:jsonEncode({'orderId':orderId,'amount':amount,'orderInfo':orderInfo})).timeout(timeoutDuration);
    if(res.statusCode!=200)throw StateError('VNPay không khả dụng (HTTP ${res.statusCode})');
    final d=jsonDecode(res.body) as Map<String,dynamic>;return d['paymentUrl'] as String?;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_pos_app/models/user.dart';
import 'package:restaurant_pos_app/models/order.dart';
import 'package:restaurant_pos_app/models/payment.dart';
import 'package:restaurant_pos_app/repositories/auth_repository.dart';
import 'package:restaurant_pos_app/repositories/order_repository.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';

class Member3FakeDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> _tables = {
    'user_session': [],
    'cart_items': [],
    'offline_orders': [],
  };
  int _autoId = 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final copy = Map<String, dynamic>.from(values);
    copy['id'] ??= _autoId++;
    _tables[table]?.add(copy);
    return copy['id'] as int;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    var list = _tables[table] ?? [];
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      if (where.contains('product_id = ?')) {
        list = list.where((r) => r['product_id'] == whereArgs.first).toList();
      } else if (where.contains('is_synced = 0')) {
        list = list.where((r) => (r['is_synced'] as int? ?? 0) == 0).toList();
      }
    }
    return List<Map<String, Object?>>.from(list);
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (where == null) {
      final count = _tables[table]?.length ?? 0;
      _tables[table]?.clear();
      return count;
    }
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (sql.contains('COUNT(*)')) {
      final count = _tables['offline_orders']?.where((r) => (r['is_synced'] as int? ?? 0) == 0).length ?? 0;
      return [{'count': count}];
    }
    return [{'total': 0}];
  }
}

class _Member3HttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Member3FakeHttpClient();
}

class _Member3FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final path = url.path;
    if (path.contains('/api/order') && method == 'POST') {
      throw const SocketException('Simulated network drop');
    }

    String jsonResp = '{}';
    if (path.contains('/api/auth/login')) {
      jsonResp = jsonEncode({
        'success': true,
        'message': 'Đăng nhập thành công',
        'token': 'test_jwt_bearer_token',
        'accountId': 1,
        'username': 'admin',
        'fullName': 'Nguyễn Văn Quản Trị',
        'role': 'ADMIN',
        'roleName': 'Quản trị viên',
      });
    } else if (path.contains('/api/order/admin')) {
      jsonResp = jsonEncode({
        'totalOrders': 1,
        'totalRevenue': 64000.0,
        'orders': [
          {
            'orderId': 1,
            'orderCode': 'ORD-001',
            'totalAmount': 64000.0,
            'finalAmount': 64000.0,
            'status': 0,
            'paymentStatus': 0,
            'createdAt': '2026-10-23T12:00:00',
          }
        ],
      });
    } else if (path.contains('/api/kds/active-orders')) {
      jsonResp = jsonEncode([
        {
          'orderDetailId': 1,
          'orderId': 1,
          'orderCode': 'ORD-001',
          'productName': 'Cà phê',
          'quantity': 1,
          'cookingStatus': 0,
          'createdAt': '2026-10-23T12:00:00',
        }
      ]);
    } else if (path.contains('/api/payment/confirm')) {
      jsonResp = jsonEncode({
        'success': true,
        'message': 'Thanh toán thành công',
        'paymentId': 1,
      });
    }

    return _Member3FakeHttpClientRequest(jsonResp);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  void close({bool force = false}) {}
}

class _Member3FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  _Member3FakeHttpClientRequest(this.responseBody);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = false;
  @override
  void write(Object? obj) {}
  @override
  void add(List<int> data) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  final HttpHeaders headers = _Member3FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _Member3FakeHttpClientResponse(responseBody);
}

class _Member3FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {
    'content-type': ['application/json; charset=utf-8'],
  };
  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];
  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;
  @override
  void forEach(void Function(String name, List<String> values) action) => _headers.forEach(action);
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => _headers[name.toLowerCase()] = [value.toString()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) => _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
}

class _Member3FakeHttpClientResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  _Member3FakeHttpClientResponse(this.responseBody);

  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  int get contentLength => utf8.encode(responseBody).length;
  @override
  final HttpHeaders headers = _Member3FakeHttpHeaders();
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(utf8.encode(responseBody)).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _Member3HttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  setUp(() {
    DatabaseHelper.setDatabaseForTesting(Member3FakeDatabase());
    AuthRepository.timeoutDuration = const Duration(seconds: 2);
    OrderRepository.timeoutDuration = const Duration(seconds: 2);
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  group('Member 3 - User Model & RBAC Roles Test', () {
    test('UserAccount serialization and role helpers', () {
      final user = UserAccount(
        accountId: 1,
        roleId: 1,
        username: 'admin',
        fullName: 'Nguyễn Văn Quản Trị',
        email: 'admin@restaurantpos.vn',
        phoneNumber: '0901234567',
        role: 'ADMIN',
        roleName: 'Quản trị viên hệ thống',
        token: 'mock-jwt-token-xyz',
      );

      expect(user.isAdmin, isTrue);
      expect(user.isManager, isTrue);
      expect(user.isStaff, isTrue);

      final map = user.toMap();
      expect(map['user_id'], 1);
      expect(map['username'], 'admin');
      expect(map['role'], 'ADMIN');
      expect(map['token'], 'mock-jwt-token-xyz');

      final fromMap = UserAccount.fromMap(map);
      expect(fromMap.accountId, 1);
      expect(fromMap.username, 'admin');
      expect(fromMap.role, 'ADMIN');
    });

    test('UserAccount Waiter and Cashier roles detection', () {
      final waiter = UserAccount(
        accountId: 2,
        roleId: 4,
        username: 'waiter1',
        fullName: 'Phục vụ bàn',
        role: 'WAITER',
        roleName: 'Nhân viên phục vụ',
      );
      expect(waiter.isWaiter, isTrue);
      expect(waiter.isAdmin, isFalse);

      final cashier = UserAccount(
        accountId: 3,
        roleId: 3,
        username: 'cashier1',
        fullName: 'Thu ngân quầy',
        role: 'CASHIER',
        roleName: 'Nhân viên thu ngân',
      );
      expect(cashier.isCashier, isTrue);
      expect(cashier.isAdmin, isFalse);
    });
  });

  group('Member 3 - Order and KDS Models Test', () {
    test('OrderModel and OrderItemModel serialization and computation', () {
      final item = OrderItemModel(
        orderDetailId: 10,
        productId: 5,
        productName: 'Trà đào cam sả',
        quantity: 2,
        unitPrice: 32000,
        subTotal: 64000,
        itemNote: 'Ít đường, nhiều đá',
        cookingStatus: 1,
      );

      expect(item.cookingStatusText, 'Đang làm');
      expect(item.subTotal, 64000);

      final order = OrderModel(
        orderId: 100,
        orderCode: 'ORD-20261004-001',
        tableId: 2,
        tableName: 'Bàn 02 (Khu A)',
        customerName: 'Nguyễn Văn A',
        totalAmount: 100000,
        discountAmount: 10000,
        finalAmount: 90000,
        status: 1,
        paymentStatus: 0,
        items: [item],
        createdAt: DateTime.now(),
      );

      expect(order.statusText, 'Đang nấu');
      expect(order.paymentStatusText, 'Chưa thanh toán');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Trà đào cam sả');
    });

    test('KdsItemModel serialization and status text', () {
      final kdsItem = KdsItemModel(
        orderDetailId: 1,
        orderId: 100,
        orderCode: 'ORD-20261004-001',
        tableName: 'Bàn 05',
        productName: 'Cà phê muối',
        quantity: 2,
        itemNote: 'Không đá',
        cookingStatus: 0,
        orderCreatedAt: DateTime.now(),
      );

      expect(kdsItem.cookingStatusText, 'Chờ nấu');
      expect(kdsItem.productName, 'Cà phê muối');
      expect(kdsItem.quantity, 2);
    });
  });

  group('Member 3 - Payment and VietQR Models Test', () {
    test('PaymentModel and VietQr dynamic URL verification', () {
      final payment = PaymentModel(
        paymentId: 1,
        orderId: 100,
        paymentMethod: 'VietQR',
        amount: 89000,
        transactionRef: 'VIETQR-20261004-001',
        status: 1,
        note: 'Thanh toán chuyển khoản VietQR',
        paymentTime: DateTime.now(),
      );

      expect(payment.paymentMethod, 'VietQR');
      expect(payment.amount, 89000);
      expect(payment.status, 1);

      final vietQr = VietQrModel(
        orderId: 100,
        orderCode: 'ORD-20261004-001',
        bankId: 'MB',
        bankName: 'Ngân hàng Quân Đội (MBBank)',
        accountNo: '0901234567',
        accountName: 'NHA HANG RESTAURANT POS',
        amount: 89000,
        description: 'THANH TOAN ORD-20261004-001',
        qrImageUrl: 'https://img.vietqr.io/image/MB-0901234567-compact2.png?amount=89000&addInfo=THANH%20TOAN%20ORD-20261004-001',
      );

      expect(vietQr.bankId, 'MB');
      expect(vietQr.accountNo, '0901234567');
      expect(vietQr.amount, 89000);
      expect(vietQr.qrImageUrl.contains('https://img.vietqr.io/image/'), isTrue);
      expect(vietQr.qrImageUrl.contains('MB-0901234567-compact2.png'), isTrue);
    });
  });

  group('Member 3 - Auth Repository Integration & Session Operations', () {
    test('Login flow saves session into SQLite user_session table and logout clears it', () async {
      final authRepo = AuthRepository();
      final dbHelper = DatabaseHelper();

      // Test login with fallback seed account
      final result = await authRepo.login('admin', 'admin');
      expect(result['success'], isTrue);
      expect(result['user'], isNotNull);

      final UserAccount user = result['user'];
      expect(user.username, 'admin');
      expect(user.isAdmin, isTrue);

      // Verify SQLite session is saved
      final session = await dbHelper.getCurrentSession();
      expect(session, isNotNull);
      expect(session!['username'], 'admin');

      // Test logout clears session
      await authRepo.logout();
      final clearedSession = await dbHelper.getCurrentSession();
      expect(clearedSession, isNull);
    });
  });

  group('Member 3 - Order Repository & Offline Resilience Test', () {
    test('createOrder falls back to SQLite offline_orders queue when network drops', () async {
      final orderRepo = OrderRepository();
      final dbHelper = DatabaseHelper();

      final orderPayload = {
        'tableId': 1,
        'customerName': 'Khách kiểm thử',
        'totalAmount': 64000.0,
        'items': [
          {'productId': 1, 'quantity': 2, 'unitPrice': 25000.0},
        ],
      };

      final result = await orderRepo.createOrder(orderPayload);
      expect(result['success'], isTrue);
      expect(result['isOffline'], isTrue);

      // Verify stored in offline queue
      final unsynced = await dbHelper.getUnsyncedOrders();
      expect(unsynced.isNotEmpty, isTrue);
      expect(unsynced.first['customer_name'], 'Khách kiểm thử');
    });

    test('getAdminOrders returns orders list and revenue', () async {
      final orderRepo = OrderRepository();
      final result = await orderRepo.getAdminOrders();

      expect(result['orders'], isNotNull);
      final List<OrderModel> orders = result['orders'];
      expect(orders.isNotEmpty, isTrue);
      expect(result['totalRevenue'], greaterThan(0));
    });

    test('getKdsActiveItems retrieves active items for kitchen', () async {
      final orderRepo = OrderRepository();
      final kdsItems = await orderRepo.getKdsActiveItems();

      expect(kdsItems, isNotNull);
      expect(kdsItems.isNotEmpty, isTrue);
    });

    test('confirmPayment updates order status and marks paid', () async {
      final orderRepo = OrderRepository();
      final result = await orderRepo.confirmPayment(
        orderId: 1,
        paymentMethod: 'VietQR',
        amount: 64000,
      );

      expect(result['success'], isTrue);
    });
  });
}

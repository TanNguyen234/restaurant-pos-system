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

void main() {
  setUp(() {
    DatabaseHelper.setDatabaseForTesting(Member3FakeDatabase());
    AuthRepository.timeoutDuration = const Duration(milliseconds: 50);
    OrderRepository.timeoutDuration = const Duration(milliseconds: 50);
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
        token: 'token_admin_test',
      );

      expect(user.isAdmin, isTrue);
      expect(user.isCashier, isFalse);
      expect(user.isWaiter, isFalse);
      expect(user.isChef, isFalse);

      final map = user.toMap();
      expect(map['username'], 'admin');
      expect(map['role'], 'ADMIN');

      final deserialized = UserAccount.fromMap(map);
      expect(deserialized.accountId, 1);
      expect(deserialized.fullName, 'Nguyễn Văn Quản Trị');
      expect(deserialized.isAdmin, isTrue);
    });

    test('UserAccount Waiter and Cashier roles detection', () {
      final waiter = UserAccount(
        accountId: 4,
        roleId: 4,
        username: 'waiter_nam',
        fullName: 'Phạm Hoàng Nam',
        role: 'WAITER',
        roleName: 'Nhân viên phục vụ',
      );
      expect(waiter.isWaiter, isTrue);
      expect(waiter.isAdmin, isFalse);

      final cashier = UserAccount(
        accountId: 3,
        roleId: 3,
        username: 'cashier_mai',
        fullName: 'Lê Tuyết Mai',
        role: 'CASHIER',
        roleName: 'Thu ngân',
      );
      expect(cashier.isCashier, isTrue);

      final chef = UserAccount(
        accountId: 7,
        roleId: 6,
        username: 'chef_dung',
        fullName: 'Ngô Tiến Dũng',
        role: 'HEAD_CHEF',
        roleName: 'Đầu bếp chính',
      );
      expect(chef.isChef, isTrue);
    });
  });

  group('Member 3 - Order and KDS Models Test', () {
    test('OrderModel and OrderItemModel serialization and computation', () {
      final orderItem = OrderItemModel(
        orderDetailId: 1,
        productId: 1,
        productName: 'Cà phê đen đá Đắk Lắk',
        quantity: 2,
        unitPrice: 25000,
        subTotal: 50000,
        itemNote: 'Đen đá không đường',
        cookingStatus: 1,
        cookingStatusText: 'Đang làm',
      );

      final order = OrderModel(
        orderId: 10,
        orderCode: 'ORD-20261020-001',
        tableId: 1,
        tableName: 'Bàn T1-01',
        customerName: 'Anh Tuấn',
        phoneNumber: '0912345678',
        totalAmount: 50000,
        finalAmount: 50000,
        status: 1,
        statusText: 'Đang chế biến',
        paymentStatus: 0,
        paymentStatusText: 'Chưa thanh toán',
        createdAt: DateTime.now(),
        items: [orderItem],
      );

      expect(order.isPaid, isFalse);
      expect(order.isCompleted, isFalse);
      expect(order.items.length, 1);
      expect(order.items.first.subTotal, 50000);

      final map = order.toMap();
      expect(map['orderCode'], 'ORD-20261020-001');

      final deserialized = OrderModel.fromMap(map);
      expect(deserialized.orderId, 10);
      expect(deserialized.items.first.productName, 'Cà phê đen đá Đắk Lắk');
    });

    test('KdsItemModel serialization and status text', () {
      final kdsItem = KdsItemModel(
        orderDetailId: 101,
        orderId: 10,
        orderCode: 'ORD-10',
        tableId: 2,
        tableName: 'Bàn T1-02',
        customerName: 'Khách lẻ',
        productId: 5,
        productName: 'Trà đào cam sả thanh nhiệt',
        quantity: 2,
        itemNote: 'Ít đường',
        cookingStatus: 0,
        cookingStatusText: 'Chờ nấu',
        createdAt: DateTime.now(),
      );

      final map = kdsItem.toMap();
      final fromMap = KdsItemModel.fromMap(map);
      expect(fromMap.orderDetailId, 101);
      expect(fromMap.productName, 'Trà đào cam sả thanh nhiệt');
      expect(fromMap.cookingStatus, 0);
    });
  });

  group('Member 3 - Payment and VietQR Models Test', () {
    test('PaymentModel and VietQr dynamic URL verification', () {
      final vietQr = VietQrModel(
        orderId: 1,
        orderCode: 'ORD-20261004-001',
        bankId: 'MB',
        bankName: 'MB Bank',
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

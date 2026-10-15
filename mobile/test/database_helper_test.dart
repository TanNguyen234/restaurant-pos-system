import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';

/// Genuine In-Memory Database for verifying DatabaseHelper CRUD and aggregation operations
class InMemoryFakeDatabase implements Database {
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
    final row = Map<String, dynamic>.from(values);
    row['id'] ??= _autoId++;
    _tables[table]?.add(row);
    return row['id'] as int;
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
    final list = _tables[table] ?? [];
    var filtered = List<Map<String, dynamic>>.from(list);

    if (where != null && whereArgs != null) {
      if (where.contains('product_id = ?')) {
        filtered = filtered.where((r) => r['product_id'] == whereArgs[0]).toList();
      } else if (where.contains('id = ?')) {
        filtered = filtered.where((r) => r['id'] == whereArgs[0]).toList();
      }
    } else if (where != null && where.contains('is_synced = 0')) {
      filtered = filtered.where((r) => r['is_synced'] == 0).toList();
    }

    if (orderBy != null) {
      if (orderBy.contains('id DESC')) {
        filtered.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      } else if (orderBy.contains('id ASC')) {
        filtered.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      }
    }

    if (limit != null && filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }

    return filtered;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = _tables[table] ?? [];
    int updatedCount = 0;

    for (var i = 0; i < list.length; i++) {
      bool matches = false;
      if (where != null && whereArgs != null) {
        if (where.contains('product_id = ?')) {
          matches = list[i]['product_id'] == whereArgs[0];
        } else if (where.contains('id = ?')) {
          matches = list[i]['id'] == whereArgs[0];
        }
      } else {
        matches = true;
      }

      if (matches) {
        final updatedRow = Map<String, dynamic>.from(list[i]);
        values.forEach((k, v) => updatedRow[k] = v);
        list[i] = updatedRow;
        updatedCount++;
      }
    }

    return updatedCount;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = _tables[table] ?? [];
    if (where == null) {
      final count = list.length;
      list.clear();
      return count;
    }

    int before = list.length;
    if (where.contains('id = ?') && whereArgs != null) {
      list.removeWhere((r) => r['id'] == whereArgs[0]);
    }
    return before - list.length;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final upper = sql.toUpperCase();

    if (upper.contains('SELECT SUM(QUANTITY) AS TOTAL FROM CART_ITEMS')) {
      final items = _tables['cart_items'] ?? [];
      final total = items.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
      return [
        {'total': total}
      ];
    }

    if (upper.contains('SELECT SUM(PRICE * QUANTITY) AS TOTAL FROM CART_ITEMS')) {
      final items = _tables['cart_items'] ?? [];
      final total = items.fold<double>(
        0.0,
        (sum, row) => sum + ((row['price'] as num).toDouble() * (row['quantity'] as int)),
      );
      return [
        {'total': total}
      ];
    }

    if (upper.contains('SELECT COUNT(*) AS COUNT FROM OFFLINE_ORDERS WHERE IS_SYNCED = 0')) {
      final orders = _tables['offline_orders'] ?? [];
      final count = orders.where((r) => r['is_synced'] == 0).length;
      return [
        {'count': count}
      ];
    }

    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InMemoryFakeDatabase fakeDb;
  late DatabaseHelper helper;

  setUp(() {
    fakeDb = InMemoryFakeDatabase();
    DatabaseHelper.setDatabaseForTesting(fakeDb);
    helper = DatabaseHelper();
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  group('DatabaseHelper - User Session Operations', () {
    test('saveUserSession, getCurrentSession, isLoggedIn, and clearUserSession flow', () async {
      expect(await helper.isLoggedIn(), false);
      expect(await helper.getCurrentSession(), isNull);

      final sessionData = {
        'user_id': 1,
        'username': 'admin',
        'full_name': 'Quản Trị Viên',
        'role': 'Admin',
        'token': 'jwt_secret_token_123',
      };

      final insertId = await helper.saveUserSession(sessionData);
      expect(insertId, greaterThan(0));
      expect(await helper.isLoggedIn(), true);

      final current = await helper.getCurrentSession();
      expect(current, isNotNull);
      expect(current!['username'], 'admin');
      expect(current['full_name'], 'Quản Trị Viên');
      expect(current['logged_in_at'], isNotNull);

      // Save a second session replaces the first
      final session2 = {
        'user_id': 2,
        'username': 'waiter1',
        'full_name': 'Nhân viên A',
        'role': 'Waiter',
      };
      await helper.saveUserSession(session2);
      final current2 = await helper.getCurrentSession();
      expect(current2!['username'], 'waiter1');

      // Clear session (logout)
      await helper.clearUserSession();
      expect(await helper.isLoggedIn(), false);
      expect(await helper.getCurrentSession(), isNull);
    });
  });

  group('DatabaseHelper - Cart Operations & Total Amount Calculation', () {
    test('insertOrUpdateCart, getCartItems, getCartTotalAmount and updateCartQuantity', () async {
      expect(await helper.getCartTotalAmount(), 0.0);
      expect(await helper.getCartItemCount(), 0);

      // Add Item 1: Cà phê sữa (price: 35000, quantity: 2)
      await helper.insertOrUpdateCart({
        'product_id': 101,
        'product_name': 'Cà phê sữa đá',
        'price': 35000.0,
        'quantity': 2,
      });

      // Add Item 2: Bạc xỉu (price: 40000, quantity: 1)
      await helper.insertOrUpdateCart({
        'product_id': 102,
        'product_name': 'Bạc xỉu',
        'price': 40000.0,
        'quantity': 1,
      });

      expect(await helper.getCartItemCount(), 3);
      // 35000 * 2 + 40000 * 1 = 110,000
      expect(await helper.getCartTotalAmount(), 110000.0);

      // Adding existing item 101 with quantity 1 increments quantity to 3
      await helper.insertOrUpdateCart({
        'product_id': 101,
        'product_name': 'Cà phê sữa đá',
        'price': 35000.0,
        'quantity': 1,
      });

      expect(await helper.getCartItemCount(), 4);
      // 35000 * 3 + 40000 * 1 = 145,000
      expect(await helper.getCartTotalAmount(), 145000.0);

      // Clear cart
      await helper.clearCart();
      expect(await helper.getCartTotalAmount(), 0.0);
      expect(await helper.getCartItemCount(), 0);
    });
  });

  group('DatabaseHelper - Offline Orders Queue Operations', () {
    test('saveOfflineOrder, getUnsyncedOrders, markOrderSynced, and getUnsyncedOrderCount', () async {
      expect(await helper.getUnsyncedOrderCount(), 0);

      final order1 = {
        'table_id': 1,
        'customer_name': 'Anh Nam',
        'total_amount': 150000.0,
        'items_json': '[{"productId":1,"name":"Cà phê","price":50000,"qty":3}]',
      };

      final order2 = {
        'table_id': 2,
        'customer_name': 'Chị Hoa',
        'total_amount': 90000.0,
        'items_json': '[{"productId":2,"name":"Trà đào","price":45000,"qty":2}]',
      };

      final id1 = await helper.saveOfflineOrder(order1);
      final id2 = await helper.saveOfflineOrder(order2);

      expect(await helper.getUnsyncedOrderCount(), 2);

      final unsynced = await helper.getUnsyncedOrders();
      expect(unsynced.length, 2);
      expect(unsynced[0]['id'], id1);
      expect(unsynced[0]['is_synced'], 0);
      expect(unsynced[0]['customer_name'], 'Anh Nam');

      // Mark order 1 as synced
      await helper.markOrderSynced(id1);
      expect(await helper.getUnsyncedOrderCount(), 1);

      final remainingUnsynced = await helper.getUnsyncedOrders();
      expect(remainingUnsynced.length, 1);
      expect(remainingUnsynced[0]['id'], id2);

      // Delete order 2
      await helper.deleteOfflineOrder(id2);
      expect(await helper.getUnsyncedOrderCount(), 0);
    });
  });
}

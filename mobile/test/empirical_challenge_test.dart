import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/services/offline_sync_service.dart';

/// Accurate In-Memory Database Simulator for SQLite behavior
class EmpiricalChallengeFakeDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> tables = {
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
    tables[table]?.add(row);
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
    final list = tables[table] ?? [];
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
    final list = tables[table] ?? [];
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
    final list = tables[table] ?? [];
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

    // Genuine SQLite behavior: SUM on empty rows returns 1 row with null total!
    if (upper.contains('SELECT SUM(QUANTITY) AS TOTAL FROM CART_ITEMS')) {
      final items = tables['cart_items'] ?? [];
      if (items.isEmpty) {
        return [{'total': null}];
      }
      final total = items.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
      return [{'total': total}];
    }

    if (upper.contains('SELECT SUM(PRICE * QUANTITY) AS TOTAL FROM CART_ITEMS')) {
      final items = tables['cart_items'] ?? [];
      if (items.isEmpty) {
        // Genuine SQLite: returns [{'total': null}]
        return [{'total': null}];
      }
      final total = items.fold<double>(
        0.0,
        (sum, row) => sum + ((row['price'] as num).toDouble() * (row['quantity'] as int)),
      );
      return [{'total': total}];
    }

    if (upper.contains('SELECT COUNT(*) AS COUNT FROM OFFLINE_ORDERS WHERE IS_SYNCED = 0')) {
      final orders = tables['offline_orders'] ?? [];
      final count = orders.where((r) => r['is_synced'] == 0).length;
      return [{'count': count}];
    }

    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EmpiricalChallengeFakeDatabase fakeDb;
  late DatabaseHelper dbHelper;
  late OfflineSyncService syncService;

  setUp(() {
    HttpOverrides.global = null;
    fakeDb = EmpiricalChallengeFakeDatabase();
    DatabaseHelper.setDatabaseForTesting(fakeDb);
    dbHelper = DatabaseHelper();
    syncService = OfflineSyncService();
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
    syncService.stopPeriodicSync();
  });

  group('Empirical Challenge 1: database_helper.dart', () {
    test('1.1: getCartTotalAmount() returns 0.0 without exception when cart is empty (SQLite returns NULL)', () async {
      // Empty table in SQLite returns [{'total': null}]
      final total = await dbHelper.getCartTotalAmount();
      expect(total, 0.0);
      expect(total, isA<double>());

      final count = await dbHelper.getCartItemCount();
      expect(count, 0);
    });

    test('1.2: user_session single-session enforcement (saving session 2 destroys session 1)', () async {
      expect(await dbHelper.isLoggedIn(), false);
      expect(await dbHelper.getCurrentSession(), isNull);

      // Save session 1 (Cashier)
      await dbHelper.saveUserSession({
        'user_id': 101,
        'username': 'cashier_mai',
        'full_name': 'Nguyen Thi Mai',
        'role': 'Cashier',
        'token': 'jwt_token_aaa',
      });

      expect(await dbHelper.isLoggedIn(), true);
      var current = await dbHelper.getCurrentSession();
      expect(current!['username'], 'cashier_mai');
      expect(fakeDb.tables['user_session']!.length, 1);

      // Save session 2 (Manager) - must replace session 1 completely
      await dbHelper.saveUserSession({
        'user_id': 202,
        'username': 'manager_tuan',
        'full_name': 'Tran Van Tuan',
        'role': 'Manager',
        'token': 'jwt_token_bbb',
      });

      expect(await dbHelper.isLoggedIn(), true);
      current = await dbHelper.getCurrentSession();
      expect(current!['username'], 'manager_tuan');
      expect(current['user_id'], 202);
      // Enforce: exactly 1 session in table
      expect(fakeDb.tables['user_session']!.length, 1);

      // Clear session (Logout)
      final deleted = await dbHelper.clearUserSession();
      expect(deleted, 1);
      expect(await dbHelper.isLoggedIn(), false);
      expect(await dbHelper.getCurrentSession(), isNull);
      expect(fakeDb.tables['user_session']!.isEmpty, true);
    });

    test('1.3: offline_orders queue forces is_synced=0 and transitions to 1 on markOrderSynced', () async {
      // Adversarial attempt: pass is_synced=1 explicitly in input map
      final maliciousOrder = {
        'table_id': 5,
        'customer_name': 'Khách VIP',
        'total_amount': 250000.0,
        'items_json': '[{"id": 1, "name": "Lẩu Thái", "qty": 1, "price": 250000}]',
        'is_synced': 1, // Adversarial attempt to bypass offline queue
      };

      final orderId = await dbHelper.saveOfflineOrder(maliciousOrder);
      expect(orderId, greaterThan(0));

      // Verify that saveOfflineOrder enforced is_synced = 0
      final rawRow = fakeDb.tables['offline_orders']!.firstWhere((r) => r['id'] == orderId);
      expect(rawRow['is_synced'], 0, reason: 'saveOfflineOrder MUST enforce is_synced=0');

      // Verify getUnsyncedOrders returns this order
      final unsynced = await dbHelper.getUnsyncedOrders();
      expect(unsynced.length, 1);
      expect(unsynced.first['id'], orderId);
      expect(await dbHelper.getUnsyncedOrderCount(), 1);

      // Mark order as synced
      final updateCount = await dbHelper.markOrderSynced(orderId);
      expect(updateCount, 1);

      // Verify status transitioned to is_synced = 1 by querying the table again
      final updatedRow = fakeDb.tables['offline_orders']!.firstWhere((r) => r['id'] == orderId);
      expect(updatedRow['is_synced'], 1, reason: 'markOrderSynced MUST set is_synced=1');

      // Verify it is no longer returned in unsynced queue
      expect(await dbHelper.getUnsyncedOrders(), isEmpty);
      expect(await dbHelper.getUnsyncedOrderCount(), 0);
    });
  });

  group('Empirical Challenge 2: offline_sync_service.dart', () {
    test('2.1: checkNetworkReachability returns false when backend is unreachable (no crash)', () async {
      // Configure healthCheckUrl to a dead loopback port
      OfflineSyncService.healthCheckUrl = "http://127.0.0.1:58999/api/table/areas";

      final isOnline = await syncService.checkNetworkReachability();
      expect(isOnline, false);
    });

    test('2.2: syncNow with unreachable backend does not crash and leaves orders unsynced (is_synced=0)', () async {
      // Setup 2 unsynced orders
      await dbHelper.saveOfflineOrder({
        'table_id': 1,
        'customer_name': 'Bàn 1 Offline',
        'total_amount': 70000.0,
        'items_json': '[{"productId": 10, "qty": 2}]',
      });
      await dbHelper.saveOfflineOrder({
        'table_id': 2,
        'customer_name': 'Bàn 2 Offline',
        'total_amount': 120000.0,
        'items_json': '[{"productId": 20, "qty": 1}]',
      });

      expect(await dbHelper.getUnsyncedOrderCount(), 2);

      // Point URLs to dead port
      OfflineSyncService.healthCheckUrl = "http://127.0.0.1:58999/api/table/areas";
      OfflineSyncService.orderApiUrl = "http://127.0.0.1:58999/api/order";

      final result = await syncService.syncNow();

      expect(result.total, 2);
      expect(result.synced, 0);
      expect(result.failed, 2);
      expect(result.message, contains('Không thể kết nối'));

      // CRITICAL: orders in SQLite must NOT be marked synced!
      final unsynced = await dbHelper.getUnsyncedOrders();
      expect(unsynced.length, 2);
      for (final order in unsynced) {
        expect(order['is_synced'], 0);
      }
      expect(await dbHelper.getUnsyncedOrderCount(), 2);
    });

    test('2.3: syncNow when backend returns HTTP 500 error does NOT mark orders as synced', () async {
      // Start a real local HTTP server that simulates Backend returning 200 for health, but 500 for order
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((HttpRequest request) {
        if (request.uri.path == '/api/table/areas') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write('[]')
            ..close();
        } else if (request.uri.path == '/api/order') {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Internal Database Exception')
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });

      try {
        OfflineSyncService.healthCheckUrl = "http://127.0.0.1:$port/api/table/areas";
        OfflineSyncService.orderApiUrl = "http://127.0.0.1:$port/api/order";

        await dbHelper.saveOfflineOrder({
          'table_id': 3,
          'customer_name': 'Khách 500 Test',
          'total_amount': 50000.0,
          'items_json': '[{"id": 1}]',
        });

        final result = await syncService.syncNow();

        expect(result.total, 1);
        expect(result.synced, 0);
        expect(result.failed, 1);

        // Verify order is still unsynced
        final unsynced = await dbHelper.getUnsyncedOrders();
        expect(unsynced.length, 1);
        expect(unsynced.first['is_synced'], 0);
      } finally {
        await server.close(force: true);
      }
    });

    test('2.4: syncNow when backend returns HTTP 200 marks orders as synced (is_synced=1)', () async {
      // Start a real local HTTP server returning 200 OK for both endpoints
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final receivedPayloads = <Map<String, dynamic>>[];

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/api/table/areas') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write('[]')
            ..close();
        } else if (request.uri.path == '/api/order' && request.method == 'POST') {
          final body = await utf8.decodeStream(request);
          receivedPayloads.add(jsonDecode(body) as Map<String, dynamic>);
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'success': true, 'orderId': 999}))
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });

      try {
        OfflineSyncService.healthCheckUrl = "http://127.0.0.1:$port/api/table/areas";
        OfflineSyncService.orderApiUrl = "http://127.0.0.1:$port/api/order";

        final id = await dbHelper.saveOfflineOrder({
          'table_id': 4,
          'customer_name': 'Khách Success',
          'total_amount': 95000.0,
          'items_json': '[{"productId": 5, "name": "Sinh tố bơ", "price": 45000, "qty": 1}]',
        });

        final result = await syncService.syncNow();

        expect(result.total, 1);
        expect(result.synced, 1);
        expect(result.failed, 0);

        // Verify received payload structure matches backend expectation
        expect(receivedPayloads.length, 1);
        expect(receivedPayloads.first['offlineOrderId'], id);
        expect(receivedPayloads.first['customerName'], 'Khách Success');
        expect(receivedPayloads.first['totalAmount'], 95000.0);
        expect(receivedPayloads.first['items'], isA<List>());

        // Verify SQLite state transitioned to synced
        expect(await dbHelper.getUnsyncedOrders(), isEmpty);
        expect(await dbHelper.getUnsyncedOrderCount(), 0);
        expect(syncService.unsyncedCountNotifier.value, 0);
      } finally {
        await server.close(force: true);
      }
    });

    test('2.5: syncNow handles corrupt/malformed items_json without crashing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final receivedPayloads = <Map<String, dynamic>>[];

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/api/table/areas') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('[]')
            ..close();
        } else if (request.uri.path == '/api/order') {
          final body = await utf8.decodeStream(request);
          receivedPayloads.add(jsonDecode(body) as Map<String, dynamic>);
          request.response
            ..statusCode = HttpStatus.ok
            ..write('{"status": "ok"}')
            ..close();
        }
      });

      try {
        OfflineSyncService.healthCheckUrl = "http://127.0.0.1:$port/api/table/areas";
        OfflineSyncService.orderApiUrl = "http://127.0.0.1:$port/api/order";

        // Corrupt items_json string
        await dbHelper.saveOfflineOrder({
          'table_id': 7,
          'customer_name': 'Khách Corrupt Json',
          'total_amount': 30000.0,
          'items_json': 'NOT_VALID_JSON{:::broken',
        });

        final result = await syncService.syncNow();

        expect(result.synced, 1);
        // Parsed items should fallback safely to empty list []
        expect(receivedPayloads.first['items'], isEmpty);
      } finally {
        await server.close(force: true);
      }
    });

    test('2.6: FIFO order queue processing: 5 orders are retrieved in strict ascending ID order', () async {
      for (int i = 1; i <= 5; i++) {
        await dbHelper.saveOfflineOrder({
          'table_id': i,
          'customer_name': 'Khách #$i',
          'total_amount': i * 20000.0,
          'items_json': '[]',
        });
      }

      final unsynced = await dbHelper.getUnsyncedOrders();
      expect(unsynced.length, 5);
      for (int i = 0; i < 4; i++) {
        expect(
          (unsynced[i]['id'] as int) < (unsynced[i + 1]['id'] as int),
          true,
          reason: 'FIFO: Order ${unsynced[i]['id']} must precede ${unsynced[i + 1]['id']}',
        );
      }
    });

    test('2.7: Partial sync resilience: Order 1 fails (500) but Order 2 succeeds (200) -> only Order 2 is marked synced', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/api/table/areas') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write('[]')
            ..close();
        } else if (request.uri.path == '/api/order') {
          final body = await utf8.decodeStream(request);
          final payload = jsonDecode(body) as Map<String, dynamic>;
          final offlineId = payload['offlineOrderId'] as int;

          if (offlineId == 1) {
            // Order 1 fails on backend
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write('Server error on order 1')
              ..close();
          } else {
            // Order 2 succeeds
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write('{"success": true}')
              ..close();
          }
        }
      });

      try {
        OfflineSyncService.healthCheckUrl = "http://127.0.0.1:$port/api/table/areas";
        OfflineSyncService.orderApiUrl = "http://127.0.0.1:$port/api/order";

        final id1 = await dbHelper.saveOfflineOrder({
          'table_id': 10,
          'customer_name': 'Khách Fail 1',
          'total_amount': 50000.0,
          'items_json': '[]',
        });
        final id2 = await dbHelper.saveOfflineOrder({
          'table_id': 11,
          'customer_name': 'Khách Succeed 2',
          'total_amount': 80000.0,
          'items_json': '[]',
        });

        final result = await syncService.syncNow();

        expect(result.total, 2);
        expect(result.synced, 1);
        expect(result.failed, 1);

        // Verify id1 is still unsynced (is_synced == 0)
        final remainingUnsynced = await dbHelper.getUnsyncedOrders();
        expect(remainingUnsynced.length, 1);
        expect(remainingUnsynced.first['id'], id1);
        expect(remainingUnsynced.first['is_synced'], 0);

        // Verify id2 transitioned to is_synced == 1
        final order2Row = fakeDb.tables['offline_orders']!.firstWhere((r) => r['id'] == id2);
        expect(order2Row['is_synced'], 1);
      } finally {
        await server.close(force: true);
      }
    });

    test('2.8: Concurrency guard: second syncNow while first is running returns early', () async {
      final completer = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((HttpRequest request) async {
        if (request.uri.path == '/api/table/areas') {
          // Delay response until signaled
          await completer.future;
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write('[]')
            ..close();
        }
      });

      try {
        OfflineSyncService.healthCheckUrl = "http://127.0.0.1:$port/api/table/areas";
        OfflineSyncService.orderApiUrl = "http://127.0.0.1:$port/api/order";

        await dbHelper.saveOfflineOrder({
          'table_id': 1,
          'customer_name': 'Khách Concurrency',
          'total_amount': 10000.0,
          'items_json': '[]',
        });

        // Launch first sync (will hang waiting on completer)
        final future1 = syncService.syncNow();

        // Immediately launch second sync while first is in flight
        final result2 = await syncService.syncNow();
        expect(result2.message, 'Đang trong quá trình đồng bộ...');
        expect(result2.total, 0);

        // Complete the first sync
        completer.complete();
        await future1;
      } finally {
        await server.close(force: true);
      }
    });
  });

  group('Empirical Challenge 3: Cart Precision & Edge Cases', () {
    test('3.1: getCartTotalAmount computes floating point precision and large quantities accurately', () async {
      await dbHelper.insertOrUpdateCart({
        'product_id': 501,
        'product_name': 'Topping Thạch Trái Cây',
        'price': 12500.50,
        'quantity': 3,
      });
      await dbHelper.insertOrUpdateCart({
        'product_id': 502,
        'product_name': 'Combo Trà Sữa Size L',
        'price': 65000.25,
        'quantity': 2,
      });

      // 12500.50 * 3 + 65000.25 * 2 = 37501.50 + 130000.50 = 167502.0
      final total = await dbHelper.getCartTotalAmount();
      expect(total, 167502.0);
    });
  });
}


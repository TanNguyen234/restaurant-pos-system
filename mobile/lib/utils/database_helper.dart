import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Web in-memory storage fallback
  static Map<String, dynamic>? _webSession;
  static final List<Map<String, dynamic>> _webCart = [];
  static final List<Map<String, dynamic>> _webOrders = [];
  static int _webCartAutoId = 1;
  static int _webOrderAutoId = 1;
  static bool isTestingMode = false;
  static bool get _useInMemory => kIsWeb || isTestingMode;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  /// Test injection hook for unit tests
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'restaurant_pos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_session (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            username TEXT,
            full_name TEXT,
            role TEXT,
            token TEXT,
            logged_in_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cart_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            price REAL NOT NULL,
            quantity INTEGER NOT NULL,
            image_url TEXT,
            note TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_id INTEGER,
            customer_name TEXT,
            total_amount REAL,
            items_json TEXT,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT
          )
        ''');
      },
    );
  }

  /// Lưu phiên đăng nhập của người dùng.
  Future<int> saveUserSession(Map<String, dynamic> session) async {
    if (_useInMemory) {
      final sessionData = Map<String, dynamic>.from(session);
      sessionData['logged_in_at'] ??= DateTime.now().toIso8601String();
      _webSession = sessionData;
      return 1;
    }
    final db = await database;
    await db.delete('user_session');
    final sessionData = Map<String, dynamic>.from(session);
    sessionData['logged_in_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('user_session', sessionData);
  }

  /// Lấy thông tin phiên đăng nhập mới nhất.
  Future<Map<String, dynamic>?> getCurrentSession() async {
    if (_useInMemory) return _webSession;
    final db = await database;
    final results = await db.query(
      'user_session',
      orderBy: 'id DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Kiểm tra xem người dùng hiện tại có đang đăng nhập hay không.
  Future<bool> isLoggedIn() async {
    final session = await getCurrentSession();
    return session != null;
  }

  /// Đăng xuất - xóa toàn bộ thông tin phiên làm việc.
  Future<int> clearUserSession() async {
    if (_useInMemory) {
      _webSession = null;
      return 1;
    }
    final db = await database;
    return await db.delete('user_session');
  }

  Future<int> insertOrUpdateCart(Map<String, dynamic> item) async {
    if (_useInMemory) {
      int productId = item['product_id'];
      final idx = _webCart.indexWhere((c) => c['product_id'] == productId);
      if (idx != -1) {
        _webCart[idx]['quantity'] = (_webCart[idx]['quantity'] as int) + (item['quantity'] as int);
      } else {
        final newItem = Map<String, dynamic>.from(item);
        newItem['id'] ??= _webCartAutoId++;
        _webCart.add(newItem);
      }
      return 1;
    }
    final db = await database;
    int productId = item['product_id'];
    List<Map<String, dynamic>> existing = await db.query(
      'cart_items',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    if (existing.isNotEmpty) {
      int currentQty = existing.first['quantity'] as int;
      return await db.update(
        'cart_items',
        {'quantity': currentQty + (item['quantity'] as int)},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } else {
      return await db.insert('cart_items', item);
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    if (_useInMemory) return List<Map<String, dynamic>>.from(_webCart);
    final db = await database;
    return await db.query('cart_items');
  }

  Future<int> getCartItemCount() async {
    if (_useInMemory) {
      return _webCart.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
    }
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(quantity) as total FROM cart_items');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Tính tổng tiền tất cả món ăn trong giỏ hàng ngoại tuyến (SUM(price * quantity)).
  Future<double> getCartTotalAmount() async {
    if (_useInMemory) {
      return _webCart.fold<double>(0.0, (sum, item) => sum + ((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 0)).toDouble());
    }
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(price * quantity) as total FROM cart_items');
    var total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }

  Future<int> updateCartQuantity(int id, int quantity) async {
    if (_useInMemory) {
      if (quantity <= 0) {
        _webCart.removeWhere((c) => c['id'] == id);
      } else {
        final idx = _webCart.indexWhere((c) => c['id'] == id);
        if (idx != -1) _webCart[idx]['quantity'] = quantity;
      }
      return 1;
    }
    final db = await database;
    if (quantity <= 0) {
      return await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
    }
    return await db.update(
      'cart_items',
      {'quantity': quantity},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCartItem(int id) async {
    if (_useInMemory) {
      _webCart.removeWhere((c) => c['id'] == id);
      return 1;
    }
    final db = await database;
    return await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearCart() async {
    if (_useInMemory) {
      _webCart.clear();
      return 1;
    }
    final db = await database;
    return await db.delete('cart_items');
  }

  /// Lưu đơn hàng ngoại tuyến vào hàng đợi (is_synced = 0).
  Future<int> saveOfflineOrder(Map<String, dynamic> order) async {
    if (_useInMemory) {
      final orderData = Map<String, dynamic>.from(order);
      orderData['id'] ??= _webOrderAutoId++;
      orderData['is_synced'] = 0;
      orderData['created_at'] ??= DateTime.now().toIso8601String();
      _webOrders.insert(0, orderData);
      return orderData['id'] as int;
    }
    final db = await database;
    final orderData = Map<String, dynamic>.from(order);
    orderData['is_synced'] = 0;
    orderData['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('offline_orders', orderData);
  }

  /// Lấy danh sách các đơn hàng chưa đồng bộ (is_synced = 0).
  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    if (_useInMemory) {
      return _webOrders.where((o) => (o['is_synced'] as int? ?? 0) == 0).toList();
    }
    final db = await database;
    return await db.query(
      'offline_orders',
      where: 'is_synced = 0',
      orderBy: 'id ASC',
    );
  }

  /// Lấy toàn bộ đơn hàng ngoại tuyến đã lưu (cả đã và chưa đồng bộ).
  Future<List<Map<String, dynamic>>> getAllOfflineOrders() async {
    if (_useInMemory) {
      return List<Map<String, dynamic>>.from(_webOrders);
    }
    final db = await database;
    return await db.query('offline_orders', orderBy: 'id DESC');
  }

  /// Đánh dấu đơn hàng đã được đồng bộ thành công lên server backend (is_synced = 1).
  Future<int> markOrderSynced(int id) async {
    if (_useInMemory) {
      final idx = _webOrders.indexWhere((o) => o['id'] == id);
      if (idx != -1) _webOrders[idx]['is_synced'] = 1;
      return 1;
    }
    final db = await database;
    return await db.update(
      'offline_orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Xóa đơn hàng khỏi danh sách đơn ngoại tuyến theo ID.
  Future<int> deleteOfflineOrder(int id) async {
    if (_useInMemory) {
      _webOrders.removeWhere((o) => o['id'] == id);
      return 1;
    }
    final db = await database;
    return await db.delete('offline_orders', where: 'id = ?', whereArgs: [id]);
  }

  /// Đếm số lượng đơn hàng chưa đồng bộ lên máy chủ.
  Future<int> getUnsyncedOrderCount() async {
    if (_useInMemory) {
      return _webOrders.where((o) => (o['is_synced'] as int? ?? 0) == 0).length;
    }
    final db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_orders WHERE is_synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }
}

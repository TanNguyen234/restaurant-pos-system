import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

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
    final db = await database;
    await db.delete('user_session');
    final sessionData = Map<String, dynamic>.from(session);
    sessionData['logged_in_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('user_session', sessionData);
  }

  /// Lấy thông tin phiên đăng nhập mới nhất.
  Future<Map<String, dynamic>?> getCurrentSession() async {
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
    final db = await database;
    return await db.delete('user_session');
  }

  Future<int> insertOrUpdateCart(Map<String, dynamic> item) async {
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
    final db = await database;
    return await db.query('cart_items');
  }

  Future<int> getCartItemCount() async {
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(quantity) as total FROM cart_items');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Tính tổng tiền tất cả món ăn trong giỏ hàng ngoại tuyến (SUM(price * quantity)).
  Future<double> getCartTotalAmount() async {
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(price * quantity) as total FROM cart_items');
    var total = result.first['total'];
    if (total == null) return 0.0;
    return (total as num).toDouble();
  }

  Future<int> updateCartQuantity(int id, int quantity) async {
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
    final db = await database;
    return await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearCart() async {
    final db = await database;
    return await db.delete('cart_items');
  }

  /// Lưu đơn hàng ngoại tuyến vào hàng đợi (is_synced = 0).
  Future<int> saveOfflineOrder(Map<String, dynamic> order) async {
    final db = await database;
    final orderData = Map<String, dynamic>.from(order);
    orderData['is_synced'] = 0;
    orderData['created_at'] ??= DateTime.now().toIso8601String();
    return await db.insert('offline_orders', orderData);
  }

  /// Lấy danh sách các đơn hàng chưa đồng bộ (is_synced = 0).
  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await database;
    return await db.query(
      'offline_orders',
      where: 'is_synced = 0',
      orderBy: 'id ASC',
    );
  }

  /// Lấy toàn bộ đơn hàng ngoại tuyến đã lưu (cả đã và chưa đồng bộ).
  Future<List<Map<String, dynamic>>> getAllOfflineOrders() async {
    final db = await database;
    return await db.query('offline_orders', orderBy: 'id DESC');
  }

  /// Đánh dấu đơn hàng đã được đồng bộ thành công lên server backend (is_synced = 1).
  Future<int> markOrderSynced(int id) async {
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
    final db = await database;
    return await db.delete('offline_orders', where: 'id = ?', whereArgs: [id]);
  }

  /// Đếm số lượng đơn hàng chưa đồng bộ lên máy chủ.
  Future<int> getUnsyncedOrderCount() async {
    final db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_orders WHERE is_synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }
}

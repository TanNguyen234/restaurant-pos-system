import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

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
        // 1. Bảng lưu trữ phiên đăng nhập người dùng trên điện thoại
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

        // 2. Bảng lưu giỏ hàng ngoại tuyến (Cart)
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

        // 3. Bảng lưu đơn hàng chờ đồng bộ khi mất mạng (Offline Orders Queue)
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

  // --- CART OPERATIONS ---
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
}

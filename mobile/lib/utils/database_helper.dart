import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // In-memory storage for web or isolated testing mode (clean, no mock data)
  static Map<String, dynamic>? _webSession;
  static final List<Map<String, dynamic>> _webCart = [];
  static final List<Map<String, dynamic>> _webOrders = [];
  static final List<Map<String, dynamic>> _webCachedCategories = [];
  static final List<Map<String, dynamic>> _webCachedProducts = [];

  static int _webCartAutoId = 1;
  static int _webOrderAutoId = 1;
  static bool isTestingMode = false;
  static bool get _useInMemory => kIsWeb || isTestingMode;

  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  /// Test injection hook for unit tests
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  Future<void> refreshCartNotifier() async {
    try {
      final count = await getCartItemCount();
      cartCountNotifier.value = count;
    } catch (_) {}
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
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_session (
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
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER UNIQUE,
        product_name TEXT,
        price REAL,
        quantity INTEGER,
        image_url TEXT,
        note TEXT,
        modifiers_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER,
        customer_name TEXT,
        total_amount REAL,
        items_json TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_categories (
        id INTEGER PRIMARY KEY,
        name TEXT,
        title TEXT,
        description TEXT,
        icon TEXT,
        sort_order INTEGER,
        is_active INTEGER,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_products (
        id INTEGER PRIMARY KEY,
        name TEXT,
        category_id INTEGER,
        price REAL,
        image_url TEXT,
        is_available INTEGER,
        is_featured INTEGER,
        unit TEXT,
        description TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Lưu phiên đăng nhập của người dùng.
  Future<int> saveUserSession(Map<String, dynamic> session) async {
    if (_useInMemory) {
      _webSession = Map<String, dynamic>.from(session);
      _webSession!['logged_in_at'] = DateTime.now().toIso8601String();
      return 1;
    }
    final db = await database;
    await db.delete('user_session');

    final sessionData = Map<String, dynamic>.from(session);
    sessionData['logged_in_at'] = DateTime.now().toIso8601String();

    return await db.insert('user_session', sessionData);
  }

  /// Lấy phiên đăng nhập hiện tại.
  Future<Map<String, dynamic>?> getCurrentSession() async {
    if (_useInMemory) return _webSession;
    final db = await database;
    final results = await db.query('user_session', limit: 1);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  /// Kiểm tra xem người dùng hiện tại có đang đăng nhập hay không.
  Future<bool> isLoggedIn() async {
    final session = await getCurrentSession();
    return session != null;
  }

  /// Xóa phiên đăng nhập (đăng xuất).
  Future<int> clearUserSession() async {
    if (_useInMemory) {
      _webSession = null;
      return 1;
    }
    final db = await database;
    return await db.delete('user_session');
  }

  // --- OFFLINE MENU CACHING ---

  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    if (_useInMemory) {
      _webCachedCategories.clear();
      _webCachedCategories.addAll(categories);
      return;
    }
    try {
      final db = await database;
      final batch = db.batch();
      batch.delete('cached_categories');
      for (final c in categories) {
        batch.insert('cached_categories', {
          'id': c['id'] ?? c['categoryId'],
          'name': c['name'] ?? c['categoryName'] ?? '',
          'title': c['title'] ?? '',
          'description': c['description'] ?? '',
          'icon': c['icon'] ?? '',
          'sort_order': c['sortOrder'] ?? c['sort_order'] ?? 0,
          'is_active': (c['isActive'] ?? c['is_active'] ?? true) ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedCategories() async {
    if (_useInMemory) {
      return List<Map<String, dynamic>>.from(_webCachedCategories);
    }
    final db = await database;
    return await db.query('cached_categories', orderBy: 'sort_order ASC, id ASC');
  }

  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    if (_useInMemory) {
      _webCachedProducts.clear();
      _webCachedProducts.addAll(products);
      return;
    }
    try {
      final db = await database;
      final batch = db.batch();
      for (final p in products) {
        batch.insert('cached_products', {
          'id': p['id'] ?? p['productId'],
          'name': p['name'] ?? p['productName'] ?? '',
          'category_id': p['categoryId'] ?? p['category_id'] ?? 0,
          'price': (p['price'] as num?)?.toDouble() ?? 0.0,
          'image_url': p['imageUrl'] ?? p['image_url'] ?? '',
          'is_available': (p['isAvailable'] ?? p['is_available'] ?? true) ? 1 : 0,
          'is_featured': (p['isFeatured'] ?? p['is_featured'] ?? false) ? 1 : 0,
          'unit': p['unit'] ?? 'Phần',
          'description': p['description'] ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedProducts({int? categoryId}) async {
    if (_useInMemory) {
      if (categoryId != null && categoryId > 0) {
        return _webCachedProducts.where((p) => (p['categoryId'] ?? p['category_id']) == categoryId).toList();
      }
      return List<Map<String, dynamic>>.from(_webCachedProducts);
    }
    final db = await database;
    if (categoryId != null && categoryId > 0) {
      return await db.query('cached_products', where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'id ASC');
    }
    return await db.query('cached_products', orderBy: 'id ASC');
  }

  // --- CART OPERATIONS ---

  /// Thêm hoặc cập nhật món ăn trong giỏ hàng.
  Future<int> insertOrUpdateCart(Map<String, dynamic> item) async {
    int res = 0;
    if (_useInMemory) {
      final existingIndex = _webCart.indexWhere((i) => i['product_id'] == item['product_id']);
      if (existingIndex != -1) {
        _webCart[existingIndex]['quantity'] = (_webCart[existingIndex]['quantity'] as int) + (item['quantity'] as int);
        if (item.containsKey('note')) {
          _webCart[existingIndex]['note'] = item['note'];
        }
        if (item.containsKey('modifiers_json')) {
          _webCart[existingIndex]['modifiers_json'] = item['modifiers_json'];
        }
        res = _webCart[existingIndex]['id'] as int;
      } else {
        final newItem = Map<String, dynamic>.from(item);
        newItem['id'] = _webCartAutoId++;
        _webCart.add(newItem);
        res = newItem['id'] as int;
      }
    } else {
      final db = await database;
      final existing = await db.query(
        'cart_items',
        where: 'product_id = ?',
        whereArgs: [item['product_id']],
      );

      if (existing.isNotEmpty) {
        final currentQty = existing.first['quantity'] as int;
        final newQty = currentQty + (item['quantity'] as int);
        final updateData = <String, dynamic>{'quantity': newQty};
        if (item.containsKey('note')) {
          updateData['note'] = item['note'];
        }
        if (item.containsKey('modifiers_json')) {
          updateData['modifiers_json'] = item['modifiers_json'];
        }

        res = await db.update(
          'cart_items',
          updateData,
          where: 'product_id = ?',
          whereArgs: [item['product_id']],
        );
      } else {
        res = await db.insert('cart_items', item);
      }
    }
    await refreshCartNotifier();
    return res;
  }

  /// Lấy tất cả món ăn trong giỏ hàng.
  Future<List<Map<String, dynamic>>> getCartItems() async {
    if (_useInMemory) {
      return List<Map<String, dynamic>>.from(_webCart);
    }
    final db = await database;
    return await db.query('cart_items', orderBy: 'id ASC');
  }

  /// Đếm tổng số lượng sản phẩm (units) đang có trong giỏ hàng.
  Future<int> getCartItemCount() async {
    if (_useInMemory) {
      int sum = 0;
      for (final item in _webCart) {
        sum += (item['quantity'] as int? ?? 0);
      }
      return sum;
    }
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(quantity) as total FROM cart_items');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Tính tổng số tiền của các món ăn trong giỏ hàng.
  Future<double> getCartTotalAmount() async {
    if (_useInMemory) {
      double sum = 0;
      for (final item in _webCart) {
        sum += (item['price'] as num) * (item['quantity'] as int);
      }
      return sum;
    }
    final db = await database;
    var result = await db.rawQuery('SELECT SUM(price * quantity) as total FROM cart_items');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Cập nhật số lượng của một sản phẩm trong giỏ hàng theo product_id.
  Future<int> updateCartQuantity(int productId, int quantity) async {
    int res = 0;
    if (_useInMemory) {
      if (quantity <= 0) {
        _webCart.removeWhere((i) => i['product_id'] == productId);
      } else {
        final idx = _webCart.indexWhere((i) => i['product_id'] == productId);
        if (idx != -1) _webCart[idx]['quantity'] = quantity;
      }
      res = 1;
    } else {
      final db = await database;
      if (quantity <= 0) {
        res = await db.delete('cart_items', where: 'product_id = ?', whereArgs: [productId]);
      } else {
        res = await db.update(
          'cart_items',
          {'quantity': quantity},
          where: 'product_id = ?',
          whereArgs: [productId],
        );
      }
    }
    await refreshCartNotifier();
    return res;
  }

  /// Xóa một món ăn khỏi giỏ hàng theo product_id.
  Future<int> removeFromCart(int productId) async {
    int res = 0;
    if (_useInMemory) {
      _webCart.removeWhere((i) => i['product_id'] == productId);
      res = 1;
    } else {
      final db = await database;
      res = await db.delete('cart_items', where: 'product_id = ?', whereArgs: [productId]);
    }
    await refreshCartNotifier();
    return res;
  }

  /// Xóa một món ăn khỏi giỏ hàng theo primary key ID (cho cart_page.dart).
  Future<int> deleteCartItem(int id) async {
    int res = 0;
    if (_useInMemory) {
      _webCart.removeWhere((i) => i['id'] == id || i['product_id'] == id);
      res = 1;
    } else {
      final db = await database;
      res = await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
    }
    await refreshCartNotifier();
    return res;
  }

  /// Xóa sạch tất cả các món ăn trong giỏ hàng.
  Future<int> clearCart() async {
    int res = 0;
    if (_useInMemory) {
      _webCart.clear();
      res = 1;
    } else {
      final db = await database;
      res = await db.delete('cart_items');
    }
    await refreshCartNotifier();
    return res;
  }

  // --- OFFLINE ORDERS QUEUE ---

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

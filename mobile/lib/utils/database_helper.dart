import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Web persistence keys (SharedPreferences) + in-memory cache for fast sync
  static const String _prefSessionKey = 'pos_web_session_v1';
  static const String _prefCartKey = 'pos_web_cart_v1';
  static const String _prefOrdersKey = 'pos_web_orders_v1';
  static const String _prefCartSeqKey = 'pos_web_cart_seq_v1';
  static const String _prefOrderSeqKey = 'pos_web_order_seq_v1';

  static Map<String, dynamic>? _webSession;
  static final List<Map<String, dynamic>> _webCart = [];
  static final List<Map<String, dynamic>> _webOrders = [];
  static final List<Map<String, dynamic>> _webCachedCategories = [];
  static final List<Map<String, dynamic>> _webCachedProducts = [];

  static int _webCartAutoId = 1;
  static int _webOrderAutoId = 1;
  static bool isTestingMode = false;
  static bool _webInitialized = false;
  static bool _desktopFfiInitialized = false;
  static bool get _useInMemory => kIsWeb || isTestingMode;

  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  /// Initialize SQLite FFI for Windows/Linux/macOS desktop platforms
  static void initDesktopFfi() {
    if (kIsWeb || _desktopFfiInitialized) return;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _desktopFfiInitialized = true;
    }
  }

  /// Hydrate Web session, cart & offline orders from SharedPreferences across reloads
  Future<void> initWebPersistence() async {
    if (!kIsWeb || _webInitialized || isTestingMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionRaw = prefs.getString(_prefSessionKey);
      if (sessionRaw != null && sessionRaw.isNotEmpty) {
        _webSession = Map<String, dynamic>.from(jsonDecode(sessionRaw) as Map);
      }
      final cartRaw = prefs.getString(_prefCartKey);
      if (cartRaw != null && cartRaw.isNotEmpty) {
        _webCart
          ..clear()
          ..addAll((jsonDecode(cartRaw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
      final ordersRaw = prefs.getString(_prefOrdersKey);
      if (ordersRaw != null && ordersRaw.isNotEmpty) {
        _webOrders
          ..clear()
          ..addAll((jsonDecode(ordersRaw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
      _webCartAutoId = prefs.getInt(_prefCartSeqKey) ?? (_webCart.isEmpty ? 1 : (_webCart.map((e) => (e['id'] as int? ?? 0)).reduce((a, b) => a > b ? a : b) + 1));
      _webOrderAutoId = prefs.getInt(_prefOrderSeqKey) ?? (_webOrders.isEmpty ? 1 : (_webOrders.map((e) => (e['id'] as int? ?? 0)).reduce((a, b) => a > b ? a : b) + 1));
      _webInitialized = true;
      await refreshCartNotifier();
    } catch (_) {
      _webInitialized = true;
    }
  }

  Future<void> _persistWebState() async {
    if (!kIsWeb || isTestingMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_webSession == null) {
        await prefs.remove(_prefSessionKey);
      } else {
        await prefs.setString(_prefSessionKey, jsonEncode(_webSession));
      }
      await prefs.setString(_prefCartKey, jsonEncode(_webCart));
      await prefs.setString(_prefOrdersKey, jsonEncode(_webOrders));
      await prefs.setInt(_prefCartSeqKey, _webCartAutoId);
      await prefs.setInt(_prefOrderSeqKey, _webOrderAutoId);
    } catch (_) {}
  }

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
    initDesktopFfi();
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'restaurant_pos.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _migrateSchema(db, oldVersion);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _migrateSchema(db, 1);
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
        role_id INTEGER DEFAULT 8,
        role_name TEXT,
        email TEXT,
        phone_number TEXT,
        avatar TEXT,
        is_email_verified INTEGER DEFAULT 0,
        loyalty_points INTEGER DEFAULT 0,
        token TEXT,
        logged_in_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        variant_key TEXT UNIQUE,
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
        idempotency_key TEXT,
        table_id INTEGER,
        customer_name TEXT,
        phone_number TEXT,
        order_type INTEGER DEFAULT 1,
        note TEXT,
        discount_code TEXT,
        total_amount REAL,
        items_json TEXT,
        is_synced INTEGER DEFAULT 0,
        last_error TEXT,
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

  Future<void> _migrateSchema(Database db, int oldVersion) async {
    Future<void> ensureCol(String table, String col, String ddl) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final exists = info.any((r) => r['name'] == col);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $ddl');
      }
    }

    await ensureCol('user_session', 'role_id', 'role_id INTEGER DEFAULT 8');
    await ensureCol('user_session', 'role_name', 'role_name TEXT');
    await ensureCol('user_session', 'email', 'email TEXT');
    await ensureCol('user_session', 'phone_number', 'phone_number TEXT');
    await ensureCol('user_session', 'avatar', 'avatar TEXT');
    await ensureCol('user_session', 'is_email_verified', 'is_email_verified INTEGER DEFAULT 0');
    await ensureCol('user_session', 'loyalty_points', 'loyalty_points INTEGER DEFAULT 0');

    await ensureCol('cart_items', 'variant_key', 'variant_key TEXT');

    await ensureCol('offline_orders', 'idempotency_key', 'idempotency_key TEXT');
    await ensureCol('offline_orders', 'phone_number', 'phone_number TEXT');
    await ensureCol('offline_orders', 'order_type', 'order_type INTEGER DEFAULT 1');
    await ensureCol('offline_orders', 'note', 'note TEXT');
    await ensureCol('offline_orders', 'discount_code', 'discount_code TEXT');
    await ensureCol('offline_orders', 'last_error', 'last_error TEXT');
  }

  /// Lưu phiên đăng nhập của người dùng (hỗ trợ cả camelCase lẫn snake_case từ UserAccount.toMap)
  Future<int> saveUserSession(Map<String, dynamic> session) async {
    final normalized = <String, dynamic>{
      'user_id': session['user_id'] ?? session['accountId'] ?? 0,
      'username': session['username']?.toString() ?? '',
      'full_name': (session['full_name'] ?? session['fullName'] ?? '').toString(),
      'role': (session['role'] ?? session['roleCode'] ?? 'MEMBER').toString(),
      'role_id': session['role_id'] ?? session['roleId'] ?? 8,
      'role_name': (session['role_name'] ?? session['roleName'] ?? 'Thành viên').toString(),
      'email': session['email']?.toString(),
      'phone_number': (session['phone_number'] ?? session['phoneNumber'])?.toString(),
      'avatar': session['avatar']?.toString(),
      'is_email_verified': (session['is_email_verified'] == true ||
              session['isEmailVerified'] == true ||
              session['isEmailVerified'] == 1)
          ? 1
          : 0,
      'loyalty_points': (session['loyalty_points'] ?? session['loyaltyPoints'] as num? ?? 0).toInt(),
      'token': session['token']?.toString() ?? '',
      'logged_in_at': DateTime.now().toIso8601String(),
    };

    if (_useInMemory) {
      _webSession = Map<String, dynamic>.from(normalized);
      await _persistWebState();
      return 1;
    }

    final db = await database;
    await db.delete('user_session');
    return await db.insert('user_session', normalized);
  }

  Future<Map<String, dynamic>?> getCurrentSession() async {
    if (_useInMemory) {
      return _webSession == null ? null : Map<String, dynamic>.from(_webSession!);
    }
    final db = await database;
    final results = await db.query('user_session', limit: 1);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final session = await getCurrentSession();
    return session != null;
  }

  Future<int> clearUserSession() async {
    if (_useInMemory) {
      _webSession = null;
      await _persistWebState();
      return 1;
    }
    final db = await database;
    return await db.delete('user_session');
  }

  // --- OFFLINE MENU CACHING ---

  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    if (_useInMemory) {
      _webCachedCategories
        ..clear()
        ..addAll(categories);
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
      for (final p in products) {
        final pid = p['productId'] ?? p['id'];
        final idx = _webCachedProducts.indexWhere((x) => (x['productId'] ?? x['id']) == pid);
        if (idx >= 0) {
          _webCachedProducts[idx] = Map<String, dynamic>.from(p);
        } else {
          _webCachedProducts.add(Map<String, dynamic>.from(p));
        }
      }
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
          'unit': p['unit'] ?? 'Ly',
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

  static String _buildVariantKey(Map<String, dynamic> item) {
    final pid = item['product_id'] ?? 0;
    final mods = item['modifiers_json']?.toString() ?? '';
    final note = item['note']?.toString().trim() ?? '';
    return '$pid|$mods|$note';
  }

  Future<int> insertOrUpdateCart(Map<String, dynamic> item) async {
    final sanitized = Map<String, dynamic>.from(item);
    final variantKey = sanitized['variant_key']?.toString() ?? _buildVariantKey(sanitized);
    sanitized['variant_key'] = variantKey;

    int res = 0;
    if (_useInMemory) {
      final existingIndex = _webCart.indexWhere((i) =>
          (i['variant_key'] ?? _buildVariantKey(i)) == variantKey);
      if (existingIndex != -1) {
        _webCart[existingIndex]['quantity'] =
            (_webCart[existingIndex]['quantity'] as int) + (sanitized['quantity'] as int);
        res = _webCart[existingIndex]['id'] as int;
      } else {
        sanitized['id'] = _webCartAutoId++;
        _webCart.add(sanitized);
        res = sanitized['id'] as int;
      }
      await _persistWebState();
    } else {
      final db = await database;
      final existing = await db.query(
        'cart_items',
        where: 'variant_key = ? OR (variant_key IS NULL AND product_id = ?)',
        whereArgs: [variantKey, sanitized['product_id']],
      );

      if (existing.isNotEmpty) {
        final row = existing.first;
        final rowId = row['id'] as int;
        final currentQty = row['quantity'] as int;
        final newQty = currentQty + (sanitized['quantity'] as int);
        res = await db.update(
          'cart_items',
          {'quantity': newQty, 'variant_key': variantKey},
          where: 'id = ?',
          whereArgs: [rowId],
        );
      } else {
        res = await db.insert('cart_items', sanitized);
      }
    }
    await refreshCartNotifier();
    return res;
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    if (_useInMemory) {
      return List<Map<String, dynamic>>.from(_webCart);
    }
    final db = await database;
    return await db.query('cart_items', orderBy: 'id ASC');
  }

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

  /// Cập nhật số lượng theo cart row primary key (`id`) — chuẩn xác khi có nhiều variant cùng product_id
  Future<int> updateCartItemQuantityById(int cartRowId, int quantity) async {
    int res = 0;
    if (_useInMemory) {
      if (quantity <= 0) {
        _webCart.removeWhere((i) => i['id'] == cartRowId);
      } else {
        final idx = _webCart.indexWhere((i) => i['id'] == cartRowId);
        if (idx != -1) _webCart[idx]['quantity'] = quantity;
      }
      await _persistWebState();
      res = 1;
    } else {
      final db = await database;
      if (quantity <= 0) {
        res = await db.delete('cart_items', where: 'id = ?', whereArgs: [cartRowId]);
      } else {
        res = await db.update(
          'cart_items',
          {'quantity': quantity},
          where: 'id = ?',
          whereArgs: [cartRowId],
        );
      }
    }
    await refreshCartNotifier();
    return res;
  }

  /// Cập nhật số lượng theo product_id (giữ tương thích cho các unit test)
  Future<int> updateCartQuantity(int productId, int quantity) async {
    int res = 0;
    if (_useInMemory) {
      if (quantity <= 0) {
        _webCart.removeWhere((i) => i['product_id'] == productId);
      } else {
        final idx = _webCart.indexWhere((i) => i['product_id'] == productId);
        if (idx != -1) _webCart[idx]['quantity'] = quantity;
      }
      await _persistWebState();
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

  Future<int> removeFromCart(int productId) async {
    int res = 0;
    if (_useInMemory) {
      _webCart.removeWhere((i) => i['product_id'] == productId);
      await _persistWebState();
      res = 1;
    } else {
      final db = await database;
      res = await db.delete('cart_items', where: 'product_id = ?', whereArgs: [productId]);
    }
    await refreshCartNotifier();
    return res;
  }

  /// Xóa một món ăn khỏi giỏ hàng theo primary key ID (không xóa nhầm theo product_id!)
  Future<int> deleteCartItem(int id) async {
    int res = 0;
    if (_useInMemory) {
      _webCart.removeWhere((i) => i['id'] == id);
      await _persistWebState();
      res = 1;
    } else {
      final db = await database;
      res = await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
    }
    await refreshCartNotifier();
    return res;
  }

  Future<int> clearCart() async {
    int res = 0;
    if (_useInMemory) {
      _webCart.clear();
      await _persistWebState();
      res = 1;
    } else {
      final db = await database;
      res = await db.delete('cart_items');
    }
    await refreshCartNotifier();
    return res;
  }

  // --- OFFLINE ORDERS QUEUE ---

  Future<int> saveOfflineOrder(Map<String, dynamic> order) async {
    final orderData = Map<String, dynamic>.from(order);
    orderData['is_synced'] = 0;
    orderData['created_at'] ??= DateTime.now().toIso8601String();

    if (_useInMemory) {
      orderData['id'] ??= _webOrderAutoId++;
      _webOrders.add(orderData); // FIFO append
      await _persistWebState();
      return orderData['id'] as int;
    }

    final db = await database;
    return await db.insert('offline_orders', orderData);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    if (_useInMemory) {
      return _webOrders
          .where((o) => (o['is_synced'] as int? ?? 0) == 0)
          .toList();
    }
    final db = await database;
    return await db.query(
      'offline_orders',
      where: 'is_synced = 0',
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllOfflineOrders() async {
    if (_useInMemory) {
      return List<Map<String, dynamic>>.from(_webOrders.reversed);
    }
    final db = await database;
    return await db.query('offline_orders', orderBy: 'id DESC');
  }

  Future<int> markOrderSynced(int id) async {
    if (_useInMemory) {
      final idx = _webOrders.indexWhere((o) => o['id'] == id);
      if (idx != -1) {
        _webOrders[idx]['is_synced'] = 1;
        _webOrders[idx]['last_error'] = null;
      }
      await _persistWebState();
      return 1;
    }
    final db = await database;
    return await db.update(
      'offline_orders',
      {'is_synced': 1, 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markOrderSyncError(int id, String error) async {
    if (_useInMemory) {
      final idx = _webOrders.indexWhere((o) => o['id'] == id);
      if (idx != -1) _webOrders[idx]['last_error'] = error;
      await _persistWebState();
      return 1;
    }
    final db = await database;
    return await db.update(
      'offline_orders',
      {'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteOfflineOrder(int id) async {
    if (_useInMemory) {
      _webOrders.removeWhere((o) => o['id'] == id);
      await _persistWebState();
      return 1;
    }
    final db = await database;
    return await db.delete('offline_orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getUnsyncedOrderCount() async {
    if (_useInMemory) {
      return _webOrders.where((o) => (o['is_synced'] as int? ?? 0) == 0).length;
    }
    final db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_orders WHERE is_synced = 0');
    return (result.first['count'] as int?) ?? 0;
  }
}

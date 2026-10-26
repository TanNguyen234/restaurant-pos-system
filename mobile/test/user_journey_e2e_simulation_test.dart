import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/main.dart';
import 'package:restaurant_pos_app/models/user.dart';
import 'package:restaurant_pos_app/services/session_manager.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/views/admin/admin_category_page.dart';
import 'package:restaurant_pos_app/views/admin/admin_user_page.dart';
import 'package:restaurant_pos_app/views/kitchen/kitchen_display_page.dart';

class _E2ETestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _E2EFakeHttpClient();
}

class _E2EFakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void close({bool force = false}) {}

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    final m = method.toUpperCase();
    if (m == 'POST') return postUrl(url);
    if (m == 'PUT') return putUrl(url);
    if (m == 'DELETE') return deleteUrl(url);
    return getUrl(url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final path = url.path;

    // Phục vụ ảnh từ backend wwwroot nếu có
    if (path.endsWith('.jpg') || path.endsWith('.png')) {
      final fileName = path.split('/').last;
      File file = File('../backend/wwwroot/images/products/$fileName');
      if (!file.existsSync()) {
        file = File('../backend/wwwroot/images/categories/$fileName');
      }
      if (file.existsSync()) {
        return _ImageBytesHttpClientRequest(file.readAsBytesSync(), path.endsWith('.jpg') ? 'image/jpeg' : 'image/png');
      }
    }

    if (path.contains('/api/table/area')) {
      final jsonResp = jsonEncode([
        {'areaId': 1, 'areaName': 'Tầng trệt máy lạnh', 'sortOrder': 1, 'isActive': true},
        {'areaId': 2, 'areaName': 'Tầng 1 ban công', 'sortOrder': 2, 'isActive': true},
      ]);
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/table')) {
      final jsonResp = jsonEncode([
        {'tableId': 1, 'areaId': 1, 'tableName': 'Bàn T1-01', 'capacity': 4, 'status': 0},
        {'tableId': 2, 'areaId': 1, 'tableName': 'Bàn T1-02', 'capacity': 2, 'status': 1},
        {'tableId': 3, 'areaId': 1, 'tableName': 'Bàn T1-03', 'capacity': 6, 'status': 2},
        {'tableId': 4, 'areaId': 2, 'tableName': 'Bàn B1-01', 'capacity': 4, 'status': 0},
      ]);
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/category')) {
      final jsonResp = jsonEncode([
        {'categoryId': 1, 'name': 'Cà phê truyền thống', 'title': 'Hương vị Việt', 'description': 'Robusta Đắk Lắk đậm đà', 'sortOrder': 1},
        {'categoryId': 2, 'name': 'Cà phê pha máy (Espresso)', 'title': 'Hạt Arabica Cầu Đất', 'description': 'Hạt Arabica Cầu Đất phối trộn chuẩn vị Ý thơm ngát', 'sortOrder': 2},
        {'categoryId': 3, 'name': 'Trà trái cây tươi', 'title': 'Thanh mát', 'description': 'Trà tươi ủ mộc kết hợp cùng trái cây tươi nhiệt đới', 'sortOrder': 3},
        {'categoryId': 4, 'name': 'Đá xay & Sinh tố (Ice Blended)', 'title': 'Mát lạnh sảng khoái', 'description': 'Mát lạnh sảng khoái với lớp whipping cream béo ngậy', 'sortOrder': 4},
        {'categoryId': 5, 'name': 'Bánh ngọt & Tráng miệng', 'title': 'Bánh nướng thủ công', 'description': 'Bánh nướng thủ công thơm lừng mỗi sáng từ bơ Pháp cao cấp', 'sortOrder': 5},
      ]);
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/product/featured')) {
      final jsonResp = jsonEncode([
        {
          'productId': 1,
          'productName': 'Cà Phê Sữa Đá Sài Gòn',
          'categoryId': 1,
          'price': 29000,
          'imageUrl': 'cafe_sua_da.jpg',
          'isAvailable': true,
          'isFeatured': true,
          'unit': 'Ly',
          'description': 'Cà phê Robusta Đắk Lắk pha phin truyền thống.',
        },
      ]);
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/product')) {
      final jsonResp = jsonEncode({
        'totalItems': 2,
        'page': 1,
        'pageSize': 10,
        'totalPages': 1,
        'data': [
          {
            'productId': 1,
            'productName': 'Cà Phê Sữa Đá Sài Gòn',
            'categoryId': 1,
            'price': 29000,
            'imageUrl': 'cafe_sua_da.jpg',
            'isAvailable': true,
            'isFeatured': true,
            'unit': 'Ly',
            'description': 'Cà phê Robusta Đắk Lắk pha phin truyền thống.',
          },
          {
            'productId': 26,
            'productName': 'Phở Bò Wagyu Thượng Hạng',
            'categoryId': 5,
            'price': 89000,
            'imageUrl': 'pho_bo_wagyu.jpg',
            'isAvailable': true,
            'isFeatured': true,
            'unit': 'Tô',
            'description': 'Nước dùng ninh xương bò 24h, thăn bò Wagyu mềm tan.',
          },
        ],
      });
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/kds/active-orders')) {
      final jsonResp = jsonEncode([
        {
          'orderDetailId': 101,
          'orderId': 501,
          'orderCode': 'ORD-20261026-001',
          'tableName': 'Bàn T1-01',
          'productName': 'Cà Phê Sữa Đá Sài Gòn',
          'quantity': 2,
          'itemNote': 'Ít đường nhiều sữa',
          'cookingStatus': 0, // Chờ nấu
          'createdAt': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
        },
        {
          'orderDetailId': 102,
          'orderId': 501,
          'orderCode': 'ORD-20261026-001',
          'tableName': 'Bàn T1-01',
          'productName': 'Phở Bò Wagyu Thượng Hạng',
          'quantity': 1,
          'itemNote': 'Không hành lá',
          'cookingStatus': 1, // Đang làm
          'createdAt': DateTime.now().subtract(const Duration(minutes: 6)).toIso8601String(),
        },
      ]);
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/order')) {
      final jsonResp = jsonEncode({
        'orderId': 888,
        'orderCode': 'ORD-SIMULATED-888',
        'tableId': 1,
        'tableName': 'Bàn T1-01',
        'customerName': 'Khách tại Bàn T1-01',
        'orderType': 1,
        'totalAmount': 147000.0,
        'discountAmount': 0.0,
        'finalAmount': 147000.0,
        'status': 0,
        'paymentStatus': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'items': [
          {
            'orderDetailId': 101,
            'productId': 1,
            'productName': 'Cà Phê Sữa Đá Sài Gòn',
            'quantity': 2,
            'price': 29000.0,
            'totalPrice': 58000.0,
          },
          {
            'orderDetailId': 102,
            'productId': 26,
            'productName': 'Phở Bò Wagyu Thượng Hạng',
            'quantity': 1,
            'price': 89000.0,
            'totalPrice': 89000.0,
          },
        ],
      });
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/account/members')) {
      final jsonResp = jsonEncode([
        {
          'accountId': 1,
          'roleId': 1,
          'roleCode': 'ADMIN',
          'roleName': 'Quản trị viên hệ thống',
          'username': 'admin',
          'fullName': 'Nguyễn Văn Quản Trị',
          'email': 'admin@restaurantpos.vn',
          'phoneNumber': '0901234567',
        },
        {
          'accountId': 4,
          'roleId': 4,
          'roleCode': 'WAITER',
          'roleName': 'Nhân viên phục vụ',
          'username': 'waiter_nam',
          'fullName': 'Phạm Hoàng Nam',
          'email': 'nam.waiter@restaurantpos.vn',
          'phoneNumber': '0904567890',
        },
        {
          'accountId': 11,
          'roleId': 11,
          'roleCode': 'KITCHEN',
          'roleName': 'Bộ phận bếp & pha chế (KDS)',
          'username': 'kitchen',
          'fullName': 'Bếp Trưởng KDS',
          'email': 'kitchen@restaurantpos.vn',
          'phoneNumber': '0907890123',
        },
      ]);
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    return _E2EJsonHttpClientRequest('{}');
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    final path = url.path;

    if (path.contains('/api/order')) {
      final jsonResp = jsonEncode({
        'success': true,
        'orderId': 888,
        'orderCode': 'ORD-SIMULATED-888',
        'totalAmount': 147000.0,
        'message': 'Tạo đơn hàng thành công và chuyển thông tin xuống bếp KDS!',
      });
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    if (path.contains('/api/auth/login')) {
      final jsonResp = jsonEncode({
        'success': true,
        'token': 'jwt_simulated_token_pos_2026',
        'accountId': 11,
        'roleId': 11,
        'roleCode': 'KITCHEN',
        'roleName': 'Bộ phận bếp & pha chế (KDS)',
        'username': 'kitchen',
        'fullName': 'Bếp Trưởng KDS',
        'email': 'kitchen@restaurantpos.vn',
        'phoneNumber': '0907890123',
        'message': 'Đăng nhập thành công',
      });
      return _E2EJsonHttpClientRequest(jsonResp);
    }

    return _E2EJsonHttpClientRequest('{"success": true}');
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    return _E2EJsonHttpClientRequest('{"success": true}');
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async {
    return _E2EJsonHttpClientRequest('{"success": true, "message": "Xóa thành công"}');
  }
}

class _E2EJsonHttpClientRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  _E2EJsonHttpClientRequest(this.responseBody);

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
  final HttpHeaders headers = _FakeE2EHttpHeaders('application/json; charset=utf-8');

  @override
  Future<HttpClientResponse> close() async => _E2EJsonHttpClientResponse(responseBody);
}

class _E2EJsonHttpClientResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  _E2EJsonHttpClientResponse(this.responseBody);

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
  final HttpHeaders headers = _FakeE2EHttpHeaders('application/json; charset=utf-8');
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(utf8.encode(responseBody)).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class _ImageBytesHttpClientRequest extends Fake implements HttpClientRequest {
  final List<int> bytes;
  final String contentType;
  _ImageBytesHttpClientRequest(this.bytes, this.contentType);

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
  late final HttpHeaders headers = _FakeE2EHttpHeaders(contentType);

  @override
  Future<HttpClientResponse> close() async => _ImageBytesHttpClientResponse(bytes, contentType);
}

class _ImageBytesHttpClientResponse extends Fake implements HttpClientResponse {
  final List<int> bytes;
  final String contentType;
  _ImageBytesHttpClientResponse(this.bytes, this.contentType);

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
  int get contentLength => bytes.length;
  @override
  late final HttpHeaders headers = _FakeE2EHttpHeaders(contentType);
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class _FakeE2EHttpHeaders extends Fake implements HttpHeaders {
  final String cType;
  _FakeE2EHttpHeaders(this.cType);

  @override
  List<String>? operator [](String name) => name.toLowerCase() == 'content-type' ? [cType] : null;
  @override
  String? value(String name) => name.toLowerCase() == 'content-type' ? cType : null;
  @override
  void forEach(void Function(String name, List<String> values) action) => action('content-type', [cType]);
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

Future<void> _loadTestFonts() async {
  // 1. MaterialIcons
  final iconFile = File(r'D:\Download\DevTools\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf');
  if (iconFile.existsSync()) {
    final bytes = iconFile.readAsBytesSync();
    final loader = FontLoader('MaterialIcons');
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  // 2. CupertinoIcons
  final cupertinoFile = File('build/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf');
  if (cupertinoFile.existsSync()) {
    final bytes = cupertinoFile.readAsBytesSync();
    final loader = FontLoader('packages/cupertino_icons/CupertinoIcons');
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  // 3. Typography Fonts (Segoe UI with Vietnamese diacritics)
  final regularFile = File(r'C:\Windows\Fonts\segoeui.ttf');
  final boldFile = File(r'C:\Windows\Fonts\segoeuib.ttf');
  if (regularFile.existsSync()) {
    final regBytes = regularFile.readAsBytesSync();
    final boldBytes = boldFile.existsSync() ? boldFile.readAsBytesSync() : regBytes;

    for (final name in ['Roboto', 'Segoe UI', 'Arial', 'sans-serif']) {
      final loader = FontLoader(name);
      loader.addFont(Future.value(ByteData.view(regBytes.buffer)));
      loader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
      await loader.load();
    }
  }
}

Future<void> _captureScreen(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(pngBytes);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadTestFonts();
    DatabaseHelper.isTestingMode = true;
    HttpOverrides.global = _E2ETestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('E2E User Journey Simulation: Multi-step Realistic Test & Step-by-Step Screenshots', (WidgetTester tester) async {
    // Kích thước chuẩn màn hình điện thoại hiện đại (Pixel / iPhone 1080x2340)
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final screenKey = GlobalKey();

    // Khởi động toàn bộ ứng dụng từ Gốc (Root App)
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenKey,
        child: const RestaurantPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    // -------------------------------------------------------------
    // BƯỚC 1: SƠ ĐỒ BÀN ĂN (FLOOR TABLE PLAN)
    // -------------------------------------------------------------
    expect(find.text('Sơ đồ bàn ăn'), findsOneWidget);
    expect(find.text('Bàn T1-01'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step01_floor_table_initial.png');

    // -------------------------------------------------------------
    // BƯỚC 2: CHỌN BÀN T1-01 -> MỞ ACTION SHEET
    // -------------------------------------------------------------
    await tester.tap(find.text('Bàn T1-01'));
    await tester.pumpAndSettle();

    expect(find.text('Gọi món / Đặt món cho bàn'), findsOneWidget);
    expect(find.text('Đổi trạng thái bàn'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step02_table_action_sheet.png');

    // Đóng Action Sheet
    Navigator.of(tester.element(find.text('Gọi món / Đặt món cho bàn'))).pop();
    await tester.pumpAndSettle();

    // -------------------------------------------------------------
    // BƯỚC 3: DI CHUYỂN SANG TAB THỰC ĐƠN & THÊM MÓN VÀO GIỎ
    // -------------------------------------------------------------
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();

    expect(find.text('Thực đơn & Danh mục'), findsOneWidget);

    // Thêm món vào SQLite giỏ hàng
    await DatabaseHelper().clearCart();
    await DatabaseHelper().insertOrUpdateCart({
      'product_id': 1,
      'product_name': 'Cà Phê Sữa Đá Sài Gòn',
      'price': 29000.0,
      'quantity': 2,
      'image_url': 'cafe_sua_da.jpg',
      'note': 'Ít đường, nhiều sữa',
    });
    await DatabaseHelper().insertOrUpdateCart({
      'product_id': 26,
      'product_name': 'Phở Bò Wagyu Thượng Hạng',
      'price': 89000.0,
      'quantity': 1,
      'image_url': 'pho_bo_wagyu.jpg',
      'note': 'Không hành lá',
    });

    await tester.pumpAndSettle();
    // Kiểm tra cart count badge hiển thị tổng số lượng 3 món (2 + 1)
    expect(DatabaseHelper().cartCountNotifier.value, 3);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step03_menu_cart_badge_updated.png');

    // -------------------------------------------------------------
    // BƯỚC 4: CHUYỂN SANG TAB GIỎ HÀNG (CART PAGE)
    // -------------------------------------------------------------
    await tester.tap(find.text('Giỏ hàng'));
    await tester.pumpAndSettle();

    expect(find.text('Giỏ hàng gọi món'), findsOneWidget);
    expect(find.text('Cà Phê Sữa Đá Sài Gòn'), findsOneWidget);
    expect(find.text('Phở Bò Wagyu Thượng Hạng'), findsOneWidget);
    expect(find.text('TIẾN HÀNH ĐẶT MÓN'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step04_cart_screen_checkout.png');

    // -------------------------------------------------------------
    // BƯỚC 5: TIẾN HÀNH ĐẶT MÓN -> MỞ ORDER CHECKOUT PAGE
    // -------------------------------------------------------------
    await tester.tap(find.text('TIẾN HÀNH ĐẶT MÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận đặt món & Thanh toán'), findsOneWidget);
    expect(find.textContaining('Xác Nhận Đặt Món'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step05_checkout_order_creation.png');

    // -------------------------------------------------------------
    // BƯỚC 6: XÁC NHẬN GỬI ĐƠN -> DỌN SẠCH GIỎ HÀNG
    // -------------------------------------------------------------
    final checkoutBtn = find.textContaining('Xác Nhận Đặt Món');
    await tester.ensureVisible(checkoutBtn);
    await tester.pumpAndSettle();
    await tester.tap(checkoutBtn);
    await tester.pumpAndSettle();

    // OrderDetailPage hiển thị chi tiết đơn hàng
    expect(find.text('ORD-SIMULATED-888'), findsOneWidget);
    expect(DatabaseHelper().cartCountNotifier.value, 0);

    // Quay lại giỏ hàng -> Kiểm tra giỏ hàng đã dọn sạch hoàn toàn (0 món)
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Giỏ hàng của bạn đang trống'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step06_cart_cleared_after_order.png');

    // -------------------------------------------------------------
    // BƯỚC 7: MÀN HÌNH BẾP & PHA CHẾ (KITCHEN DISPLAY KDS)
    // -------------------------------------------------------------
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: RepaintBoundary(
          key: screenKey,
          child: const KitchenDisplayPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Màn hình Bếp & Pha chế (KDS)'), findsOneWidget);
    expect(find.text('Chờ nấu'), findsOneWidget);
    expect(find.text('Đang làm'), findsOneWidget);
    expect(find.text('Cà Phê Sữa Đá Sài Gòn'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step07_kitchen_kds_active_order.png');

    // -------------------------------------------------------------
    // BƯỚC 8: QUẢN TRỊ DANH MỤC (ADMIN CATEGORY PAGE - FIX OVERFLOW)
    // -------------------------------------------------------------
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: RepaintBoundary(
          key: screenKey,
          child: const AdminCategoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản trị Danh mục'), findsOneWidget);
    expect(find.text('Cà phê pha máy (Espresso)'), findsOneWidget);
    expect(find.text('Đá xay & Sinh tố (Ice Blended)'), findsOneWidget);
    // Xác nhận không còn lỗi RenderFlex overflow
    expect(tester.takeException(), isNull);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step08_admin_category_no_overflow.png');

    // -------------------------------------------------------------
    // BƯỚC 9: MENU VẬN HÀNH & TÀI KHOẢN ĐĂNG NHẬP / ĐĂNG XUẤT (RBAC)
    // -------------------------------------------------------------
    await SessionManager.instance.setSession(
      UserAccount(
        accountId: 11,
        roleId: 11,
        username: 'kitchen',
        fullName: 'Bếp Trưởng KDS',
        email: 'kitchen@restaurantpos.vn',
        phoneNumber: '0907890123',
        role: 'KITCHEN',
        roleName: 'Bộ phận bếp & pha chế (KDS)',
      ),
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: screenKey,
        child: const RestaurantPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Mở menu vận hành bằng FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Kiểm tra tên tiếng Việt sạch (Bếp Trưởng KDS), vai trò sạch (Bộ phận bếp & pha chế (KDS))
    expect(find.text('Bếp Trưởng KDS'), findsOneWidget);
    expect(find.text('Bộ phận bếp & pha chế (KDS)'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step09_operations_menu_rbac_logout.png');

    // Đóng bottom sheet
    tester.binding.handlePointerEvent(const PointerDownEvent(position: Offset(50, 50)));
    tester.binding.handlePointerEvent(const PointerUpEvent(position: Offset(50, 50)));
    await tester.pumpAndSettle();

    // -------------------------------------------------------------
    // BƯỚC 10: QUẢN TRỊ NGƯỜI DÙNG & VAI TRÒ (ADMIN USER MANAGEMENT)
    // -------------------------------------------------------------
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: RepaintBoundary(
          key: screenKey,
          child: const AdminUserPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản trị Người dùng & Vai trò'), findsOneWidget);
    expect(find.text('Bếp Trưởng KDS'), findsOneWidget);
    expect(find.text('Phạm Hoàng Nam'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _captureScreen(tester, screenKey, '../docs/acceptance/screenshots/step10_admin_user_management.png');
  });
}

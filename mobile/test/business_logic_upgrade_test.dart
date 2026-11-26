import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_pos_app/models/product.dart';
import 'package:restaurant_pos_app/repositories/inventory_repository.dart';
import 'package:restaurant_pos_app/repositories/order_repository.dart';
import 'package:restaurant_pos_app/repositories/product_repository.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';
import 'package:restaurant_pos_app/services/csv_export_service.dart';
import 'package:restaurant_pos_app/services/escpos_printer_service.dart';
import 'package:restaurant_pos_app/services/realtime_service.dart';
import 'package:restaurant_pos_app/utils/category_helper.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/views/admin/admin_inventory_page.dart';
import 'package:restaurant_pos_app/views/admin/admin_user_page.dart';
import 'package:restaurant_pos_app/views/home_page.dart';
import 'package:restaurant_pos_app/views/table/floor_table_page.dart';
import 'package:sqflite/sqflite.dart';

class _TestFakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
  }) async =>
      [];

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async =>
      [{'count': 0, 'total': 0}];

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async =>
      1;
}

class _TestHttpOverrides extends HttpOverrides {
  final String Function(Uri uri, String method) handler;
  _TestHttpOverrides(this.handler);

  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient(handler);
}

class _TestHttpClient extends Fake implements HttpClient {
  final String Function(Uri uri, String method) handler;
  _TestHttpClient(this.handler);

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _TestHttpRequest(handler(url, method));
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
}

class _TestHttpRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  _TestHttpRequest(this.responseBody);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = false;
  @override
  int contentLength = -1;
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  void add(List<int> data) {}
  @override
  Future addStream(Stream<List<int>> stream) async => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _TestHttpResponse(responseBody);
}

class _TestHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _map = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _map.forEach(action);
  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];
  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = [value.toString()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
}

class _TestHttpResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  _TestHttpResponse(this.responseBody);

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
  int get contentLength => utf8.encode(responseBody).length;
  @override
  final HttpHeaders headers = _TestHttpHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUp(() {
    PosRealtimeService.isTestingMode = true;
    DatabaseHelper.setDatabaseForTesting(_TestFakeDatabase());
    TableRepository.timeoutDuration = const Duration(milliseconds: 500);
    InventoryRepository.timeoutDuration;
    ProductRepository.timeoutDuration = const Duration(milliseconds: 500);
  });

  tearDown(() {
    PosRealtimeService.instance.dispose();
    PosRealtimeService.isTestingMode = false;
    DatabaseHelper.setDatabaseForTesting(null);
    HttpOverrides.global = null;
  });

  test('ESC/POS sanitizeAscii and buildReceiptBytes handle Vietnamese, symbols & emoji without ArgumentError', () {
    final safe = EscPosPrinterService.sanitizeAscii('Cà phê sữa đá • Size L — 45,000₫ 😊');
    expect(safe, 'Ca phe sua da * Size L - 45,000d  ');

    final bytes = EscPosPrinterService.buildReceiptBytes({
      'orderCode': 'ORD-20261126-TEST01',
      'tableName': 'Phòng VIP 01 • Tầng 2',
      'customerName': 'Đỗ Minh Đức 🍜',
      'finalAmount': 125000,
      'paidAmount': 125000,
      'details': [
        {
          'productName': 'Bún Bò Huế — Đặc Biệt',
          'quantity': 2,
          'unitPrice': 62500,
          'subTotal': 125000,
          'modifiers': [
            {'modifierName': 'Size L • Thêm gân'},
          ],
          'itemNote': 'Ít cay 😊',
        },
      ],
    });

    expect(bytes, isNotEmpty);
    final decoded = ascii.decode(bytes, allowInvalid: true);
    expect(decoded, contains('ORD-20261126-TEST01'));
    expect(decoded, contains('Bun Bo Hue - Dac Biet'));
  });

  test('isDrinkCategory classifies drink vs food categories consistently', () {
    for (final catId in [1, 2, 3, 4, 5, 9, 10]) {
      expect(isDrinkCategory(catId), isTrue, reason: 'Category $catId should be drink');
    }
    for (final catId in [6, 7, 8]) {
      expect(isDrinkCategory(catId), isFalse, reason: 'Category $catId should be food');
    }
  });

  test('CsvExportService saves real .csv file with UTF-8 BOM to target directory', () async {
    final tmpDir = Directory.systemTemp.createTempSync('pos_csv_test_');
    try {
      final csvBytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('OrderId,OrderCode\n1,"ORD-001"\n'),
      ]);
      final res = await CsvExportService.saveOrShareCsv(
        fileName: 'orders_export_test.csv',
        bytes: csvBytes,
        customDirectoryPath: tmpDir.path,
      );

      expect(res.savedAsFile, isTrue);
      expect(res.savedPath, isNotNull);
      final outFile = File(res.savedPath!);
      expect(outFile.existsSync(), isTrue);

      final raw = await outFile.readAsBytes();
      expect(raw.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(raw.sublist(3)), 'OrderId,OrderCode\n1,"ORD-001"\n');
    } finally {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    }
  });

  testWidgets('FloorTablePage distinguishes status 2 (Chờ phục vụ / occupied) vs status 3 (Đã đặt trước) & 4-status dialog', (tester) async {
    HttpOverrides.global = _TestHttpOverrides((uri, method) {
      if (uri.path.contains('/areas')) {
        return jsonEncode([
          {'areaId': 1, 'areaName': 'Sảnh Chính', 'sortOrder': 1, 'isActive': true},
        ]);
      }
      if (uri.path.endsWith('/api/table')) {
        return jsonEncode([
          {'tableId': 1, 'areaId': 1, 'tableName': 'Bàn 02', 'capacity': 4, 'status': 2},
          {'tableId': 2, 'areaId': 1, 'tableName': 'Bàn 03', 'capacity': 6, 'status': 3},
        ]);
      }
      if (uri.path.contains('/reservations')) {
        return jsonEncode([]);
      }
      return '{}';
    });

    await tester.pumpWidget(const MaterialApp(home: FloorTablePage()));
    await tester.pumpAndSettle();

    expect(find.text('Có khách: 1'), findsOneWidget);
    expect(find.text('Đặt trước: 1'), findsOneWidget);

    // Tap table with status 2 -> shows occupied actions, NOT check-in/cancel reservation
    await tester.tap(find.text('Bàn 02'));
    await tester.pumpAndSettle();

    expect(find.text('Gộp bàn'), findsOneWidget);
    expect(find.text('Khách đến nhận bàn'), findsNothing);

    // Open status dialog -> exposes all 4 statuses (0..3)
    await tester.tap(find.text('Đổi trạng thái bàn'));
    await tester.pumpAndSettle();
    expect(find.text('Bàn trống'), findsOneWidget);
    expect(find.text('Có khách'), findsOneWidget);
    expect(find.text('Chờ phục vụ'), findsOneWidget);
    expect(find.text('Đã đặt trước'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    // Tap table with status 3 -> shows Check-in & Cancel reservation actions
    await tester.tap(find.text('Bàn 03'));
    await tester.pumpAndSettle();
    expect(find.text('Khách đến nhận bàn'), findsOneWidget);
    expect(find.text('Hủy đặt bàn'), findsOneWidget);
  });

  testWidgets('AdminInventoryPage hides FAB on Tab 2 and keeps full unfiltered ingredients in BOM dropdown', (tester) async {
    HttpOverrides.global = _TestHttpOverrides((uri, method) {
      if (uri.path.contains('/api/inventory/ingredients')) {
        final search = uri.queryParameters['search'] ?? '';
        final all = [
          {'ingredientId': 1, 'ingredientName': 'Cà phê Robusta', 'unit': 'gram', 'currentStock': 5000, 'minThreshold': 500, 'costPerUnit': 320, 'isActive': true},
          {'ingredientId': 2, 'ingredientName': 'Sữa đặc có đường', 'unit': 'ml', 'currentStock': 4000, 'minThreshold': 500, 'costPerUnit': 45, 'isActive': true},
        ];
        final filtered = search.isEmpty
            ? all
            : all.where((i) => i['ingredientName'].toString().toLowerCase().contains(search.toLowerCase())).toList();
        return jsonEncode({'lowStockCount': 0, 'data': filtered});
      }
      if (uri.path.contains('/api/inventory/transactions')) {
        return jsonEncode({'data': []});
      }
      if (uri.path.contains('/api/inventory/recipes/1')) {
        return jsonEncode({'data': [], 'attributeRecipes': []});
      }
      if (uri.path.endsWith('/api/product')) {
        return jsonEncode({
          'totalItems': 1,
          'page': 1,
          'pageSize': 100,
          'totalPages': 1,
          'data': [
            {
              'productId': 1,
              'categoryId': 1,
              'productName': 'Bạc Xỉu',
              'price': 45000,
              'unit': 'Ly',
              'imageUrl': '/img/1.png',
              'isAvailable': true,
              'autoDisabledByStock': false,
              'isFeatured': false,
              'attributes': [],
            }
          ],
        });
      }
      return '{}';
    });

    await tester.pumpWidget(const MaterialApp(home: AdminInventoryPage()));
    await tester.pumpAndSettle();

    // Tab 0 shows Add Ingredient FAB
    expect(find.text('Thêm nguyên liệu'), findsOneWidget);

    // Filter Tab 0 to only "Cà phê"
    await tester.enterText(find.byType(TextField).first, 'Cà phê');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Cà phê Robusta'), findsOneWidget);
    expect(find.text('Sữa đặc có đường'), findsNothing);

    // Switch to Tab 1 (Định lượng BOM) -> FAB switches to Thêm BOM, dialog lists ALL unfiltered ingredients
    await tester.tap(find.text('Định lượng BOM'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm BOM'), findsOneWidget);

    await tester.tap(find.text('Thêm BOM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cà phê Robusta (gram)'));
    await tester.pumpAndSettle();
    expect(find.text('Sữa đặc có đường (ml)'), findsOneWidget);

    // Close dropdown & dialog
    await tester.tap(find.text('Sữa đặc có đường (ml)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    // Switch to Tab 2 (Lịch sử kho) -> FAB is hidden
    await tester.tap(find.text('Lịch sử kho'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  group('P2 regression tests (#15, #16, #18, #19)', () {
    test('OrderRepository.getAnalytics sends days, fromDate, and toDate query parameters', () async {
      Uri? capturedUri;
      HttpOverrides.global = _TestHttpOverrides((uri, method) {
        capturedUri = uri;
        return jsonEncode({
          'dailyRevenue': [],
          'hourlyOrders': [],
          'paymentMethods': [],
        });
      });

      final from = DateTime.utc(2026, 11, 1, 0, 0, 0);
      final to = DateTime.utc(2026, 11, 26, 23, 59, 59);
      final data = await OrderRepository().getAnalytics(
        days: 14,
        fromDate: from,
        toDate: to,
      );

      expect(data['dailyRevenue'], isList);
      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, endsWith('/api/order/analytics'));
      expect(capturedUri!.queryParameters['days'], '14');
      expect(capturedUri!.queryParameters['fromDate'], from.toIso8601String());
      expect(capturedUri!.queryParameters['toDate'], to.toIso8601String());
    });

    test('OrderRepository.createOrder only queues offline on transport errors, not FormatException', () async {
      DatabaseHelper.isTestingMode = true;
      DatabaseHelper.setDatabaseForTesting(null);
      addTearDown(() async {
        await DatabaseHelper().clearCart();
        DatabaseHelper.isTestingMode = false;
      });

      final payload = {
        'customerName': 'P2 Error Boundary Check',
        'orderType': 1,
        'items': [
          {'productId': 1, 'quantity': 1}
        ],
      };

      final beforeCount = (await DatabaseHelper().getUnsyncedOrders())
          .where((o) => o['customer_name'] == 'P2 Error Boundary Check')
          .length;

      final formatRes = await http.runWithClient(
        () => OrderRepository().createOrder(payload),
        () => _StubBaseClient((_) async => throw const FormatException('Malformed payload')),
      );
      expect(formatRes['success'], isFalse);
      expect(formatRes['isOffline'], isFalse);
      expect(formatRes['message'].toString(), contains('Lỗi xử lý đơn hàng'));

      final afterFormatCount = (await DatabaseHelper().getUnsyncedOrders())
          .where((o) => o['customer_name'] == 'P2 Error Boundary Check')
          .length;
      expect(afterFormatCount, beforeCount);

      final offlineRes = await http.runWithClient(
        () => OrderRepository().createOrder(payload),
        () => _StubBaseClient((_) async => throw http.ClientException('Connection refused')),
      );
      expect(offlineRes['success'], isTrue);
      expect(offlineRes['isOffline'], isTrue);

      final afterOfflineCount = (await DatabaseHelper().getUnsyncedOrders())
          .where((o) => o['customer_name'] == 'P2 Error Boundary Check')
          .length;
      expect(afterOfflineCount, beforeCount + 1);
    });

    test('AdminUserPage fallback roles match canonical SQL Roles IDs', () {
      final byCode = {
        for (final r in AdminUserPage.debugFallbackRoles) r['roleCode']: r['roleId'],
      };
      expect(byCode['ADMIN'], 1);
      expect(byCode['MANAGER'], 2);
      expect(byCode['CASHIER'], 3);
      expect(byCode['WAITER'], 4);
      expect(byCode['BARISTA_LEAD'], 5);
      expect(byCode['HEAD_CHEF'], 6);
      expect(byCode['COOK_ASSISTANT'], 7);
      expect(byCode['MEMBER'], 8);
      expect(byCode['VIP_MEMBER'], 9);
      expect(byCode['DELIVERY_PARTNER'], 10);
      expect(byCode['KITCHEN'], 11);
    });

    test('HomePage.buildQuickAddCartItem auto-selects lowest-extraPrice option per required group', () async {
      DatabaseHelper.isTestingMode = true;
      DatabaseHelper.setDatabaseForTesting(null);
      await DatabaseHelper().clearCart();
      addTearDown(() async {
        await DatabaseHelper().clearCart();
        DatabaseHelper.isTestingMode = false;
      });

      final product = Product(
        productId: 99,
        categoryId: 1,
        productName: 'Trà Sữa Ô Long',
        price: 35000,
        imageUrl: '',
        isAvailable: true,
        attributes: [
          ProductAttribute(
            attributeId: 102,
            productId: 99,
            attributeGroup: 'Size',
            attributeName: 'Size L',
            extraPrice: 8000,
            isRequired: true,
          ),
          ProductAttribute(
            attributeId: 101,
            productId: 99,
            attributeGroup: 'Size',
            attributeName: 'Size M',
            extraPrice: 0,
            isRequired: true,
          ),
          ProductAttribute(
            attributeId: 103,
            productId: 99,
            attributeGroup: 'Topping',
            attributeName: 'Trân châu trắng',
            extraPrice: 7000,
            isRequired: false,
          ),
        ],
      );

      final cartItem = HomePage.buildQuickAddCartItem(product);
      await DatabaseHelper().insertOrUpdateCart(cartItem);

      final items = await DatabaseHelper().getCartItems();
      expect(items.length, 1);
      expect(items.first['price'], 35000.0);
      expect(items.first['note'], 'Size M');
      final decodedMods = jsonDecode(items.first['modifiers_json'] as String) as List<dynamic>;
      expect(decodedMods.length, 1);
      expect(decodedMods.first['attributeId'], 101);
      expect(decodedMods.first['modifierName'], 'Size M');
      expect(decodedMods.first['modifierGroup'], 'Size');
      expect(decodedMods.first['extraPrice'], 0.0);
    });
  });
}

class _StubBaseClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;
  _StubBaseClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler(request);
}

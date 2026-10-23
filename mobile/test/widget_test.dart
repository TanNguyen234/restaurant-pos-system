import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_pos_app/main.dart';
import 'package:restaurant_pos_app/models/category.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';

class WidgetTestFakeDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> _tables = {
    'user_session': [],
    'cart_items': [],
    'offline_orders': [],
  };

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
  }) async {
    return _tables[table] ?? [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    return [
      {'count': 0, 'total': 0}
    ];
  }
}

class _WidgetTestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _WidgetFakeHttpClient();
}

class _WidgetFakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    String jsonResp = '[]';
    final path = url.path;
    if (path.contains('/api/product/featured')) {
      jsonResp = '[]';
    } else if (path.contains('/api/product')) {
      jsonResp = jsonEncode({
        'totalItems': 0,
        'page': 1,
        'pageSize': 10,
        'totalPages': 0,
        'data': [],
      });
    } else if (path.contains('/api/category') || path.contains('/api/table')) {
      jsonResp = '[]';
    }
    return _WidgetFakeHttpClientRequest(jsonResp);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);
  @override
  void close({bool force = false}) {}
}

class _WidgetFakeHttpClientRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  _WidgetFakeHttpClientRequest(this.responseBody);

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
  final HttpHeaders headers = _WidgetFakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _WidgetFakeHttpClientResponse(responseBody);
}

class _WidgetFakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {
    'content-type': ['application/json; charset=utf-8'],
  };
  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];
  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;
  @override
  void forEach(void Function(String name, List<String> values) action) => _headers.forEach(action);
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => _headers[name.toLowerCase()] = [value.toString()];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) => _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
}

class _WidgetFakeHttpClientResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  _WidgetFakeHttpClientResponse(this.responseBody);

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
  final HttpHeaders headers = _WidgetFakeHttpHeaders();
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(utf8.encode(responseBody)).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

void main() {
  setUpAll(() {
    TableRepository.timeoutDuration = const Duration(milliseconds: 50);
    HttpOverrides.global = _WidgetTestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  setUp(() {
    DatabaseHelper.setDatabaseForTesting(WidgetTestFakeDatabase());
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  test('Category model fromMap and toMap serialization test', () {
    final map = {
      'id': 1,
      'name': 'Cà phê',
      'title': 'Cà phê nguyên chất',
      'description': 'Đậm đà hương vị truyền thống',
      'icon': 'coffee.png',
      'sortOrder': 1,
      'isActive': true,
    };

    final category = Category.fromMap(map);

    expect(category.id, 1);
    expect(category.name, 'Cà phê');
    expect(category.title, 'Cà phê nguyên chất');
    expect(category.icon, 'coffee.png');

    final backToMap = category.toMap();
    expect(backToMap['id'], 1);
    expect(backToMap['name'], 'Cà phê');
  });

  testWidgets('RestaurantPosApp renders with NavigationBar and Tabs', (tester) async {
    await tester.pumpWidget(const RestaurantPosApp());
    await tester.pumpAndSettle();

    // Verify AppBar title of initial floor plan page
    expect(find.text('Sơ đồ bàn ăn'), findsOneWidget);

    // Verify NavigationBar destinations
    expect(find.text('Sơ đồ bàn'), findsOneWidget);
    expect(find.text('Thực đơn'), findsOneWidget);
    expect(find.text('Đồng bộ đơn'), findsOneWidget);

    // Switch to Thực đơn tab
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();

    // Verify Category page is loaded
    expect(find.text('Thực đơn & Danh mục'), findsOneWidget);

    // Switch to Đồng bộ đơn tab
    await tester.tap(find.text('Đồng bộ đơn'));
    await tester.pumpAndSettle();

    // Verify OrdersSyncPage is loaded
    expect(find.text('Đơn hàng ngoại tuyến'), findsOneWidget);
    expect(find.text('Trạng thái đồng bộ hàng đợi SQLite'), findsOneWidget);
  });
}

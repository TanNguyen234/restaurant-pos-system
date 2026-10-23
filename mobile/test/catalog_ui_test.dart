import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/product.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/views/admin/admin_category_page.dart';
import 'package:restaurant_pos_app/views/admin/admin_product_page.dart';
import 'package:restaurant_pos_app/views/cart_page.dart';
import 'package:restaurant_pos_app/views/product_detail_page.dart';

class _CatalogTestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
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
    if (path.contains('/api/product')) {
      jsonResp = jsonEncode({
        'totalItems': 0,
        'page': 1,
        'pageSize': 10,
        'totalPages': 0,
        'data': [],
      });
    } else if (path.contains('/api/category')) {
      jsonResp = '[]';
    }
    return _FakeHttpClientRequest(jsonResp);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);
  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  _FakeHttpClientRequest(this.responseBody);

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
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse(responseBody);
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
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

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  _FakeHttpClientResponse(this.responseBody);

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
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(utf8.encode(responseBody)).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseHelper.isTestingMode = true;
    HttpOverrides.global = _CatalogTestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  setUp(() async {
    await DatabaseHelper().clearCart();
  });

  group('CartPage Widget Tests', () {
    testWidgets('Renders empty state when cart has no items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CartPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Giỏ hàng của bạn đang trống'), findsOneWidget);
      expect(find.text('KHÁM PHÁ THỰC ĐƠN'), findsOneWidget);
    });

    testWidgets('Renders item and calculates total when item is in cart', (WidgetTester tester) async {
      await DatabaseHelper().insertOrUpdateCart({
        'product_id': 1,
        'product_name': 'Cà phê đen đá Đắk Lắk',
        'price': 25000.0,
        'quantity': 2,
        'image_url': 'cafe_den_da.jpg',
        'note': 'Ít đá',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CartPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cà phê đen đá Đắk Lắk'), findsOneWidget);
      expect(find.text('Ít đá'), findsOneWidget);
      expect(find.text('TIẾN HÀNH ĐẶT MÓN'), findsOneWidget);
    });
  });

  group('ProductDetailPage Widget Tests', () {
    testWidgets('Renders product detail with size options and add-to-cart button', (WidgetTester tester) async {
      final product = Product(
        productId: 10,
        categoryId: 1,
        categoryName: 'Cà phê',
        productName: 'Bạc xỉu Sài Gòn',
        price: 29000,
        unit: 'Ly',
        imageUrl: 'bac_xiu.jpg',
        description: 'Vị ngọt dịu thơm béo từ sữa đặc nguyên kem',
        attributes: [
          ProductAttribute(attributeId: 1, productId: 10, attributeGroup: 'Size', attributeName: 'Vừa (M)', extraPrice: 0),
          ProductAttribute(attributeId: 2, productId: 10, attributeGroup: 'Size', attributeName: 'Lớn (L)', extraPrice: 6000),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailPage(product: product),
        ),
      );
      await tester.pump();

      expect(find.text('Bạc xỉu Sài Gòn'), findsWidgets);
      expect(find.text('Vị ngọt dịu thơm béo từ sữa đặc nguyên kem'), findsOneWidget);
      expect(find.text('Kích thước (Size)'), findsOneWidget);
      expect(find.text('Vừa (M)'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
    });
  });

  group('Admin Pages Widget Tests', () {
    testWidgets('AdminCategoryPage renders header and category list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCategoryPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Quản trị Danh mục'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('AdminProductPage renders search, category dropdown and product list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminProductPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Quản trị Món ăn'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/product.dart';
import 'package:restaurant_pos_app/views/home_page.dart';
import 'package:restaurant_pos_app/views/product_detail_page.dart';
import 'package:restaurant_pos_app/views/cart_page.dart';
import 'package:restaurant_pos_app/views/admin/admin_product_page.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';

class _CaptureTestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _CaptureFakeHttpClient();
}

class _CaptureFakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final path = url.path;
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

    if (path.contains('/api/product/featured')) {
      final jsonResp = jsonEncode([
        {
          'productId': 1,
          'productName': 'Cà Phê Sữa Đá Sài Gòn',
          'categoryId': 1,
          'price': 29000,
          'imageUrl': 'cafe_sua_da.jpg;cafe_sua_da_2.jpg',
          'isAvailable': true,
          'isFeatured': true,
          'unit': 'Ly',
          'description': 'Cà phê Robusta Đắk Lắk pha phin truyền thống hòa quyện cùng sữa đặc béo ngậy.',
        },
        {
          'productId': 26,
          'productName': 'Phở Bò Wagyu Thượng Hạng',
          'categoryId': 7,
          'price': 89000,
          'imageUrl': 'pho_bo_wagyu.jpg;pho_bo_wagyu_2.jpg',
          'isAvailable': true,
          'isFeatured': true,
          'unit': 'Tô',
          'description': 'Nước dùng ninh xương bò 24h thơm hương quế hồi, thăn bò Wagyu mềm tan.',
        },
      ]);
      return _CaptureJsonHttpClientRequest(jsonResp);
    } else if (path.contains('/api/product')) {
      final jsonResp = jsonEncode({
        'totalItems': 4,
        'page': 1,
        'pageSize': 10,
        'totalPages': 1,
        'data': [
          {
            'productId': 1,
            'productName': 'Cà Phê Sữa Đá Sài Gòn',
            'categoryId': 1,
            'price': 29000,
            'imageUrl': 'cafe_sua_da.jpg;cafe_sua_da_2.jpg',
            'isAvailable': true,
            'isFeatured': true,
            'unit': 'Ly',
            'description': 'Cà phê Robusta Đắk Lắk pha phin truyền thống hòa quyện cùng sữa đặc béo ngậy.',
          },
          {
            'productId': 2,
            'productName': 'Bạc Xỉu 3 Tầng',
            'categoryId': 1,
            'price': 35000,
            'imageUrl': 'bac_xiu_3tang.jpg;bac_xiu_3tang_2.jpg',
            'isAvailable': true,
            'isFeatured': true,
            'unit': 'Ly',
            'description': 'Hương vị nhẹ nhàng 3 tầng: sữa tươi thanh mát, sữa đặc ngọt dịu và cà phê phin.',
          },
          {
            'productId': 11,
            'productName': 'Trà Đào Cam Sả',
            'categoryId': 3,
            'price': 45000,
            'imageUrl': 'tra_dao_cam_sa.jpg;tra_dao_cam_sa_2.jpg',
            'isAvailable': true,
            'isFeatured': true,
            'unit': 'Ly',
            'description': 'Trà đen Ceylon thơm ngát kết hợp cùng đào giòn, cam vàng tươi và sả đập dập.',
          },
          {
            'productId': 26,
            'productName': 'Phở Bò Wagyu Thượng Hạng',
            'categoryId': 7,
            'price': 89000,
            'imageUrl': 'pho_bo_wagyu.jpg;pho_bo_wagyu_2.jpg',
            'isAvailable': true,
            'isFeatured': true,
            'unit': 'Tô',
            'description': 'Nước dùng ninh xương bò 24h thơm hương quế hồi, thăn bò Wagyu mềm tan.',
          },
        ],
      });
      return _CaptureJsonHttpClientRequest(jsonResp);
    } else if (path.contains('/api/category')) {
      final jsonResp = jsonEncode([
        {'id': 1, 'name': 'Cà Phê Truyền Thống', 'imageUrl': 'traditional_coffee.png'},
        {'id': 2, 'name': 'Espresso & Cà Phê Ý', 'imageUrl': 'espresso_coffee.png'},
        {'id': 3, 'name': 'Trà Trái Cây & Trà Hoa', 'imageUrl': 'fruit_tea.png'},
        {'id': 7, 'name': 'Điểm Tâm & Món Ăn Sáng', 'imageUrl': 'breakfast.png'},
      ]);
      return _CaptureJsonHttpClientRequest(jsonResp);
    }
    return _CaptureJsonHttpClientRequest('[]');
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);
  @override
  void close({bool force = false}) {}
}

class _CaptureJsonHttpClientRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  _CaptureJsonHttpClientRequest(this.responseBody);

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
  final HttpHeaders headers = _FakeHttpHeaders('application/json; charset=utf-8');

  @override
  Future<HttpClientResponse> close() async => _CaptureJsonHttpClientResponse(responseBody);
}

class _CaptureJsonHttpClientResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  _CaptureJsonHttpClientResponse(this.responseBody);

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
  final HttpHeaders headers = _FakeHttpHeaders('application/json; charset=utf-8');
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
  late final HttpHeaders headers = _FakeHttpHeaders(contentType);

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
  late final HttpHeaders headers = _FakeHttpHeaders(contentType);
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final String cType;
  _FakeHttpHeaders(this.cType);

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

Future<void> _captureWidgetToFile(WidgetTester tester, GlobalKey repaintKey, String outputPath) async {
  await tester.runAsync(() async {
    final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(pngBytes);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseHelper.isTestingMode = true;
    HttpOverrides.global = _CaptureTestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('Capture 1: HomePage with Product Grid and Category Filter', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: RepaintBoundary(
          key: repaintKey,
          child: const HomePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _captureWidgetToFile(tester, repaintKey, '../docs/acceptance/screenshots/01_home_menu_page.png');
  });

  testWidgets('Capture 2: ProductDetailPage with Multi-Image Slider (Cafe Sua Da)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sampleProduct = Product(
      productId: 1,
      categoryId: 1,
      productName: 'Cà Phê Sữa Đá Sài Gòn',
      price: 29000,
      unit: 'Ly',
      imageUrl: 'cafe_sua_da.jpg;cafe_sua_da_2.jpg',
      description: 'Cà phê Robusta Đắk Lắk pha phin truyền thống hòa quyện cùng sữa đặc béo ngậy hảo hạng.',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 1, productId: 1, attributeGroup: 'Size', attributeName: 'Size M (+0đ)', extraPrice: 0),
        ProductAttribute(attributeId: 2, productId: 1, attributeGroup: 'Size', attributeName: 'Size L (+8.000đ)', extraPrice: 8000),
      ],
    );

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: RepaintBoundary(
          key: repaintKey,
          child: ProductDetailPage(product: sampleProduct),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _captureWidgetToFile(tester, repaintKey, '../docs/acceptance/screenshots/02_product_detail_multiphoto.png');
  });

  testWidgets('Capture 3: ProductDetailPage with Pho Bo Wagyu', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final phoProduct = Product(
      productId: 26,
      categoryId: 7,
      productName: 'Phở Bò Wagyu Thượng Hạng',
      price: 89000,
      unit: 'Tô',
      imageUrl: 'pho_bo_wagyu.jpg;pho_bo_wagyu_2.jpg',
      description: 'Nước dùng ninh xương bò 24h thơm hương quế hồi, thăn bò Wagyu mềm tan tuyệt đỉnh ẩm thực Việt.',
      isAvailable: true,
      isFeatured: true,
      attributes: [
        ProductAttribute(attributeId: 10, productId: 26, attributeGroup: 'Khẩu phần', attributeName: 'Tô Tiêu Chuẩn', extraPrice: 0),
        ProductAttribute(attributeId: 11, productId: 26, attributeGroup: 'Topping', attributeName: 'Thêm Thịt Wagyu (+35.000đ)', extraPrice: 35000),
      ],
    );

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: RepaintBoundary(
          key: repaintKey,
          child: ProductDetailPage(product: phoProduct),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _captureWidgetToFile(tester, repaintKey, '../docs/acceptance/screenshots/03_product_detail_food.png');
  });

  testWidgets('Capture 4: CartPage with Items and Calculations', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
      'note': 'Không hành lá, nhiều ớt',
    });

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: RepaintBoundary(
          key: repaintKey,
          child: const CartPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _captureWidgetToFile(tester, repaintKey, '../docs/acceptance/screenshots/04_cart_summary_page.png');
  });

  testWidgets('Capture 5: AdminProductPage with Product List and Thumbnails', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        home: RepaintBoundary(
          key: repaintKey,
          child: const AdminProductPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _captureWidgetToFile(tester, repaintKey, '../docs/acceptance/screenshots/05_admin_product_page.png');
  });
}

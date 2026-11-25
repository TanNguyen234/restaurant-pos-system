import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/main.dart';
import 'package:restaurant_pos_app/models/order.dart';
import 'package:restaurant_pos_app/models/user.dart';
import 'package:restaurant_pos_app/repositories/order_repository.dart';
import 'package:restaurant_pos_app/services/escpos_printer_service.dart';
import 'package:restaurant_pos_app/services/qr_table_session.dart';
import 'package:restaurant_pos_app/services/realtime_service.dart';
import 'package:restaurant_pos_app/services/session_manager.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/utils/snackbar_helper.dart';
import 'package:restaurant_pos_app/views/member/member_home_page.dart';
import 'package:restaurant_pos_app/views/order/order_checkout_page.dart';
import 'package:restaurant_pos_app/views/order/order_detail_page.dart';

UserAccount _userWithRole(String role) => UserAccount(
      accountId: 1,
      roleId: 1,
      username: 'u_$role',
      fullName: 'User $role',
      role: role,
      roleName: role,
    );

void main() {
  setUp(() async {
    PosRealtimeService.isTestingMode = true;
    DatabaseHelper.isTestingMode = true;
    await DatabaseHelper().clearCart();
    await SessionManager.instance.logout();
  });

  tearDown(() async {
    await DatabaseHelper().clearCart();
    await SessionManager.instance.logout();
  });

  group('RBAC getters & SessionManager guards', () {
    test('Role capability matrix for all system roles + guest', () {
      final admin = _userWithRole('ADMIN');
      expect(admin.isAdmin, isTrue);
      expect(admin.isManager, isTrue);
      expect(admin.isCashier, isTrue);
      expect(admin.isWaiter, isTrue);
      expect(admin.isKitchen, isTrue);
      expect(admin.isStaff, isTrue);
      expect(admin.isMember, isFalse);

      final manager = _userWithRole('MANAGER');
      expect(manager.isAdmin, isFalse);
      expect(manager.isManager, isTrue);
      expect(manager.isCashier, isFalse);
      expect(manager.isWaiter, isTrue);
      expect(manager.isKitchen, isTrue);
      expect(manager.isStaff, isTrue);

      final cashier = _userWithRole('CASHIER');
      expect(cashier.isAdmin, isFalse);
      expect(cashier.isManager, isFalse);
      expect(cashier.isCashier, isTrue);
      expect(cashier.isStaff, isTrue);

      final waiter = _userWithRole('WAITER');
      expect(waiter.isWaiter, isTrue);
      expect(waiter.isManager, isFalse);
      expect(waiter.isCashier, isFalse);
      expect(waiter.isStaff, isTrue);

      final headChef = _userWithRole('HEAD_CHEF');
      expect(headChef.isChef, isTrue);
      expect(headChef.isKitchen, isTrue);
      expect(headChef.isManager, isFalse);
      expect(headChef.isStaff, isTrue);

      final kitchen = _userWithRole('KITCHEN');
      expect(kitchen.isChef, isTrue);
      expect(kitchen.isKitchen, isTrue);
      expect(kitchen.isStaff, isTrue);

      final member = _userWithRole('MEMBER');
      expect(member.isMember, isTrue);
      expect(member.isStaff, isFalse);
      expect(member.isAdmin, isFalse);
      expect(member.isManager, isFalse);

      expect(SessionManager.instance.isLoggedIn, isFalse);
      expect(SessionManager.instance.isStaff, isFalse);
      expect(SessionManager.instance.isManager, isFalse);
    });
  });

  group('DatabaseHelper cart variant & row-id isolation', () {
    test('Same product_id with distinct notes stores two separate rows and deletes by row id', () async {
      final db = DatabaseHelper();

      final row1 = await db.insertOrUpdateCart({
        'product_id': 1,
        'product_name': 'Cà Phê Sữa Đá',
        'price': 29000.0,
        'quantity': 1,
        'note': 'Ít đường',
      });
      final row2 = await db.insertOrUpdateCart({
        'product_id': 1,
        'product_name': 'Cà Phê Sữa Đá',
        'price': 29000.0,
        'quantity': 2,
        'note': 'Nhiều sữa',
      });
      final row1Updated = await db.insertOrUpdateCart({
        'product_id': 1,
        'product_name': 'Cà Phê Sữa Đá',
        'price': 29000.0,
        'quantity': 1,
        'note': 'Ít đường',
      });

      expect(row1, isNot(equals(row2)));
      expect(row1Updated, equals(row1));

      final items = await db.getCartItems();
      expect(items.length, 2);
      expect(await db.getCartItemCount(), 4);

      await db.deleteCartItem(row1);
      final remaining = await db.getCartItems();
      expect(remaining.length, 1);
      expect(remaining.first['id'], row2);
      expect(remaining.first['note'], 'Nhiều sữa');
      expect(await db.getCartItemCount(), 2);
    });
  });

  group('OrderItemModel & OrderRepository idempotencyKey', () {
    test('OrderItemModel.isVoided reflects cookingStatus == 4 only', () {
      for (int status = 0; status <= 3; status++) {
        final item = OrderItemModel(
          orderDetailId: 10 + status,
          productId: 1,
          productName: 'Test Item',
          quantity: 1,
          unitPrice: 30000,
          subTotal: 30000,
          cookingStatus: status,
        );
        expect(item.isVoided, isFalse);
      }

      final voided = OrderItemModel(
        orderDetailId: 99,
        productId: 1,
        productName: 'Voided Item',
        quantity: 1,
        unitPrice: 30000,
        subTotal: 30000,
        cookingStatus: 4,
      );
      expect(voided.isVoided, isTrue);
      expect(voided.cookingStatusText, 'Đã hủy món');
    });

    test('OrderRepository offline fallback generates unique UUID idempotencyKeys', () async {
      final prevOverrides = HttpOverrides.current;
      final prevUrl = OrderRepository.baseUrl;
      final prevTimeout = OrderRepository.timeoutDuration;
      addTearDown(() {
        HttpOverrides.global = prevOverrides;
        OrderRepository.baseUrl = prevUrl;
        OrderRepository.timeoutDuration = prevTimeout;
      });

      HttpOverrides.global = _OfflineHttpOverrides();
      OrderRepository.baseUrl = 'http://offline.invalid/api/order';
      OrderRepository.timeoutDuration = const Duration(seconds: 2);
      final repo = OrderRepository();

      final payload = {
        'customerName': 'QA Offline Unique Check',
        'orderType': 1,
        'items': [
          {'productId': 1, 'quantity': 1}
        ],
      };

      final res1 = await repo.createOrder(payload);
      final res2 = await repo.createOrder(payload);

      expect(res1['success'], isTrue);
      expect(res1['isOffline'], isTrue);
      expect(res2['success'], isTrue);
      expect(res2['isOffline'], isTrue);

      final queued = (await DatabaseHelper().getUnsyncedOrders())
          .where((o) => o['customer_name'] == 'QA Offline Unique Check')
          .toList();
      expect(queued.length, greaterThanOrEqualTo(2));

      final key1 = queued[queued.length - 2]['idempotency_key']?.toString() ?? '';
      final key2 = queued[queued.length - 1]['idempotency_key']?.toString() ?? '';
      expect(key1.length, greaterThanOrEqualTo(32));
      expect(key2.length, greaterThanOrEqualTo(32));
      expect(key1, isNot(equals(key2)));
    });
  });

  group('Upgrades 1-6 regression tests', () {
    test('EscPosPrinterService builds 58mm/80mm binary ESC/POS buffer with Vietnamese folding & cut', () {
      final order = {
        'orderCode': 'ORD-20261125-001',
        'tableName': 'Bàn T1-02',
        'customerName': 'Bùi Vĩnh Khang',
        'totalAmount': 80000,
        'discountAmount': 8000,
        'finalAmount': 72000,
        'details': [
          {'quantity': 2, 'productName': 'Cà phê sữa đá', 'subTotal': 58000, 'cookingStatus': 1},
          {'quantity': 1, 'productName': 'Món hủy', 'subTotal': 22000, 'cookingStatus': 4},
        ],
      };

      final bytes80 = EscPosPrinterService.buildReceiptBytes(order, paperWidthMm: 80);
      final bytes58 = EscPosPrinterService.buildReceiptBytes(order, paperWidthMm: 58, isPreCheck: true);

      // Starts with ESC @ (0x1B, 0x40) and ends with GS V B 0 (0x1D, 0x56, 0x42, 0x00)
      expect(bytes80.sublist(0, 2), equals([0x1B, 0x40]));
      expect(bytes80.sublist(bytes80.length - 4), equals([0x1D, 0x56, 0x42, 0x00]));
      expect(bytes58.sublist(0, 2), equals([0x1B, 0x40]));

      final decoded80 = ascii.decode(bytes80, allowInvalid: true);
      expect(decoded80, contains('Ca phe sua da'));
      expect(decoded80, isNot(contains('Mon huy')));
      expect(ascii.decode(bytes58, allowInvalid: true), contains('PHIEU TAM TINH'));
    });

    test('QrTableSession parses ?tableId= from both query string and hash fragment', () {
      expect(QrTableSession.parseTableIdFromUri(Uri.parse('http://localhost:8088/?tableId=4')), 4);
      expect(QrTableSession.parseTableIdFromUri(Uri.parse('http://localhost:8088/#/?tableId=9')), 9);
      expect(QrTableSession.parseTableIdFromUri(Uri.parse('http://localhost:8088/')), isNull);
      expect(QrTableSession.parseTableIdFromUri(Uri.parse('http://localhost:8088/?tableId=-1')), isNull);
    });

    test('PosRealtimeService parses multi-frame SignalR Hub JSON payloads', () {
      const sep = '\u001e';
      const raw =
          '{"type":1,"target":"OrderEvent","arguments":[{"eventType":"OrderCreated","orderId":55}]}$sep'
          '{"type":6}$sep'
          '{"type":1,"target":"KdsUpdated","arguments":[{"orderDetailId":12}]}$sep';

      final events = PosRealtimeService.parseFrames(raw);
      expect(events.length, 2);
      expect(events[0].target, 'OrderEvent');
      expect((events[0].payload as Map)['eventType'], 'OrderCreated');
      expect(events[1].target, 'KdsUpdated');
    });
  });

  group('UX, VNPay Recovery, Checkout Vouchers, Deep-Link & User Orders tests', () {
    tearDown(() {
      HttpOverrides.global = null;
    });

    testWidgets('showAutoDismissSnackBar auto-dismisses even when accessibleNavigation is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showAutoDismissSnackBar(
                    ctx,
                    message: 'Đã thêm 1 x "Cà phê" vào giỏ',
                    duration: const Duration(seconds: 2),
                    actionLabel: 'GIỎ HÀNG',
                    onAction: () {},
                  ),
                  child: const Text('Trigger'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Đã thêm 1 x "Cà phê" vào giỏ'), findsOneWidget);
      expect(find.text('GIỎ HÀNG'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Đã thêm 1 x "Cà phê" vào giỏ'), findsNothing);
    });

    test('MainNavigationPage parses VNPay return params and OAuth ticket from URI', () {
      final vnp = MainNavigationPage.parseVnpayReturnFromUri(
        Uri.parse('http://localhost:8088/?vnpayStatus=cancelled&orderId=42&code=24'),
      );
      expect(vnp, isNotNull);
      expect(vnp!.status, 'cancelled');
      expect(vnp.orderId, 42);
      expect(vnp.code, '24');

      expect(
        MainNavigationPage.parseOAuthTicketFromUri(Uri.parse('http://localhost:8088/?oauthTicket=abc123')),
        'abc123',
      );
      expect(
        MainNavigationPage.parseOAuthTicketFromUri(Uri.parse('http://localhost:8088/#/?oauthTicket=xyz789')),
        'xyz789',
      );
    });

    testWidgets('OrderCheckoutPage renders active vouchers with eligibility & applies on 1 tap', (tester) async {
      HttpOverrides.global = _MockHttpOverrides((method, uri, _) {
        if (uri.path.endsWith('/api/table')) {
          return (200, jsonEncode([{'tableId': 1, 'areaId': 1, 'tableName': 'Bàn T1-01', 'capacity': 4, 'status': 0}]));
        }
        if (uri.path.endsWith('/api/discount/active')) {
          return (200, jsonEncode({
            'success': true,
            'data': [
              {'discountId': 1, 'code': 'BANMOI10', 'title': 'Giảm 10% khách mới', 'discountPercent': 10, 'discountAmount': 0, 'minOrderAmount': 50000, 'maxDiscountAmount': 50000},
              {'discountId': 2, 'code': 'GIAM20K', 'title': 'Giảm 20k đơn 100k', 'discountPercent': 0, 'discountAmount': 20000, 'minOrderAmount': 100000, 'maxDiscountAmount': 20000},
            ],
          }));
        }
        if (uri.path.endsWith('/api/discount/validate')) {
          return (200, jsonEncode({'success': true, 'discountAmount': 6000}));
        }
        return (200, '{}');
      });

      await DatabaseHelper().insertOrUpdateCart({
        'product_id': 1,
        'product_name': 'Cà phê đen đá',
        'price': 60000.0,
        'quantity': 1,
      });

      await tester.pumpWidget(const MaterialApp(home: OrderCheckoutPage(preSelectedTableId: 1)));
      await tester.pumpAndSettle();

      expect(find.text('Mã giảm giá có sẵn cho đơn này'), findsOneWidget);
      expect(find.text('BANMOI10'), findsOneWidget);
      expect(find.text('GIAM20K'), findsOneWidget);
      expect(find.text('Dùng ngay'), findsOneWidget);
      expect(find.text('Chưa đủ'), findsOneWidget);

      await tester.ensureVisible(find.text('BANMOI10'));
      await tester.tap(find.text('BANMOI10'));
      await tester.pumpAndSettle();

      expect(find.text('Giảm giá (BANMOI10):'), findsOneWidget);
      expect(find.text('Đang dùng'), findsOneWidget);
    });

    testWidgets('OrderDetailPage shows VNPay cancelled recovery banner and restores order back to cart', (tester) async {
      bool cancelledApiCalled = false;
      HttpOverrides.global = _MockHttpOverrides((method, uri, _) {
        if (uri.path.endsWith('/api/order/77')) {
          return (200, jsonEncode({
            'orderId': 77,
            'orderCode': 'ORD-VNPAY-77',
            'tableId': 2,
            'tableName': 'Bàn T1-02',
            'customerName': 'Khách VNPay',
            'totalAmount': 50000,
            'discountAmount': 0,
            'finalAmount': 50000,
            'paidAmount': 0,
            'status': 0,
            'paymentStatus': 0,
            'details': [
              {'orderDetailId': 1, 'productId': 5, 'productName': 'Trà đào cam sả', 'quantity': 1, 'unitPrice': 50000, 'subTotal': 50000, 'cookingStatus': 0},
            ],
          }));
        }
        if (uri.path.contains('/api/payment/vietqr/77')) {
          return (404, '{}');
        }
        if (uri.path.endsWith('/api/order/77/cancel-unpaid') && method == 'POST') {
          cancelledApiCalled = true;
          return (200, jsonEncode({'success': true, 'message': 'Đã hủy đơn chưa thanh toán'}));
        }
        return (200, '{}');
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: OrderDetailPage(orderId: 77, vnpayStatus: 'cancelled', vnpayCode: '24'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bạn đã hủy giao dịch VNPay (Mã 24)'), findsOneWidget);
      expect(find.text('Tiền mặt tại quầy'), findsOneWidget);

      await tester.ensureVisible(find.text('Hủy thanh toán & Khôi phục về giỏ hàng'));
      await tester.tap(find.text('Hủy thanh toán & Khôi phục về giỏ hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Khôi phục về giỏ'));
      await tester.pumpAndSettle();

      expect(cancelledApiCalled, isTrue);
      final restored = await DatabaseHelper().getCartItems();
      expect(restored.length, 1);
      expect(restored.first['product_name'], 'Trà đào cam sả');
    });

    testWidgets('MemberHomePage auto-loads logged-in user orders on mount without manual search', (tester) async {
      await SessionManager.instance.setSession(_userWithRole('MEMBER'));
      HttpOverrides.global = _MockHttpOverrides((method, uri, _) {
        if (uri.path.endsWith('/api/loyalty/me')) {
          return (200, jsonEncode({
            'success': true,
            'data': {
              'loyaltyPoints': 1250,
              'tier': 'THÀNH VIÊN',
              'availableVouchers': [],
              'redeemedVoucherCodes': [],
              'history': [],
            },
          }));
        }
        if (uri.path.contains('/api/order/lookup')) {
          return (200, jsonEncode({
            'success': true,
            'data': [
              {
                'orderId': 6,
                'orderCode': 'ORD-MEMBER-006',
                'tableName': 'Bàn T1-01',
                'customerName': 'Bùi Vĩnh Khang',
                'totalAmount': 80000,
                'discountAmount': 0,
                'finalAmount': 80000,
                'status': 1,
                'paymentStatus': 0,
                'details': [],
              }
            ],
          }));
        }
        return (200, '{}');
      });

      await tester.pumpWidget(const MaterialApp(home: MemberHomePage()));
      await tester.pumpAndSettle();

      expect(find.text('Đơn hàng của tôi (1)'), findsOneWidget);
      expect(find.text('ORD-MEMBER-006'), findsOneWidget);
    });
  });
}

class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _OfflineHttpClient();
}

class _OfflineHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('openUrl') ||
        name.contains('getUrl') ||
        name.contains('postUrl') ||
        name.contains('putUrl') ||
        name.contains('deleteUrl')) {
      return Future<HttpClientRequest>.error(
        const SocketException('Simulated offline mode'),
      );
    }
    return null;
  }
}

typedef _MockResponder = (int statusCode, String body) Function(String method, Uri uri, String body);

class _MockHttpOverrides extends HttpOverrides {
  final _MockResponder responder;
  _MockHttpOverrides(this.responder);

  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient(responder);
}

class _MockHttpClient extends Fake implements HttpClient {
  final _MockResponder responder;
  _MockHttpClient(this.responder);

  @override
  set autoUncompress(bool _) {}
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _MockHttpClientRequest(method, url, responder);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  void close({bool force = false}) {}
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final _MockResponder responder;
  final _buffer = <int>[];

  _MockHttpClientRequest(this.method, this.uri, this.responder);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = false;
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => _buffer.addAll(data);
  @override
  void write(Object? obj) => _buffer.addAll(utf8.encode(obj?.toString() ?? ''));
  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _buffer.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final (code, body) = responder(method, uri, utf8.decode(_buffer, allowMalformed: true));
    return _MockHttpClientResponse(code, utf8.encode(body));
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  void forEach(void Function(String name, List<String> values) action) => _headers.forEach(action);
  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];
  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> _bytes;
  _MockHttpClientResponse(this.statusCode, this._bytes);

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Error';
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  int get contentLength => _bytes.length;
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}



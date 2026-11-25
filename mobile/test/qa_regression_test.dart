import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/order.dart';
import 'package:restaurant_pos_app/models/user.dart';
import 'package:restaurant_pos_app/repositories/order_repository.dart';
import 'package:restaurant_pos_app/services/session_manager.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';

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


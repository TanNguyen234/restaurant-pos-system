import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../utils/database_helper.dart';
import '../config/api_config.dart';

class SyncResult {
  final int total;
  final int synced;
  final int failed;
  final String message;

  SyncResult({
    required this.total,
    required this.synced,
    required this.failed,
    required this.message,
  });

  @override
  String toString() =>
      'SyncResult(total: $total, synced: $synced, failed: $failed, message: $message)';
}

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static String orderApiUrl = '${ApiConfig.baseUrl}/api/order';
  static String healthCheckUrl = '${ApiConfig.baseUrl}/api/table/areas';
  static const Duration timeoutDuration = Duration(seconds: 5);
  static const Uuid _uuid = Uuid();

  Timer? _periodicTimer;
  bool _isSyncing = false;
  final ValueNotifier<int> unsyncedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    await refreshUnsyncedCount();
  }

  Future<int> refreshUnsyncedCount() async {
    try {
      final count = await DatabaseHelper().getUnsyncedOrderCount();
      unsyncedCountNotifier.value = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> checkNetworkReachability() async {
    try {
      final response = await ApiConfig.get(Uri.parse(healthCheckUrl))
          .timeout(timeoutDuration);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    stopPeriodicSync();
    _periodicTimer = Timer.periodic(interval, (_) async {
      await syncNow();
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  static List<Map<String, dynamic>> _normalizeItems(dynamic rawItems) {
    if (rawItems is! List) return [];
    return rawItems.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return {
        'productId': item['productId'] ?? item['product_id'],
        'quantity': item['quantity'] ?? item['qty'] ?? 1,
        'itemNote': item['itemNote'] ?? item['note'],
        if (item['modifiers'] != null) 'modifiers': item['modifiers'],
      };
    }).toList();
  }

  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      return SyncResult(
        total: 0,
        synced: 0,
        failed: 0,
        message: 'Đang trong quá trình đồng bộ...',
      );
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    int syncedCount = 0;
    int failedCount = 0;
    int totalCount = 0;

    try {
      final unsyncedOrders = await DatabaseHelper().getUnsyncedOrders();
      totalCount = unsyncedOrders.length;

      if (totalCount == 0) {
        await refreshUnsyncedCount();
        return SyncResult(
          total: 0,
          synced: 0,
          failed: 0,
          message: 'Không có đơn hàng nào cần đồng bộ.',
        );
      }

      final isOnline = await checkNetworkReachability();
      if (!isOnline) {
        return SyncResult(
          total: totalCount,
          synced: 0,
          failed: totalCount,
          message: 'Không thể kết nối đến máy chủ Backend.',
        );
      }

      for (final order in unsyncedOrders) {
        final orderId = order['id'] as int;
        try {
          dynamic parsedItems;
          try {
            if (order['items_json'] != null) {
              parsedItems = jsonDecode(order['items_json'] as String);
            }
          } catch (_) {
            parsedItems = [];
          }

          final normalizedItems = _normalizeItems(parsedItems);
          final payload = <String, dynamic>{
            if (order['idempotency_key'] != null &&
                order['idempotency_key'].toString().isNotEmpty)
              'idempotencyKey': order['idempotency_key'],
            'offlineOrderId': orderId,
            'tableId': order['table_id'],
            'customerName': order['customer_name'],
            if (order['phone_number'] != null) 'phoneNumber': order['phone_number'],
            'orderType': order['order_type'] ?? (order['table_id'] != null ? 1 : 2),
            if (order['note'] != null) 'note': order['note'],
            if (order['discount_code'] != null) 'discountCode': order['discount_code'],
            'totalAmount': order['total_amount'],
            'items': normalizedItems,
            'createdAt': order['created_at'],
          };

          final response = await ApiConfig.post(
            Uri.parse(orderApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(timeoutDuration);

          if (response.statusCode >= 200 && response.statusCode < 300) {
            await DatabaseHelper().markOrderSynced(orderId);
            syncedCount++;
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            await DatabaseHelper().markOrderSyncError(
              orderId,
              'Vui lòng đăng nhập tài khoản nhân viên/hội viên để đồng bộ đơn hàng (HTTP ${response.statusCode})',
            );
            failedCount++;
            break;
          } else {
            String errMsg = 'HTTP ${response.statusCode}';
            try {
              final d = jsonDecode(utf8.decode(response.bodyBytes));
              if (d is Map && (d['message'] != null || d['error'] != null)) {
                errMsg = (d['message'] ?? d['error']).toString();
              }
            } catch (_) {}
            await DatabaseHelper().markOrderSyncError(orderId, errMsg);
            failedCount++;
          }
        } catch (e) {
          await DatabaseHelper().markOrderSyncError(orderId, 'Lỗi mạng: $e');
          failedCount++;
        }
      }

      await refreshUnsyncedCount();

      return SyncResult(
        total: totalCount,
        synced: syncedCount,
        failed: failedCount,
        message: failedCount == 0
            ? 'Đã đồng bộ thành công $syncedCount/$totalCount đơn hàng.'
            : 'Đã đồng bộ $syncedCount/$totalCount đơn ($failedCount đơn lỗi).',
      );
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  Future<int> queueOfflineOrder({
    required int? tableId,
    required String? customerName,
    String? phoneNumber,
    int? orderType,
    String? note,
    String? discountCode,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final order = {
      'idempotency_key': _uuid.v4(),
      'table_id': tableId,
      'customer_name': customerName ?? 'Khách lẻ',
      'phone_number': phoneNumber,
      'order_type': orderType ?? (tableId != null ? 1 : 2),
      'note': note,
      'discount_code': discountCode,
      'total_amount': totalAmount,
      'items_json': jsonEncode(_normalizeItems(items)),
    };

    final id = await DatabaseHelper().saveOfflineOrder(order);
    await refreshUnsyncedCount();

    unawaited(syncNow());
    return id;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  static String orderApiUrl = ApiConfig.baseUrl + '/api/order';
  static String healthCheckUrl = ApiConfig.baseUrl + '/api/table/areas';
  static const Duration timeoutDuration = Duration(seconds: 4);

  Timer? _periodicTimer;
  bool _isSyncing = false;
  final ValueNotifier<int> unsyncedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  bool get isSyncing => _isSyncing;

  /// Khởi tạo và cập nhật số lượng đơn hàng chưa đồng bộ ban đầu
  Future<void> initialize() async {
    await refreshUnsyncedCount();
  }

  /// Cập nhật số lượng đơn hàng chưa đồng bộ
  Future<int> refreshUnsyncedCount() async {
    try {
      final count = await DatabaseHelper().getUnsyncedOrderCount();
      unsyncedCountNotifier.value = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Kiểm tra xem Backend Server có thể truy cập được hay không
  Future<bool> checkNetworkReachability() async {
    try {
      final response = await http
          .get(Uri.parse(healthCheckUrl))
          .timeout(timeoutDuration);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Bắt đầu chạy tiến trình đồng bộ định kỳ theo khoảng thời gian (mặc định 30 giây)
  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    stopPeriodicSync();
    _periodicTimer = Timer.periodic(interval, (_) async {
      await syncNow();
    });
  }

  /// Dừng tiến trình đồng bộ định kỳ
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Thực hiện đồng bộ các đơn hàng chưa đồng bộ lên Backend API
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

          final payload = {
            'offlineOrderId': orderId,
            'tableId': order['table_id'],
            'customerName': order['customer_name'],
            'totalAmount': order['total_amount'],
            'items': parsedItems,
            'createdAt': order['created_at'],
          };

          final response = await http
              .post(
                Uri.parse(orderApiUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(timeoutDuration);

          if (response.statusCode >= 200 && response.statusCode < 300) {
            await DatabaseHelper().markOrderSynced(orderId);
            syncedCount++;
          } else {
            failedCount++;
          }
        } catch (_) {
          failedCount++;
        }
      }

      await refreshUnsyncedCount();

      return SyncResult(
        total: totalCount,
        synced: syncedCount,
        failed: failedCount,
        message: 'Đã đồng bộ thành công $syncedCount/$totalCount đơn hàng.',
      );
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Tiện ích lưu đơn hàng ngoại tuyến và kích hoạt đồng bộ ngầm
  Future<int> queueOfflineOrder({
    required int? tableId,
    required String? customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final order = {
      'table_id': tableId,
      'customer_name': customerName ?? 'Khách lẻ',
      'total_amount': totalAmount,
      'items_json': jsonEncode(items),
    };

    final id = await DatabaseHelper().saveOfflineOrder(order);
    await refreshUnsyncedCount();

    unawaited(syncNow());

    return id;
  }
}

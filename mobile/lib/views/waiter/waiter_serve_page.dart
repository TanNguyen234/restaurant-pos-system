import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';
import '../../services/realtime_service.dart';

/// Màn hình của phục vụ: danh sách món bếp / pha chế đã làm xong đang chờ bưng ra bàn.
/// Phục vụ xác nhận "Đã giao" từng món hoặc cả bàn (cookingStatus 2 -> 3). Bếp và pha chế không có bước này.
class WaiterServePage extends StatefulWidget {
  const WaiterServePage({super.key});

  @override
  State<WaiterServePage> createState() => _WaiterServePageState();
}

class _WaiterServePageState extends State<WaiterServePage> {
  final _orderRepo = OrderRepository();
  List<KdsItemModel> _items = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<PosRealtimeEvent>? _rtSub;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    PosRealtimeService.instance.ensureStarted();
    _rtSub = PosRealtimeService.instance.events.listen((ev) {
      if (mounted && (ev.target == 'KdsUpdated' || ev.target == 'OrderEvent' || ev.target == 'TableUpdated')) {
        _load(showSpinner: false);
      }
    });
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {}); // làm mới số phút chờ
    });
    _load();
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final items = await _orderRepo.getReadyToServeItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được danh sách món chờ bưng: $e';
        _isLoading = false;
      });
    }
  }

  void _toast(String message, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626)),
    );
  }

  Future<void> _serveItem(KdsItemModel item) async {
    final res = await _orderRepo.serveItem(item.orderDetailId);
    if (!mounted) return;
    _toast(res['message']?.toString() ?? '', res['success'] == true);
    await _load(showSpinner: false);
  }

  Future<void> _serveTable(int orderId) async {
    final res = await _orderRepo.serveReadyItems(orderId);
    if (!mounted) return;
    _toast(res['message']?.toString() ?? '', res['success'] == true);
    await _load(showSpinner: false);
  }

  String _waitText(KdsItemModel item) {
    final since = item.finishedCookingAt ?? item.createdAt;
    final mins = DateTime.now().difference(since).inMinutes;
    return mins < 1 ? 'vừa xong' : 'chờ $mins phút';
  }

  Widget _buildGroup(int orderId, List<KdsItemModel> items) {
    final tableName = items.first.tableName.isEmpty ? items.first.orderCode : items.first.tableName;
    final qty = items.fold<int>(0, (a, i) => a + i.quantity);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$tableName • $qty phần',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                if (items.length > 1)
                  TextButton.icon(
                    onPressed: () => _serveTable(orderId),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Giao cả bàn'),
                  ),
              ],
            ),
            const Divider(height: 12),
            ...items.map(_buildItemRow),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(KdsItemModel item) {
    final mods = item.modifiers.map((m) => (m['modifierName'] ?? '').toString()).where((s) => s.isNotEmpty).join(', ');
    final note = [mods, (item.itemNote ?? '').trim()].where((s) => s.isNotEmpty).join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.quantity}x ${item.productName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  note.isEmpty ? _waitText(item) : '$note • ${_waitText(item)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => _serveItem(item),
            icon: const Icon(Icons.room_service_rounded, size: 16),
            label: const Text('Đã giao'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626))),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    // Gom theo đơn (bàn / mang về / giao hàng)
    final groups = <int, List<KdsItemModel>>{};
    for (final i in _items) {
      groups.putIfAbsent(i.orderId, () => []).add(i);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: groups.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Chưa có món nào chờ bưng', style: TextStyle(color: Color(0xFF64748B), fontSize: 15))),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: groups.entries.map((e) => _buildGroup(e.key, e.value)).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Món chờ bưng'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới', onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }
}

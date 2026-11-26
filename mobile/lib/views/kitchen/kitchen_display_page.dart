import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/product_repository.dart';
import '../../services/realtime_service.dart';
import '../../utils/category_helper.dart';

class KitchenDisplayPage extends StatefulWidget {
  const KitchenDisplayPage({super.key});

  @override
  State<KitchenDisplayPage> createState() => _KitchenDisplayPageState();
}

class _KitchenDisplayPageState extends State<KitchenDisplayPage> {
  final _orderRepo = OrderRepository();
  List<KdsItemModel> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  StreamSubscription<PosRealtimeEvent>? _rtSub;

  // 0: Chờ nấu, 1: Đang làm, 2: Đã xong, -1: Tất cả
  int _selectedFilterStatus = 0;

  // Trạm: 0: Tất cả, 1: Bếp nấu (Food), 2: Quầy Bar (Drink)
  int _selectedStation = 0;

  // false: Ticket View (Theo đơn), true: Batch Prep (Gom món tổng lực)
  bool _isBatchPrepMode = false;

  Set<int> _knownItemIds = {};
  bool _hasInitializedIds = false;
  bool _hasNewOrderAlert = false;

  @override
  void initState() {
    super.initState();
    _loadKdsItems();
    PosRealtimeService.instance.ensureStarted();
    _rtSub = PosRealtimeService.instance.events.listen((ev) {
      if (mounted && (ev.target == 'KdsUpdated' || ev.target == 'OrderEvent')) {
        _loadKdsItems(showSpinner: false);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadKdsItems(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isDrinkItem(KdsItemModel item) {
    if (item.categoryId > 0) {
      return isDrinkCategory(item.categoryId);
    }
    final lower = item.productName.toLowerCase();
    return lower.contains('cà phê') ||
        lower.contains('cafe') ||
        lower.contains('trà') ||
        lower.contains('đá xay') ||
        lower.contains('sinh tố') ||
        lower.contains('nước') ||
        lower.contains('soda') ||
        lower.contains('matcha') ||
        lower.contains('latte') ||
        lower.contains('espresso') ||
        lower.contains('uống');
  }

  Future<void> _loadKdsItems({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await _orderRepo.getKdsActiveItems();
      if (!mounted) return;

      final incomingIds = items.map((e) => e.orderDetailId).toSet();
      final bool hasNew = _hasInitializedIds && incomingIds.difference(_knownItemIds).isNotEmpty;
      _knownItemIds = incomingIds;
      _hasInitializedIds = true;

      setState(() {
        _items = items;
        _isLoading = false;
        _errorMessage = null;
        if (hasNew) _hasNewOrderAlert = true;
      });

      if (hasNew) {
        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.alert);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _hasNewOrderAlert = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể kết nối máy chủ Bếp KDS: $e';
      });
    }
  }

  Future<void> _updateCookingStatus(int orderDetailId, int newStatus) async {
    final success = await _orderRepo.updateCookingStatus(orderDetailId, newStatus);
    if (!mounted) return;
    if (success) {
      await _loadKdsItems(showSpinner: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật trạng thái món'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _voidKdsItem(KdsItemModel item) async {
    final reasonCtrl = TextEditingController(text: 'Bếp báo hết nguyên liệu');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo hủy món từ Bếp', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.productName} (x${item.quantity}) • ${item.tableName}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy món *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final res = await _orderRepo.voidKdsItem(
      orderDetailId: item.orderDetailId,
      reason: reasonCtrl.text.trim().isEmpty ? 'Bếp báo hết nguyên liệu' : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? 'Đã cập nhật'),
        backgroundColor: res['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
      ),
    );
    if (res['success'] == true) {
      await _loadKdsItems(showSpinner: false);
    }
  }

  Future<void> _batchUpdateCookingStatus(List<KdsItemModel> groupItems, int newStatus) async {
    int okCount = 0;
    for (final item in groupItems) {
      if (await _orderRepo.updateCookingStatus(item.orderDetailId, newStatus)) {
        okCount++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật $okCount/${groupItems.length} món ăn!'),
        backgroundColor: okCount == groupItems.length ? const Color(0xFF059669) : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadKdsItems(showSpinner: false);
  }

  String _formatElapsed(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.isNegative || diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}p';
    return '${diff.inMinutes} phút';
  }

  Color _getTimerColor(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes >= 15) return const Color(0xFFEF4444);
    if (diff.inMinutes >= 8) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final stationFiltered = _items.where((i) {
      if (_selectedStation == 1) return !_isDrinkItem(i);
      if (_selectedStation == 2) return _isDrinkItem(i);
      return true;
    }).toList();

    final filtered = _selectedFilterStatus == -1
        ? stationFiltered
        : stationFiltered.where((i) => i.cookingStatus == _selectedFilterStatus).toList();

    final pendingCount = stationFiltered.where((i) => i.cookingStatus == 0).length;
    final cookingCount = stationFiltered.where((i) => i.cookingStatus == 1).length;
    final readyCount = stationFiltered.where((i) => i.cookingStatus == 2).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.kitchen_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedStation == 1
                    ? 'Bếp Nấu (Food KDS)'
                    : (_selectedStation == 2 ? 'Quầy Bar (Drink KDS)' : 'Bếp & Pha chế (KDS)'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isBatchPrepMode ? Icons.layers_rounded : Icons.layers_outlined,
              color: _isBatchPrepMode ? const Color(0xFFF59E0B) : Colors.white70,
            ),
            tooltip: _isBatchPrepMode ? 'Xem theo từng đơn' : 'Gom món (Batch Prep)',
            onPressed: () => setState(() => _isBatchPrepMode = !_isBatchPrepMode),
          ),
          IconButton(
            icon: const Icon(Icons.remove_shopping_cart_outlined),
            tooltip: '1-Chạm Báo hết món',
            onPressed: _showSoldOutModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới ngay',
            onPressed: () => _loadKdsItems(showSpinner: true),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasNewOrderAlert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFDC2626),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notification_important_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ĐƠN MỚI TIẾP NHẬN! Vui lòng ưu tiên chế biến',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildStationChip(0, 'Tất cả', Icons.all_inclusive_rounded),
                const SizedBox(width: 8),
                _buildStationChip(1, 'Bếp nấu', Icons.restaurant_rounded),
                const SizedBox(width: 8),
                _buildStationChip(2, 'Quầy Bar', Icons.local_cafe_rounded),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildKdsTab(label: 'Chờ nấu', count: pendingCount, status: 0, activeColor: const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildKdsTab(label: 'Đang làm', count: cookingCount, status: 1, activeColor: const Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                _buildKdsTab(label: 'Đã xong', count: readyCount, status: 2, activeColor: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildKdsTab(label: 'Tất cả', count: stationFiltered.length, status: -1, activeColor: Colors.white),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : (_errorMessage != null && _items.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 54, color: Color(0xFFF59E0B)),
                              const SizedBox(height: 14),
                              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: const Color(0xFF0F172A),
                                ),
                                onPressed: () => _loadKdsItems(showSpinner: true),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.soup_kitchen_outlined, size: 64, color: Color(0xFF475569)),
                                const SizedBox(height: 16),
                                const Text('Hiện tại không có món nào trong hàng đợi', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
                                const SizedBox(height: 8),
                                Text(
                                  'Cập nhật lúc: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : _isBatchPrepMode
                            ? _buildBatchPrepView(filtered)
                            : _buildTicketGridView(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildStationChip(int station, String label, IconData icon) {
    final isSelected = _selectedStation == station;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedStation = station),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF475569)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketGridView(List<KdsItemModel> list) {
    return RefreshIndicator(
      onRefresh: () => _loadKdsItems(showSpinner: false),
      child: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 460,
          mainAxisExtent: 250,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          final timerColor = _getTimerColor(item.createdAt);

          return Card(
            elevation: 2,
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: item.cookingStatus == 1
                    ? const Color(0xFF38BDF8)
                    : (item.cookingStatus == 2 ? const Color(0xFF10B981) : const Color(0xFF334155)),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF475569)),
                          ),
                          child: Text(
                            '${item.tableName} • ${item.orderCode}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: timerColor),
                          const SizedBox(width: 4),
                          Text(_formatElapsed(item.createdAt), style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.modifiers.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: item.modifiers
                                    .map((m) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF38BDF8)),
                                          ),
                                          child: Text(
                                            m['modifierName']?.toString() ?? '',
                                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w600),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                            if (item.itemNote != null && item.itemNote!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ghi chú: ${item.itemNote}',
                                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (item.cookingStatus < 2)
                        IconButton(
                          tooltip: 'Báo hủy món',
                          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                          onPressed: () => _voidKdsItem(item),
                        ),
                      if (item.cookingStatus == 0)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _updateCookingStatus(item.orderDetailId, 1),
                            icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                            label: const Text('Bắt đầu làm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        )
                      else if (item.cookingStatus == 1)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _updateCookingStatus(item.orderDetailId, 2),
                            icon: const Icon(Icons.check_circle_rounded, size: 16),
                            label: const Text('Đã nấu xong', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        )
                      else
                        // Bước "Đã giao" do phục vụ xác nhận, bếp/pha chế chỉ theo dõi
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_bottom_rounded, size: 16, color: Color(0xFF10B981)),
                                SizedBox(width: 6),
                                Text('Chờ phục vụ bưng món', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBatchPrepView(List<KdsItemModel> list) {
    final Map<String, List<KdsItemModel>> groups = {};
    for (final item in list) {
      groups.putIfAbsent(item.productName, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groups.entries.map((entry) {
        final productName = entry.key;
        final items = entry.value;
        final totalQty = items.fold(0, (sum, i) => sum + i.quantity);
        final pendingItems = items.where((i) => i.cookingStatus == 0).toList();
        final cookingItems = items.where((i) => i.cookingStatus == 1).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'Tổng: $totalQty phần',
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 6),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF475569)),
                            ),
                            child: Text(item.tableName, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('x${item.quantity}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.itemNote != null && item.itemNote!.isNotEmpty ? '(${item.itemNote})' : '',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            item.cookingStatusText,
                            style: TextStyle(
                              color: item.cookingStatus == 0
                                  ? const Color(0xFFF59E0B)
                                  : (item.cookingStatus == 1 ? const Color(0xFF38BDF8) : const Color(0xFF10B981)),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (pendingItems.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                          label: Text('Làm tất cả (${pendingItems.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _batchUpdateCookingStatus(pendingItems, 1),
                        ),
                      ),
                    if (pendingItems.isNotEmpty && cookingItems.isNotEmpty) const SizedBox(width: 8),
                    if (cookingItems.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: Text('Xong tất cả (${cookingItems.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _batchUpdateCookingStatus(cookingItems, 2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKdsTab({
    required String label,
    required int count,
    required int status,
    required Color activeColor,
  }) {
    final isSelected = _selectedFilterStatus == status;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilterStatus = status),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? activeColor : const Color(0xFF334155)),
          ),
          child: Column(
            children: [
              Text('$count', style: TextStyle(color: isSelected ? activeColor : const Color(0xFF94A3B8), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: isSelected ? activeColor : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSoldOutModal() async {
    PagedProductResult? initialResult;
    String? loadErr;
    try {
      initialResult = await ProductRepository.getProducts(page: 1, pageSize: 100);
    } catch (e) {
      loadErr = '$e';
    }
    if (!mounted) return;

    final List<Product> products = List<Product>.from(initialResult?.data ?? []);
    final pageMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFDC2626), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bếp Báo Hết Món (1-Chạm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Tắt công tắc để tạm ngưng bán món trên toàn hệ thống', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: loadErr != null
                    ? Center(child: Text('Không tải được danh sách món: $loadErr'))
                    : ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (itemCtx, index) {
                          final p = products[index];
                          return SwitchListTile(
                            title: Text(
                              p.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: !p.isAvailable ? TextDecoration.lineThrough : null,
                                color: !p.isAvailable ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              p.isAvailable ? 'Đang phục vụ bình thường' : 'TẠM HẾT HÀNG (Khách không thể gọi)',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.isAvailable ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                fontWeight: !p.isAvailable ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            value: p.isAvailable,
                            activeThumbColor: const Color(0xFF10B981),
                            inactiveThumbColor: const Color(0xFFDC2626),
                            onChanged: (val) async {
                              final res = await ProductRepository.toggleAvailability(p.productId);
                              if (res['success'] == true) {
                                setModalState(() {
                                  products[index] = Product(
                                    productId: p.productId,
                                    categoryId: p.categoryId,
                                    categoryName: p.categoryName,
                                    productName: p.productName,
                                    price: p.price,
                                    unit: p.unit,
                                    description: p.description,
                                    imageUrl: p.imageUrl,
                                    images: p.images,
                                    isAvailable: res['isAvailable'] ?? val,
                                    isFeatured: p.isFeatured,
                                    attributes: p.attributes,
                                  );
                                });
                              }
                              if (mounted) {
                                pageMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Đã cập nhật trạng thái món'),
                                    backgroundColor: res['success'] == true
                                        ? (val ? const Color(0xFF10B981) : const Color(0xFFDC2626))
                                        : const Color(0xFFDC2626),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

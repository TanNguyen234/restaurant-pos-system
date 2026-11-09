import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';

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

  // 0: Chờ nấu, 1: Đang nấu, 2: Đã xong, -1: Tất cả
  int _selectedFilterStatus = 0;

  // Trạm: 0: Tất cả, 1: Bếp nấu (Food), 2: Quầy Bar (Drink)
  int _selectedStation = 0;

  // Chế độ: false: Ticket View (Theo đơn), true: Batch Prep (Gom món tổng lực)
  bool _isBatchPrepMode = false;

  int _lastItemCount = 0;
  bool _hasNewOrderAlert = false;

  @override
  void initState() {
    super.initState();
    _loadKdsItems();
    // Tự động làm mới KDS mỗi 30 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadKdsItems(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _isDrink(String name) {
    final lower = name.toLowerCase();
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
        lower.contains('bia') ||
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

      final bool hasNew = _items.isNotEmpty && items.length > _lastItemCount;
      _lastItemCount = items.length;

      setState(() {
        _items = items;
        _isLoading = false;
        _errorMessage = null;
        if (hasNew) {
          _hasNewOrderAlert = true;
        }
      });

      if (hasNew) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _hasNewOrderAlert = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể kết nối máy chủ Bếp KDS';
      });
    }
  }

  Future<void> _updateCookingStatus(int orderDetailId, int newStatus) async {
    final success = await _orderRepo.updateCookingStatus(orderDetailId, newStatus);
    if (success && mounted) {
      _loadKdsItems(showSpinner: false);
    }
  }

  Future<void> _batchUpdateCookingStatus(List<KdsItemModel> groupItems, int newStatus) async {
    for (final item in groupItems) {
      await _orderRepo.updateCookingStatus(item.orderDetailId, newStatus);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật hàng loạt ${groupItems.length} món ăn!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadKdsItems(showSpinner: false);
    }
  }

  String _formatElapsed(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    return '${diff.inMinutes} phút trước';
  }

  Color _getTimerColor(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes >= 15) return const Color(0xFFEF4444); // Đỏ: Quá 15p
    if (diff.inMinutes >= 8) return const Color(0xFFF59E0B); // Vàng: 8-15p
    return const Color(0xFF10B981); // Xanh: < 8p
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lọc theo trạm (Station Filter: Bếp vs Bar)
    final stationFiltered = _items.where((i) {
      if (_selectedStation == 1) return !_isDrink(i.productName);
      if (_selectedStation == 2) return _isDrink(i.productName);
      return true;
    }).toList();

    // 2. Lọc theo trạng thái chế biến
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
                    : (_selectedStation == 2 ? 'Quầy Bar (Drink KDS)' : 'Màn hình Bếp & Pha chế (KDS)'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Toggle Batch Prep Mode
          IconButton(
            icon: Icon(
              _isBatchPrepMode ? Icons.layers_rounded : Icons.layers_outlined,
              color: _isBatchPrepMode ? const Color(0xFFF59E0B) : Colors.white70,
            ),
            tooltip: _isBatchPrepMode ? 'Chuyển sang xem theo đơn' : 'Bật chế độ Gom món (Batch Prep)',
            onPressed: () => setState(() => _isBatchPrepMode = !_isBatchPrepMode),
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
          // New Order Pulse Alert Banner
          if (_hasNewOrderAlert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFDC2626),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notification_important_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ĐƠN MỚI TIẾP NHẬN! Vui lòng ưu tiên chế biến',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Station Selector Chips (Bếp Food vs Quầy Bar)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildStationChip(0, 'Tất cả trạm', Icons.all_inclusive_rounded),
                const SizedBox(width: 8),
                _buildStationChip(1, 'Bếp nấu (Food)', Icons.restaurant_rounded),
                const SizedBox(width: 8),
                _buildStationChip(2, 'Quầy Bar (Drink)', Icons.local_cafe_rounded),
              ],
            ),
          ),

          // Cooking Status Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildKdsTab(
                  label: 'Chờ nấu',
                  count: pendingCount,
                  status: 0,
                  activeColor: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _buildKdsTab(
                  label: 'Đang làm',
                  count: cookingCount,
                  status: 1,
                  activeColor: const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8),
                _buildKdsTab(
                  label: 'Đã xong',
                  count: readyCount,
                  status: 2,
                  activeColor: const Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                _buildKdsTab(
                  label: 'Tất cả',
                  count: stationFiltered.length,
                  status: -1,
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),

          // Main View: Batch Prep Mode vs Regular Ticket Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : (_errorMessage != null && _items.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 54, color: Color(0xFFF59E0B)),
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            ),
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
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.soup_kitchen_outlined, size: 64, color: Color(0xFF475569)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Hiện tại không có món ăn nào trong hàng đợi',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                                ),
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
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF475569),
            ),
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
                    fontSize: 11,
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
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 480,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
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
                  // Header: Table name & Elapsed Timer
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
                            item.tableName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: timerColor),
                          const SizedBox(width: 4),
                          Text(
                            _formatElapsed(item.createdAt),
                            style: TextStyle(
                              color: timerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Main: Quantity & Dish Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.itemNote != null && item.itemNote!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ghi chú: ${item.itemNote}',
                                style: const TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Action buttons (1-touch transitions)
                  Row(
                    children: [
                      if (item.cookingStatus == 0) ...[
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
                        ),
                      ] else if (item.cookingStatus == 1) ...[
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
                        ),
                      ] else ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _updateCookingStatus(item.orderDetailId, 3),
                            icon: const Icon(Icons.room_service_rounded, size: 16),
                            label: const Text('Đã giao món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
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
    // Nhóm các món theo tên món ăn
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Tổng: $totalQty phần',
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 6),

                // Table breakdown list
                ...items.map((item) {
                  return Padding(
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
                          child: Text(
                            item.tableName,
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
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
                          item.cookingStatus == 0
                              ? 'Chờ nấu'
                              : (item.cookingStatus == 1 ? 'Đang làm' : 'Xong'),
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
                  );
                }),

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
                          label: Text('Bắt đầu làm tất cả (${pendingItems.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFF334155),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

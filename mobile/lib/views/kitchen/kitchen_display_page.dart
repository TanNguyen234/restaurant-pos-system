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
  Timer? _refreshTimer;
  int _selectedFilterStatus = 0; // 0: Chờ nấu, 1: Đang nấu, 2: Đã xong, -1: Tất cả

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

  Future<void> _loadKdsItems({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final items = await _orderRepo.getKdsActiveItems();
    if (!mounted) return;

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _updateCookingStatus(int orderDetailId, int newStatus) async {
    final success = await _orderRepo.updateCookingStatus(orderDetailId, newStatus);
    if (success && mounted) {
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
    final filtered = _selectedFilterStatus == -1
        ? _items
        : _items.where((i) => i.cookingStatus == _selectedFilterStatus).toList();

    final pendingCount = _items.where((i) => i.cookingStatus == 0).length;
    final cookingCount = _items.where((i) => i.cookingStatus == 1).length;
    final readyCount = _items.where((i) => i.cookingStatus == 2).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark mode background for kitchen screen
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.kitchen_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text(
              'Màn hình Bếp & Pha chế (KDS)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới ngay',
            onPressed: () => _loadKdsItems(showSpinner: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  count: _items.length,
                  status: -1,
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),

          // Items Grid / List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
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
                    : RefreshIndicator(
                        onRefresh: () => _loadKdsItems(showSpinner: false),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380,
                            mainAxisExtent: 220,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final timerColor = _getTimerColor(item.createdAt);

                            return Card(
                              elevation: 2,
                              color: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: item.cookingStatus == 1
                                      ? const Color(0xFF38BDF8)
                                      : (item.cookingStatus == 2
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF334155)),
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
                                        Container(
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
                      ),
          ),
        ],
      ),
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

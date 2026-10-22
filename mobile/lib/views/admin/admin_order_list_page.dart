import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';
import '../order/order_detail_page.dart';

class AdminOrderListPage extends StatefulWidget {
  const AdminOrderListPage({super.key});

  @override
  State<AdminOrderListPage> createState() => _AdminOrderListPageState();
}

class _AdminOrderListPageState extends State<AdminOrderListPage> {
  final _orderRepo = OrderRepository();
  final _searchController = TextEditingController();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<OrderModel> _orders = [];
  int _totalOrders = 0;
  double _totalRevenue = 0;
  bool _isLoading = true;

  int? _selectedStatus; // null: All, 0: New, 1: Cooking, 2: Served, 3: Completed, 4: Cancelled
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    final res = await _orderRepo.getAdminOrders(
      fromDate: _selectedDateRange?.start,
      toDate: _selectedDateRange?.end,
      status: _selectedStatus,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _orders = (res['orders'] as List<OrderModel>?) ?? [];
      _totalOrders = res['totalOrders'] ?? _orders.length;
      _totalRevenue = (res['totalRevenue'] as num? ?? 0).toDouble();
      _isLoading = false;
    });
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return const Color(0xFF3B82F6); // Blue
      case 1:
        return const Color(0xFFF59E0B); // Amber
      case 2:
        return const Color(0xFF8B5CF6); // Purple
      case 3:
        return const Color(0xFF10B981); // Green
      case 4:
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản trị Đơn hàng & Doanh thu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Bảng điều khiển cho Quản lý & Thu ngân',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Bar (Total Revenue & Order Count)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng đơn hàng',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_totalOrders đơn',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doanh thu đơn',
                          style: TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(_totalRevenue),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filters Row (Search & Date Range & Status Chips)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm theo mã đơn, tên khách...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadOrders();
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _loadOrders(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedDateRange != null
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFF1F5F9),
                        foregroundColor: _selectedDateRange != null
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDateRange: _selectedDateRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              ),
                        );
                        if (picked != null) {
                          setState(() => _selectedDateRange = picked);
                          _loadOrders();
                        }
                      },
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(
                        _selectedDateRange == null
                            ? 'Lọc ngày'
                            : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Horizontal Status Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Tất cả'),
                        selected: _selectedStatus == null,
                        onSelected: (_) {
                          setState(() => _selectedStatus = null);
                          _loadOrders();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Mới tạo'),
                        selected: _selectedStatus == 0,
                        onSelected: (_) {
                          setState(() => _selectedStatus = 0);
                          _loadOrders();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Đang chế biến'),
                        selected: _selectedStatus == 1,
                        onSelected: (_) {
                          setState(() => _selectedStatus = 1);
                          _loadOrders();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Đã phục vụ'),
                        selected: _selectedStatus == 2,
                        onSelected: (_) {
                          setState(() => _selectedStatus = 2);
                          _loadOrders();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Hoàn thành'),
                        selected: _selectedStatus == 3,
                        onSelected: (_) {
                          setState(() => _selectedStatus = 3);
                          _loadOrders();
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Đã hủy'),
                        selected: _selectedStatus == 4,
                        onSelected: (_) {
                          setState(() => _selectedStatus = 4);
                          _loadOrders();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 54, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            const Text(
                              'Không có đơn hàng nào khớp điều kiện lọc',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = null;
                                  _selectedDateRange = null;
                                  _searchController.clear();
                                });
                                _loadOrders();
                              },
                              child: const Text('Xóa bộ lọc'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final ord = _orders[index];
                            final statusColor = _getStatusColor(ord.status);

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              color: Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ord.orderCode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      currencyFormatter.format(ord.finalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${ord.tableName} • ${ord.customerName} • ${DateFormat('HH:mm dd/MM').format(ord.createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ord.statusText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: ord.isPaid
                                                ? const Color(0xFFECFDF5)
                                                : const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ord.paymentStatusText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: ord.isPaid
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderDetailPage(orderId: ord.orderId),
                                    ),
                                  ).then((_) => _loadOrders());
                                },
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
}

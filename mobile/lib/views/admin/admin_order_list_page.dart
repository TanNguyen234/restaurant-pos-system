import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';
import '../../services/csv_export_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/revenue_charts.dart';
import '../../widgets/skeleton_loading.dart';
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
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, dynamic>? _analytics;
  StreamSubscription<PosRealtimeEvent>? _rtSub;
  int _totalOrders = 0;
  double _totalRevenue = 0;
  bool _isLoading = true;
  String? _errorMessage;

  int? _selectedStatus;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    PosRealtimeService.instance.ensureStarted();
    _rtSub = PosRealtimeService.instance.events.listen((ev) {
      if (mounted && ev.target == 'OrderEvent') {
        _loadOrders();
      }
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _orderRepo.getAdminOrders(
        fromDate: _selectedDateRange?.start,
        toDate: _selectedDateRange?.end,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      Map<String, dynamic>? analyticsData;
      try {
        analyticsData = await _orderRepo.getAnalytics(
          days: 7,
          fromDate: _selectedDateRange?.start,
          toDate: _selectedDateRange?.end,
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _orders = (res['orders'] as List<OrderModel>?) ?? [];
        _topProducts = (res['topProducts'] as List<Map<String, dynamic>>?) ?? [];
        _analytics = analyticsData ?? _analytics;
        _totalOrders = (res['totalOrders'] as num?)?.toInt() ?? _orders.length;
        _totalRevenue = (res['totalRevenue'] as num? ?? 0).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải báo cáo đơn hàng: $e';
      });
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return const Color(0xFF3B82F6);
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF8B5CF6);
      case 3:
        return const Color(0xFF10B981);
      case 4:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildDashboardHeader() {
    final paidCount = _orders.where((o) => o.paymentStatus == 1 && o.status != 4).length;
    final aov = paidCount > 0 ? _totalRevenue / paidCount : 0.0;
    final completedCount = _orders.where((o) => o.status == 3).length;
    final completionRate = _totalOrders > 0 ? (completedCount / _totalOrders * 100).toStringAsFixed(0) : '0';

    final maxQty = _topProducts.isNotEmpty
        ? _topProducts.map((e) => (e['totalQuantity'] as num? ?? 1).toInt()).reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng đơn hàng', style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                      const SizedBox(height: 2),
                      Text('$_totalOrders đơn', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Doanh thu thực thu', style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormatter.format(_totalRevenue),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TB/Đơn (AOV)', style: TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormatter.format(aov),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tỷ lệ hoàn thành', style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8))),
                      const SizedBox(height: 2),
                      Text('$completionRate%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_topProducts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 4),
                      Text('Top Món Bán Chạy Nhất', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._topProducts.take(5).map((tp) {
                    final name = (tp['productName'] ?? '').toString();
                    final qty = (tp['totalQuantity'] as num? ?? 0).toInt();
                    final unit = (tp['unit'] ?? 'Ly').toString();
                    final fraction = maxQty > 0 ? (qty / maxQty).clamp(0.0, 1.0) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$qty $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          if (_analytics != null) RevenueAnalyticsPanel(analytics: _analytics!),
        ],
      ),
    );
  }

  Future<void> _exportCsvFile() async {
    try {
      final bundle = await _orderRepo.exportOrdersCsvBytes(
        fromDate: _selectedDateRange?.start,
        toDate: _selectedDateRange?.end,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      final exportRes = await CsvExportService.saveOrShareCsv(
        fileName: bundle.fileName,
        bytes: bundle.bytes,
      );
      if (!mounted) return;
      final lineCount = bundle.csvText.trim().split('\n').length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${exportRes.message} ($lineCount dòng)'),
          backgroundColor: exportRes.savedAsFile ? const Color(0xFF059669) : const Color(0xFF0F172A),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Xem / Copy',
            textColor: const Color(0xFFFDE68A),
            onPressed: () {
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('${bundle.fileName} ($lineCount dòng)'),
                  content: SizedBox(
                    width: 560,
                    height: 280,
                    child: SingleChildScrollView(
                      child: SelectableText(bundle.csvText, style: const TextStyle(fontFamily: 'Courier', fontSize: 11.5)),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                    FilledButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Sao chép CSV'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: bundle.csvText));
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildFiltersBar() {
    return Container(
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
                  backgroundColor: _selectedDateRange != null ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                  foregroundColor: _selectedDateRange != null ? Colors.white : const Color(0xFF0F172A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                icon: const Icon(Icons.calendar_month, size: 17),
                label: Text(
                  _selectedDateRange == null
                      ? 'Lọc ngày'
                      : '${DateFormat('dd/MM').format(_selectedDateRange!.start)}-${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              if (_selectedDateRange != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'Xóa lọc ngày',
                  onPressed: () {
                    setState(() => _selectedDateRange = null);
                    _loadOrders();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                  label: const Text('Đang nấu'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quản trị Đơn hàng & Doanh thu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Bảng điều khiển cho Quản lý & Thu ngân', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Tải file CSV (Excel)', onPressed: _exportCsvFile),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Tải lại', onPressed: _loadOrders),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildDashboardHeader(),
            _buildFiltersBar(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonListPlaceholder(itemCount: 4),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                      const SizedBox(height: 10),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _loadOrders, child: const Text('Thử lại')),
                    ],
                  ),
                ),
              )
            else if (_orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 54, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text('Không có đơn hàng nào khớp điều kiện lọc', style: TextStyle(color: Color(0xFF64748B))),
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
            else
              ..._orders.map((ord) {
                final statusColor = _getStatusColor(ord.status);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              ord.orderCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currencyFormatter.format(ord.finalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                child: Text(ord.statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ord.isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ord.paymentStatusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: ord.isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: ord.orderId)),
                      ).then((_) => _loadOrders()),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

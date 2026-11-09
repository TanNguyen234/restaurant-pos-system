import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/receipt_printer_service.dart';

class ShiftManagementPage extends StatefulWidget {
  const ShiftManagementPage({super.key});

  @override
  State<ShiftManagementPage> createState() => _ShiftManagementPageState();
}

class _ShiftManagementPageState extends State<ShiftManagementPage> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isLoading = true;
  Map<String, dynamic>? _currentShift;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentShift();
  }

  Future<void> _loadCurrentShift() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiConfig.get(Uri.parse('${ApiConfig.baseUrl}/api/shift/current'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _currentShift = data['data'] != null ? Map<String, dynamic>.from(data['data']) : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentShift = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể kết nối máy chủ quản lý ca';
        _isLoading = false;
      });
    }
  }

  Future<void> _openShift() async {
    final floatCtrl = TextEditingController(text: '500000');
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Mở ca làm việc mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập số tiền mặt đầu ca để chuẩn bị tiền thối lẻ:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: floatCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tiền mặt đầu ca (VNĐ) *',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Ghi chú mở ca',
                hintText: 'VD: Ca sáng 06:00 - 14:00',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận mở ca', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final initialFloat = double.tryParse(floatCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    try {
      final res = await ApiConfig.post(
        Uri.parse('${ApiConfig.baseUrl}/api/shift/open'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initialFloat': initialFloat,
          'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message']?.toString() ?? 'Mở ca thành công!'),
          backgroundColor: res.statusCode == 200 ? const Color(0xFF059669) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadCurrentShift();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi mở ca: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _closeShift() async {
    if (_currentShift == null) return;
    final shiftId = _currentShift!['shiftId'] ?? _currentShift!['id'];
    final initialFloat = (_currentShift!['initialFloat'] as num?)?.toDouble() ?? 0.0;
    final cashSales = (_currentShift!['totalCashSales'] as num?)?.toDouble() ?? 0.0;
    final expectedCash = initialFloat + cashSales;

    final actualCashCtrl = TextEditingController(text: expectedCash.toInt().toString());
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) {
          final counted = double.tryParse(actualCashCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
          final diff = counted - expectedCash;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Đóng ca & Kết sổ (Z-Report)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryLine('Tiền đầu ca (Float):', _currencyFormat.format(initialFloat)),
                        _buildSummaryLine('Doanh thu tiền mặt:', _currencyFormat.format(cashSales)),
                        const Divider(height: 12),
                        _buildSummaryLine('Tiền mặt dự kiến trong két:', _currencyFormat.format(expectedCash), isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: actualCashCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Tiền mặt thực tế kiểm đếm *',
                      prefixIcon: const Icon(Icons.point_of_sale_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chênh lệch tiền mặt:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(
                        diff == 0 ? 'Khớp 100%' : (diff > 0 ? '+${_currencyFormat.format(diff)} (Thừa)' : '${_currencyFormat.format(diff)} (Thiếu)'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: diff == 0 ? const Color(0xFF059669) : (diff > 0 ? const Color(0xFF0284C7) : const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú đóng ca',
                      hintText: 'VD: Khớp sổ, bàn giao ca chiều',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xác nhận đóng ca', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final actualCash = double.tryParse(actualCashCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    try {
      final res = await ApiConfig.post(
        Uri.parse('${ApiConfig.baseUrl}/api/shift/close'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'shiftId': shiftId,
          'actualCash': actualCash,
          'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message']?.toString() ?? 'Đóng ca thành công!'),
          backgroundColor: res.statusCode == 200 ? const Color(0xFF059669) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadCurrentShift();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đóng ca: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  void _printZReport() {
    if (_currentShift == null) return;
    final shiftCode = _currentShift!['shiftCode'] ?? 'SHIFT-001';
    final initialFloat = (_currentShift!['initialFloat'] as num?)?.toDouble() ?? 0.0;
    final totalCash = (_currentShift!['totalCashSales'] as num?)?.toDouble() ?? 0.0;
    final totalCard = (_currentShift!['totalCardSales'] as num?)?.toDouble() ?? 0.0;
    final totalDiscount = (_currentShift!['totalDiscount'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = _currentShift!['totalOrders'] ?? 0;
    final totalSales = totalCash + totalCard;

    ReceiptPrinterService.showReceiptPreview(
      context: context,
      isPreCheckBill: false,
      order: {
        'orderCode': 'Z-REPORT-$shiftCode',
        'tableName': 'Toàn nhà hàng',
        'customerName': 'Báo cáo doanh thu kết ca',
        'creatorName': _currentShift!['staffName'] ?? 'Thu ngân ca',
        'createdAt': DateTime.now().toIso8601String(),
        'totalAmount': totalSales + totalDiscount,
        'discountAmount': totalDiscount,
        'finalAmount': totalSales,
        'details': [
          {'productName': 'Tiền mặt đầu ca (Float)', 'quantity': 1, 'price': initialFloat, 'subTotal': initialFloat},
          {'productName': 'Doanh thu Tiền mặt ($totalOrders đơn)', 'quantity': totalOrders, 'price': totalCash, 'subTotal': totalCash},
          {'productName': 'Doanh thu Chuyển khoản VietQR/VNPay', 'quantity': 1, 'price': totalCard, 'subTotal': totalCard},
        ],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quản lý Ca làm việc (Shift Register)'),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentShift,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(fontSize: 15, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadCurrentShift, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _currentShift == null
                  ? _buildNoShiftView()
                  : _buildActiveShiftView(),
    );
  }

  Widget _buildNoShiftView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.point_of_sale_rounded, size: 64, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có Ca làm việc nào đang mở',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mở ca thu ngân để bắt đầu nhập tiền thối lẻ, ghi nhận hóa đơn và theo dõi doanh thu trong ca.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('MỞ CA THU NGÂN NGAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _openShift,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShiftView() {
    final shift = _currentShift!;
    final shiftCode = shift['shiftCode'] ?? 'SHIFT-001';
    final staffName = shift['staffName'] ?? 'Nhân viên';
    final openedAtStr = shift['openedAt'];
    final openedAt = openedAtStr != null ? DateTime.tryParse(openedAtStr.toString()) : null;
    final initialFloat = (shift['initialFloat'] as num?)?.toDouble() ?? 0.0;
    final totalCash = (shift['totalCashSales'] as num?)?.toDouble() ?? 0.0;
    final totalCard = (shift['totalCardSales'] as num?)?.toDouble() ?? 0.0;
    final totalDiscount = (shift['totalDiscount'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = shift['totalOrders'] ?? 0;
    final totalRevenue = totalCash + totalCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift Active Card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shiftCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Thu ngân: $staffName', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: const Text('Đang hoạt động', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text('Mở lúc: ${openedAt != null ? _dateFormat.format(openedAt) : "Hôm nay"}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Key Metrics Grid
          const Text('Báo cáo thống kê ca hiện tại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Doanh thu tổng',
                  value: _currencyFormat.format(totalRevenue),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Tổng hóa đơn',
                  value: '$totalOrders đơn',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Tiền mặt đầu ca (Float)',
                  value: _currencyFormat.format(initialFloat),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFD97706),
                  bg: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Thu tiền mặt trong ca',
                  value: _currencyFormat.format(totalCash),
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF7C3AED),
                  bg: const Color(0xFFF3E8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Chuyển khoản QR / Thẻ',
                  value: _currencyFormat.format(totalCard),
                  icon: Icons.qr_code_2_rounded,
                  color: const Color(0xFF0F172A),
                  bg: const Color(0xFFF1F5F9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Khuyến mãi / Giảm giá',
                  value: _currencyFormat.format(totalDiscount),
                  icon: Icons.discount_outlined,
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF0F172A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_outlined, color: Color(0xFF0F172A)),
                  label: const Text('In Z-Report', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                  onPressed: _printZReport,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: const Text('ĐÓNG CA LÀM VIỆC', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _closeShift,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String title, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: isBold ? Colors.black : const Color(0xFF475569), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}

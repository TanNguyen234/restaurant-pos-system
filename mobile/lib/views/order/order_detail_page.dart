import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../repositories/order_repository.dart';

class OrderDetailPage extends StatefulWidget {
  final int orderId;
  final String? initialPaymentMethod;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialPaymentMethod,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _orderRepo = OrderRepository();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  OrderModel? _order;
  VietQrModel? _vietQr;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String _paymentMethod = 'VietQR';

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentMethod != null) {
      _paymentMethod = widget.initialPaymentMethod!;
    }
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);

    final order = await _orderRepo.getOrderById(widget.orderId);
    final qr = await _orderRepo.getVietQr(widget.orderId);

    if (!mounted) return;

    setState(() {
      _order = order;
      _vietQr = qr;
      _isLoading = false;
    });
  }

  Future<void> _handleConfirmPayment() async {
    if (_order == null) return;

    setState(() => _isProcessingPayment = true);

    final result = await _orderRepo.confirmPayment(
      orderId: _order!.orderId,
      paymentMethod: _paymentMethod,
      amount: _order!.finalAmount,
      note: 'Thanh toán trực tiếp tại màn hình chi tiết đơn hàng',
    );

    if (!mounted) return;

    setState(() => _isProcessingPayment = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Xác nhận thanh toán thành công!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadOrderDetails();
    }
  }

  Future<void> _handleUpdateStatus(int newStatus) async {
    if (_order == null) return;

    final success = await _orderRepo.updateOrderStatus(_order!.orderId, newStatus);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật trạng thái đơn hàng'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadOrderDetails();
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return const Color(0xFF3B82F6); // Blue: New
      case 1:
        return const Color(0xFFF59E0B); // Amber: Cooking
      case 2:
        return const Color(0xFF8B5CF6); // Purple: Served
      case 3:
        return const Color(0xFF10B981); // Green: Completed
      case 4:
        return const Color(0xFFEF4444); // Red: Cancelled
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
        body: const Center(child: Text('Không tìm thấy thông tin đơn hàng')),
      );
    }

    final order = _order!;
    final isPaid = order.isPaid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Đơn #${order.orderCode}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrderDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderCode,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${order.tableName} • ${DateFormat("HH:mm dd/MM/yyyy").format(order.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getStatusColor(order.status)),
                          ),
                          child: Text(
                            order.statusText,
                            style: TextStyle(
                              color: _getStatusColor(order.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Khách: ${order.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.phone, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            order.phoneNumber!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                    if (order.note != null && order.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.note_alt_outlined, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ghi chú: ${order.note}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB45309),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // VietQR Payment Section (Dynamic Banking QR Code)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isPaid ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  width: 1.5,
                ),
              ),
              color: isPaid ? const Color(0xFFECFDF5) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPaid ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaid ? Icons.check : Icons.qr_code_2_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPaid ? 'ĐÃ HOÀN TẤT THANH TOÁN' : 'MÃ THANH TOÁN VIETQR (NAPAS 247)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isPaid ? const Color(0xFF065F46) : const Color(0xFF0369A1),
                                ),
                              ),
                              Text(
                                isPaid
                                    ? 'Đơn hàng đã được đối soát và ghi nhận doanh thu'
                                    : 'Quét mã bằng app Mobile Banking bất kỳ để chuyển tiền',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isPaid && _vietQr != null) ...[
                      const Divider(height: 24),
                      // Hiển thị ảnh VietQR
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _vietQr!.qrImageUrl,
                                height: 230,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) {
                                  return Container(
                                    height: 180,
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.qr_code_2_rounded, size: 64, color: Color(0xFF0284C7)),
                                          SizedBox(height: 8),
                                          Text(
                                            'Mã VietQR NAPAS 247\n(Cần kết nối mạng để hiển thị ảnh QR)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Ngân hàng:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      Text(_vietQr!.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Số tài khoản:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      Row(
                                        children: [
                                          Text(
                                            _vietQr!.accountNo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 14),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Sao chép số tài khoản',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: _vietQr!.accountNo));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Đã sao chép số tài khoản!')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Chủ tài khoản:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      Text(_vietQr!.accountName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Nội dung chuyển khoản:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      Text(_vietQr!.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Nút xác nhận thu tiền / thanh toán
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: _isProcessingPayment ? null : _handleConfirmPayment,
                        icon: _isProcessingPayment
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text(
                          'Xác Nhận Đã Nhận Tiền & Hoàn Tất Đơn',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order Items List
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết món trong đơn',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final item = order.items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (item.itemNote != null && item.itemNote!.isNotEmpty)
                                    Text(
                                      'Ghi chú: ${item.itemNote}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.cookingStatus == 2
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.cookingStatusText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: item.cookingStatus == 2
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormatter.format(item.subTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 24),
                    // Summary totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính:', style: TextStyle(color: Color(0xFF64748B))),
                        Text(currencyFormatter.format(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (order.discountAmount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Chiết khấu / Giảm giá:', style: TextStyle(color: Color(0xFF059669))),
                          Text('-${currencyFormatter.format(order.discountAmount)}', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          currencyFormatter.format(order.finalAmount),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Status Actions for Waiter / Cashier
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chuyển đổi trạng thái đơn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('1. Bếp đang nấu'),
                          avatar: const Icon(Icons.soup_kitchen, size: 16),
                          onPressed: () => _handleUpdateStatus(1),
                        ),
                        ActionChip(
                          label: const Text('2. Đã phục vụ'),
                          avatar: const Icon(Icons.room_service, size: 16),
                          onPressed: () => _handleUpdateStatus(2),
                        ),
                        ActionChip(
                          label: const Text('3. Hoàn thành'),
                          avatar: const Icon(Icons.check_circle, size: 16),
                          onPressed: () => _handleUpdateStatus(3),
                        ),
                        ActionChip(
                          label: const Text('4. Hủy đơn'),
                          avatar: const Icon(Icons.cancel, size: 16, color: Colors.red),
                          onPressed: () => _handleUpdateStatus(4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

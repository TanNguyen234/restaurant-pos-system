import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../repositories/order_repository.dart';
import '../../services/receipt_printer_service.dart';
import '../../services/session_manager.dart';
import '../../utils/database_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/skeleton_loading.dart';
import '../cart_page.dart';

class OrderDetailPage extends StatefulWidget {
  final int orderId;
  final String? initialPaymentMethod;
  final String? vnpayStatus;
  final String? vnpayCode;
  final bool autoRestoreToCart;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialPaymentMethod,
    this.vnpayStatus,
    this.vnpayCode,
    this.autoRestoreToCart = false,
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
  bool _isRestoringToCart = false;
  bool _didAutoRestore = false;
  String? _errorMessage;
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _orderRepo.getOrderById(widget.orderId);
      VietQrModel? qr;
      if (order != null && !order.isPaid && order.status != 4) {
        try {
          qr = await _orderRepo.getVietQr(
            widget.orderId,
            amount: order.remainingAmount > 0 ? order.remainingAmount : order.finalAmount,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _order = order;
        _vietQr = qr;
        _isLoading = false;
      });

      if (widget.autoRestoreToCart &&
          !_didAutoRestore &&
          order != null &&
          !order.isPaid &&
          order.status != 3 &&
          order.status != 4) {
        _didAutoRestore = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _cancelAndRestoreToCart(skipConfirm: true);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải thông tin đơn hàng: $e';
      });
    }
  }

  Future<void> _cancelAndRestoreToCart({bool skipConfirm = false}) async {
    final order = _order;
    if (order == null || _isRestoringToCart) return;

    final activeItems = order.items.where((i) => !i.isVoided && i.quantity > 0).toList();
    if (activeItems.isEmpty) {
      showAutoDismissSnackBar(
        context,
        message: 'Đơn hàng không còn món hợp lệ để khôi phục về giỏ hàng.',
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    if (!skipConfirm) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hủy đơn & Khôi phục giỏ hàng?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Đơn #${order.orderCode} chưa thanh toán sẽ được hủy và ${activeItems.length} món sẽ được đưa trở lại giỏ hàng để bạn chỉnh sửa hoặc chọn lại phương thức thanh toán.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ lại đơn')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Khôi phục về giỏ'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _isRestoringToCart = true);
    final cancelRes = await _orderRepo.cancelUnpaidOrder(order.orderId);
    if (!mounted) return;

    if (cancelRes['success'] != true) {
      setState(() => _isRestoringToCart = false);
      showAutoDismissSnackBar(
        context,
        message: cancelRes['message']?.toString() ?? 'Không thể hủy đơn để hoàn về giỏ hàng.',
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    final db = DatabaseHelper();
    for (final item in activeItems) {
      await db.insertOrUpdateCart({
        'product_id': item.productId,
        'product_name': item.productName,
        'price': item.unitPrice,
        'quantity': item.quantity,
        'image_url': item.productImage,
        'note': item.itemNote,
        'modifiers_json': item.modifiers.isNotEmpty ? jsonEncode(item.modifiers) : null,
      });
    }

    if (!mounted) return;
    setState(() => _isRestoringToCart = false);
    showAutoDismissSnackBar(
      context,
      message: 'Đã khôi phục ${activeItems.length} món về giỏ hàng!',
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFF059669),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
  }

  Future<void> _showVoidItemDialog(OrderItemModel item) async {
    if (_order == null) return;
    String selectedReason = 'Khách đổi ý / Đổi món';
    int voidQty = 1;
    final otherReasonController = TextEditingController();
    final reasons = [
      'Khách đổi ý / Đổi món',
      'Bếp báo hết nguyên liệu',
      'Món làm sai yêu cầu khách',
      'Chờ quá lâu không muốn đợi',
      'Khác...',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Xác nhận hủy món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Món: ${item.productName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (item.quantity > 1) ...[
                  Row(
                    children: [
                      const Text('Số lượng hủy:', style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: voidQty > 1 ? () => setDialogState(() => voidQty--) : null,
                      ),
                      Text('$voidQty / ${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: voidQty < item.quantity ? () => setDialogState(() => voidQty++) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const Text('Lý do hủy món (*):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...reasons.map((r) {
                  final isSelected = selectedReason == r;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedReason = r),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18,
                            color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReason == 'Khác...') ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: otherReasonController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập lý do hủy chi tiết...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Đóng', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Hủy món ngay', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted && _order != null) {
      final reason = selectedReason == 'Khác...'
          ? (otherReasonController.text.trim().isNotEmpty ? otherReasonController.text.trim() : 'Lý do khác')
          : selectedReason;

      final res = await _orderRepo.voidOrderItem(
        orderId: _order!.orderId,
        orderDetailId: item.orderDetailId,
        reason: reason,
        voidQuantity: voidQty,
      );

      if (!mounted) return;
      showAutoDismissSnackBar(
        context,
        message: res['message']?.toString() ?? (res['success'] == true ? 'Đã hủy món thành công' : 'Không thể hủy món'),
        backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      );
      if (res['success'] == true) _loadOrderDetails();
    }
  }

  Future<void> _handleConfirmPayment() async {
    if (_order == null) return;
    setState(() => _isProcessingPayment = true);

    final amountToPay = _order!.remainingAmount > 0 ? _order!.remainingAmount : _order!.finalAmount;
    final result = await _orderRepo.confirmPayment(
      orderId: _order!.orderId,
      paymentMethod: _paymentMethod == 'VNPay' ? 'Cash' : _paymentMethod,
      amount: amountToPay,
      note: 'Thanh toán tại màn hình chi tiết đơn hàng',
    );

    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

    showAutoDismissSnackBar(
      context,
      message: result['message']?.toString() ?? (result['success'] == true ? 'Thanh toán thành công!' : 'Không thể xác nhận thanh toán'),
      backgroundColor: result['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
    );
    if (result['success'] == true) _loadOrderDetails();
  }

  Future<void> _launchVnpaySandbox() async {
    if (_order == null) return;
    setState(() => _isProcessingPayment = true);
    try {
      final amount = _order!.remainingAmount > 0 ? _order!.remainingAmount : _order!.finalAmount;
      final url = await _orderRepo.createVnpayUrl(
        _order!.orderId,
        amount,
        'Thanh toan don ${_order!.orderCode}',
      );
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);

      if (url == null || url.isEmpty) {
        showAutoDismissSnackBar(
          context,
          message: 'Không tạo được liên kết thanh toán VNPay',
          backgroundColor: const Color(0xFFDC2626),
        );
        return;
      }

      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (launched) {
        showAutoDismissSnackBar(
          context,
          message: 'Đã mở cổng VNPay Sandbox. Sau khi hoàn tất, bấm Làm mới để cập nhật trạng thái đơn!',
          backgroundColor: const Color(0xFF0284C7),
          duration: const Duration(seconds: 5),
        );
      } else {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Liên kết VNPay Sandbox'),
            content: SelectableText(url, style: const TextStyle(fontSize: 12)),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(ctx);
                },
                child: const Text('Sao chép URL'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      showAutoDismissSnackBar(
        context,
        message: '$e',
        backgroundColor: const Color(0xFFDC2626),
      );
    }
  }

  Future<void> _handleUpdateStatus(int newStatus) async {
    if (_order == null) return;
    final success = await _orderRepo.updateOrderStatus(_order!.orderId, newStatus);
    if (!mounted) return;

    showAutoDismissSnackBar(
      context,
      message: success ? 'Đã cập nhật trạng thái đơn hàng' : 'Không đủ quyền hoặc trạng thái không hợp lệ',
      backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFDC2626),
    );
    if (success) _loadOrderDetails();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
        body: const SkeletonListPlaceholder(itemCount: 4),
      );
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Không tìm thấy thông tin đơn hàng', textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton(onPressed: _loadOrderDetails, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final isPaid = order.isPaid;
    final canCollectMoney = SessionManager.instance.isCashier || SessionManager.instance.isManager;
    final isStaff = SessionManager.instance.isStaff;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Đơn #${order.orderCode}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Xem & In hóa đơn',
            onPressed: () => ReceiptPrinterService.showReceiptPreview(
              context: context,
              order: order.toMap(),
              vietQr: _vietQr,
              isPreCheckBill: !isPaid,
              isDuplicate: isPaid,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadOrderDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                  Text(order.orderCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${order.tableName} • ${DateFormat("HH:mm dd/MM/yyyy").format(order.createdAt)}',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                                style: TextStyle(color: _getStatusColor(order.status), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_pin, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text('Khách: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              ],
                            ),
                            if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(order.phoneNumber!, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ],
                              ),
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
                                  style: const TextStyle(fontSize: 13, color: Color(0xFFB45309), fontStyle: FontStyle.italic),
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

                // Payment & VietQR / VNPay Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isPaid ? const Color(0xFF10B981) : const Color(0xFF38BDF8), width: 1.5),
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
                              child: Icon(isPaid ? Icons.check : Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPaid ? 'ĐÃ HOÀN TẤT THANH TOÁN' : 'THANH TOÁN VIETQR & VNPAY SANDBOX',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isPaid ? const Color(0xFF065F46) : const Color(0xFF0369A1),
                                    ),
                                  ),
                                  Text(
                                    isPaid
                                        ? 'Đơn hàng đã được đối soát (${order.paymentMethod ?? "Đã thu tiền"})'
                                        : 'Còn lại cần thu: ${currencyFormatter.format(order.remainingAmount > 0 ? order.remainingAmount : order.finalAmount)}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isPaid && order.status != 4) ...[
                          if (widget.vnpayStatus == 'cancelled' || widget.vnpayStatus == 'failed') ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.vnpayStatus == 'cancelled'
                                        ? 'Bạn đã hủy giao dịch VNPay${widget.vnpayCode != null ? " (Mã ${widget.vnpayCode})" : ""}.'
                                        : 'Thanh toán VNPay chưa thành công${widget.vnpayCode != null ? " (Mã ${widget.vnpayCode})" : ""}.',
                                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Đơn hàng vẫn được giữ nguyên! Bạn có thể chọn phương thức thanh toán khác bên dưới hoặc hủy đơn để hoàn món về giỏ hàng.',
                                    style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('VietQR'),
                                  selected: _paymentMethod == 'VietQR',
                                  onSelected: (_) => setState(() => _paymentMethod = 'VietQR'),
                                ),
                                ChoiceChip(
                                  label: const Text('VNPay Sandbox'),
                                  selected: _paymentMethod == 'VNPay',
                                  onSelected: (_) => setState(() => _paymentMethod = 'VNPay'),
                                ),
                                ChoiceChip(
                                  label: const Text('Tiền mặt tại quầy'),
                                  selected: _paymentMethod == 'Cash',
                                  onSelected: (_) => setState(() => _paymentMethod = 'Cash'),
                                ),
                              ],
                            ),
                          ),
                          if (_paymentMethod == 'VietQR' && _vietQr != null) ...[
                            const Divider(height: 24),
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
                                      height: 220,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 160,
                                        color: const Color(0xFFF1F5F9),
                                        child: const Center(
                                          child: Icon(Icons.qr_code_2_rounded, size: 64, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                                    child: Column(
                                      children: [
                                        _qrInfoRow('Ngân hàng:', _vietQr!.bankName),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Số tài khoản:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            Row(
                                              children: [
                                                Text(
                                                  _vietQr!.accountNo,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                                                ),
                                                const SizedBox(width: 6),
                                                InkWell(
                                                  onTap: () {
                                                    Clipboard.setData(ClipboardData(text: _vietQr!.accountNo));
                                                    showAutoDismissSnackBar(
                                                      context,
                                                      message: 'Đã sao chép số tài khoản!',
                                                      duration: const Duration(seconds: 2),
                                                    );
                                                  },
                                                  child: const Icon(Icons.copy, size: 15),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        _qrInfoRow('Chủ tài khoản:', _vietQr!.accountName),
                                        const SizedBox(height: 6),
                                        _qrInfoRow('Nội dung CK:', _vietQr!.description, highlightColor: const Color(0xFFD97706)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_paymentMethod == 'Cash') ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                'Bạn đã chọn thanh toán tiền mặt cho đơn #${order.orderCode}. Vui lòng thanh toán trực tiếp với nhân viên hoặc tại quầy thu ngân.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF065F46)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (_paymentMethod == 'VNPay' || widget.vnpayStatus == null)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEA580C),
                                side: const BorderSide(color: Color(0xFFEA580C)),
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isProcessingPayment ? null : _launchVnpaySandbox,
                              icon: const Icon(Icons.credit_card_rounded),
                              label: Text(
                                _paymentMethod == 'VNPay'
                                    ? 'Thanh toán qua VNPay Sandbox'
                                    : 'Hoặc thanh toán qua VNPay Sandbox',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (canCollectMoney) ...[
                            const SizedBox(height: 10),
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
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_outline_rounded),
                              label: const Text('Xác Nhận Đã Thu Tiền & Hoàn Tất Đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
                          if (order.status != 3) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isRestoringToCart ? null : () => _cancelAndRestoreToCart(),
                              icon: _isRestoringToCart
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                                  : const Icon(Icons.restore_outlined),
                              label: const Text('Hủy thanh toán & Khôi phục về giỏ hàng', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Chi tiết món trong đơn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () => ReceiptPrinterService.showReceiptPreview(
                                context: context,
                                order: order.toMap(),
                                vietQr: _vietQr,
                                isPreCheckBill: !isPaid,
                                isDuplicate: isPaid,
                              ),
                              icon: const Icon(Icons.receipt_long, size: 16),
                              label: Text(isPaid ? 'In lại HĐ' : 'Phiếu tạm tính'),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: order.items.length,
                          separatorBuilder: (_, _) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final item = order.items[index];
                            final isVoided = item.isVoided;
                            final canVoid = isStaff && !isVoided && !order.isPaid && order.status != 4;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isVoided ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: isVoided ? TextDecoration.lineThrough : null,
                                      color: isVoided ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          decoration: isVoided ? TextDecoration.lineThrough : null,
                                          color: isVoided ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (item.modifiers.isNotEmpty)
                                        Text(
                                          item.modifiers.map((m) => m['modifierName']).whereType<String>().join(' • '),
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                        ),
                                      if (item.itemNote != null && item.itemNote!.isNotEmpty)
                                        Text(
                                          'Ghi chú: ${item.itemNote}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isVoided ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                            fontWeight: isVoided ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isVoided
                                              ? const Color(0xFFFEF2F2)
                                              : (item.cookingStatus >= 2 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.cookingStatusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isVoided
                                                ? const Color(0xFFDC2626)
                                                : (item.cookingStatus >= 2 ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormatter.format(item.subTotal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        decoration: isVoided ? TextDecoration.lineThrough : null,
                                        color: isVoided ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (canVoid)
                                      InkWell(
                                        onTap: () => _showVoidItemDialog(item),
                                        borderRadius: BorderRadius.circular(4),
                                        child: const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.remove_circle_outline, size: 14, color: Color(0xFFEF4444)),
                                              SizedBox(width: 2),
                                              Text('Hủy món', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 24),
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
                              Text('-${currencyFormatter.format(order.discountAmount)}',
                                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        if (order.paidAmount > 0 && !order.isPaid) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Đã thanh toán trước:', style: TextStyle(color: Color(0xFF0284C7))),
                              Text(currencyFormatter.format(order.paidAmount), style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
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

                if (isStaff && !isPaid && order.status != 4) ...[
                  const SizedBox(height: 16),
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
                          const Text('Cập nhật trạng thái đơn (Nhân viên)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                              if (canCollectMoney) ...[
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qrInfoRow(String label, String value, {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: highlightColor ?? const Color(0xFF0F172A)),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

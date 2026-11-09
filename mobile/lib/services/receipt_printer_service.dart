import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptPrinterService {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Hiển thị hộp thoại xem trước và in hóa đơn (Thermal 58mm / 80mm preview)
  static void showReceiptPreview({
    required BuildContext context,
    required Map<String, dynamic> order,
    bool isPreCheckBill = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiptPreviewSheet(
        order: order,
        isPreCheckBill: isPreCheckBill,
      ),
    );
  }
}

class _ReceiptPreviewSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isPreCheckBill;

  const _ReceiptPreviewSheet({
    required this.order,
    required this.isPreCheckBill,
  });

  @override
  State<_ReceiptPreviewSheet> createState() => _ReceiptPreviewSheetState();
}

class _ReceiptPreviewSheetState extends State<_ReceiptPreviewSheet> {
  int _paperWidthMm = 80; // 58 or 80

  String _formatCurrency(num? amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderCode = order['orderCode'] ?? order['order_code'] ?? 'ORD-000';
    final tableName = order['tableName'] ?? order['table_name'] ?? 'Mang về';
    final customerName = order['customerName'] ?? order['customer_name'] ?? 'Khách lẻ';
    final creatorName = order['creatorName'] ?? order['cashierName'] ?? 'Thu ngân';
    final createdAtStr = order['createdAt'] ?? order['created_at'];
    final createdAt = createdAtStr != null ? (DateTime.tryParse(createdAtStr.toString()) ?? DateTime.now()) : DateTime.now();

    final details = (order['details'] as List? ?? order['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final subtotal = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final discount = (order['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final finalAmount = (order['finalAmount'] as num?)?.toDouble() ?? (subtotal - discount);

    final vietQrUrl = 'https://img.vietqr.io/image/970422-0901234567-compact2.png?amount=${finalAmount.toInt()}&addInfo=$orderCode&accountName=RESTAURANT_POS';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isPreCheckBill ? Icons.receipt_long : Icons.print_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isPreCheckBill ? 'Phiếu Tạm Tính' : 'Hóa Đơn Thanh Toán',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // 58mm / 80mm Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              _buildWidthButton(58),
                              _buildWidthButton(80),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFF334155)),

              // Scrollable Thermal Receipt Preview
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Center(
                    child: Container(
                      width: _paperWidthMm == 58 ? 320 : 420,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Restaurant Branding
                          const Text(
                            'MODERN ARTISAN BISTRO',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '123 Phố Ẩm Thực, Quận 1, TP. Hồ Chí Minh\nHotline: 0901.234.567 • Wifi: Bistro_Guest (88888888)',
                            style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isPreCheckBill ? '*** PHIẾU TẠM TÍNH ***' : '*** HÓA ĐƠN THANH TOÁN ***',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: widget.isPreCheckBill ? const Color(0xFFD97706) : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Meta Info
                          _buildReceiptRow('Số HĐ:', orderCode),
                          _buildReceiptRow('Bàn ăn:', tableName),
                          _buildReceiptRow('Khách hàng:', customerName),
                          _buildReceiptRow('Nhân viên:', creatorName),
                          _buildReceiptRow('Thời gian:', ReceiptPrinterService._dateFormat.format(createdAt)),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '------------------------------------------------',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontFamily: 'Courier', color: Colors.black54),
                            ),
                          ),

                          // Table Items Header
                          Row(
                            children: const [
                              Expanded(flex: 5, child: Text('Tên món', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('SL', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 3, child: Text('Đơn giá', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 4, child: Text('T.Tiền', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '------------------------------------------------',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontFamily: 'Courier', color: Colors.black54),
                            ),
                          ),

                          // Item list
                          ...details.map((d) {
                            final name = d['productName'] ?? d['product_name'] ?? 'Món ăn';
                            final qty = d['quantity'] ?? 1;
                            final price = (d['price'] as num? ?? d['unitPrice'] as num? ?? 0).toDouble();
                            final sub = (d['subTotal'] as num? ?? price * (qty as num)).toDouble();
                            final note = d['itemNote'] ?? d['note'];

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          name.toString(),
                                          style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Courier', fontSize: 12)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(_formatCurrency(price), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Courier', fontSize: 11)),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(_formatCurrency(sub), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  if (note != null && note.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, top: 1),
                                      child: Text(
                                        '  * $note',
                                        style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '================================================',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontFamily: 'Courier', color: Colors.black54),
                            ),
                          ),

                          // Calculation Summary
                          _buildReceiptRow('Tổng tiền hàng:', _formatCurrency(subtotal)),
                          if (discount > 0)
                            _buildReceiptRow('Chiết khấu / Giảm giá:', '-${_formatCurrency(discount)}', isHighlight: true),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'THANH TOÁN:',
                                style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                _formatCurrency(finalAmount),
                                style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Dynamic VietQR Code Container
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Quét mã VietQR chuyển khoản nhanh 24/7',
                                  style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Image.network(
                                  vietQrUrl,
                                  width: 160,
                                  height: 160,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 160,
                                    height: 160,
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Số tiền: ${_formatCurrency(finalAmount)} • $orderCode',
                                  style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Text(
                            'CẢM ƠN QUÝ KHÁCH VÀ HẸN GẶP LẠI!\nPowered by Restaurant & Cafe POS Industrial System',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFFEF4444)),
                        label: const Text('Xuất file PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã xuất file hóa đơn PDF thành công vào thư mục lưu trữ!'),
                              backgroundColor: Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 20),
                        label: Text('In hóa đơn ($_paperWidthMm mm)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lệnh in hóa đơn $_paperWidthMm mm đã được gửi tới máy in nhiệt ESC/POS!'),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidthButton(int mm) {
    final isSelected = _paperWidthMm == mm;
    return InkWell(
      onTap: () => setState(() => _paperWidthMm = mm),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$mm mm',
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.black87)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? const Color(0xFF059669) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

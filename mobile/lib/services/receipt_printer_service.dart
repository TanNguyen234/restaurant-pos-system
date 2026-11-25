import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import 'escpos_printer_service.dart';

class ReceiptPrinterService {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Hiển thị hộp thoại xem trước và in hóa đơn (Thermal 58mm / 80mm preview)
  static void showReceiptPreview({
    required BuildContext context,
    required Map<String, dynamic> order,
    VietQrModel? vietQr,
    bool isPreCheckBill = false,
    bool isDuplicate = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiptPreviewSheet(
        order: order,
        vietQr: vietQr,
        isPreCheckBill: isPreCheckBill,
        isDuplicate: isDuplicate,
      ),
    );
  }
}

class _ReceiptPreviewSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final VietQrModel? vietQr;
  final bool isPreCheckBill;
  final bool isDuplicate;

  const _ReceiptPreviewSheet({
    required this.order,
    this.vietQr,
    required this.isPreCheckBill,
    this.isDuplicate = false,
  });

  @override
  State<_ReceiptPreviewSheet> createState() => _ReceiptPreviewSheetState();
}

class _ReceiptPreviewSheetState extends State<_ReceiptPreviewSheet> {
  int _paperWidthMm = 80;

  String _formatCurrency(num? amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderCode = (order['orderCode'] ?? order['order_code'] ?? 'ORD-000').toString();
    final tableName = (order['tableName'] ?? order['table_name'] ?? 'Mang về').toString();
    final customerName = (order['customerName'] ?? order['customer_name'] ?? 'Khách lẻ').toString();
    final creatorName = (order['creatorName'] ?? order['cashierName'] ?? 'Thu ngân').toString();
    final createdAtStr = order['createdAt'] ?? order['created_at'];
    final createdAt = createdAtStr != null ? (DateTime.tryParse(createdAtStr.toString()) ?? DateTime.now()) : DateTime.now();

    final rawDetails = (order['details'] as List? ?? order['items'] as List? ?? []);
    final details = rawDetails.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final subtotal = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final discount = (order['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final finalAmount = (order['finalAmount'] as num?)?.toDouble() ?? (subtotal - discount);

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      widget.isPreCheckBill ? Icons.receipt_long : Icons.print_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isPreCheckBill ? 'Phiếu Tạm Tính' : 'Hóa Đơn Thanh Toán',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [_buildWidthButton(58), _buildWidthButton(80)],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF334155)),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Center(
                    child: Container(
                      width: _paperWidthMm == 58 ? 310 : 400,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'MODERN ARTISAN BISTRO',
                            style: TextStyle(fontFamily: 'Courier', fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '123 Phố Ẩm Thực, Quận 1, TP. Hồ Chí Minh\nHotline: 0901.234.567',
                            style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isPreCheckBill ? '*** PHIẾU TẠM TÍNH ***' : '*** HÓA ĐƠN THANH TOÁN ***',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.isPreCheckBill ? const Color(0xFFD97706) : Colors.black,
                            ),
                          ),
                          if (widget.isDuplicate) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '[BẢN IN LẠI / DUPLICATE]',
                                style: TextStyle(fontFamily: 'Courier', fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _buildReceiptRow('Số HĐ:', orderCode),
                          _buildReceiptRow('Bàn ăn:', tableName),
                          _buildReceiptRow('Khách hàng:', customerName),
                          _buildReceiptRow('Nhân viên:', creatorName),
                          _buildReceiptRow('Thời gian:', ReceiptPrinterService._dateFormat.format(createdAt)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('-----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontFamily: 'Courier', color: Colors.black54)),
                          ),
                          const Row(
                            children: [
                              Expanded(flex: 5, child: Text('Tên món', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('SL', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 3, child: Text('Đơn giá', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 4, child: Text('T.Tiền', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('-----------------------------------------', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontFamily: 'Courier', color: Colors.black54)),
                          ),
                          ...details.where((d) => d['cookingStatus'] != 4).map((d) {
                            final name = d['productName'] ?? d['product_name'] ?? 'Món ăn';
                            final qty = d['quantity'] ?? 1;
                            final price = (d['unitPrice'] as num? ?? d['price'] as num? ?? 0).toDouble();
                            final sub = (d['subTotal'] as num? ?? price * (qty as num)).toDouble();
                            final note = d['itemNote'] ?? d['note'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(flex: 5, child: Text(name.toString(), style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.w600))),
                                      Expanded(flex: 2, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Courier', fontSize: 12))),
                                      Expanded(flex: 3, child: Text(_formatCurrency(price), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Courier', fontSize: 11))),
                                      Expanded(flex: 4, child: Text(_formatCurrency(sub), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                  if (note != null && note.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, top: 1),
                                      child: Text('  * $note', style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54)),
                                    ),
                                ],
                              ),
                            );
                          }),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('=========================================', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontFamily: 'Courier', color: Colors.black54)),
                          ),
                          _buildReceiptRow('Tổng tiền hàng:', _formatCurrency(subtotal)),
                          if (discount > 0) _buildReceiptRow('Chiết khấu / Giảm giá:', '-${_formatCurrency(discount)}', isHighlight: true),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('THANH TOÁN:', style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(_formatCurrency(finalAmount), style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                            ],
                          ),
                          if (widget.vietQr != null && widget.vietQr!.qrImageUrl.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'VietQR (${widget.vietQr!.bankName} • ${widget.vietQr!.accountNo})',
                                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Image.network(
                                    widget.vietQr!.qrImageUrl,
                                    width: 150,
                                    height: 150,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 150,
                                      height: 150,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(child: Icon(Icons.qr_code_2_rounded, size: 70, color: Color(0xFF0F172A))),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Số tiền: ${_formatCurrency(widget.vietQr!.amount)} • ${widget.vietQr!.description}',
                                    style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text(
                            'CẢM ƠN QUÝ KHÁCH VÀ HẸN GẶP LẠI!\nRestaurant & Cafe POS System',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1E293B),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF475569)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Đóng'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: Text('In LAN ($_paperWidthMm mm)', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final currentCfg = await EscPosPrinterService.loadConfig();
                            await EscPosPrinterService.saveConfig(EscPosPrinterConfig(
                              host: currentCfg.host,
                              port: currentCfg.port,
                              paperWidthMm: _paperWidthMm,
                            ));
                            final printRes = await EscPosPrinterService.printOrderOverLan(
                              order,
                              isPreCheck: widget.isPreCheckBill,
                              isDuplicate: widget.isDuplicate,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(printRes['message']?.toString() ?? 'Đã gửi lệnh in $_paperWidthMm mm cho hóa đơn $orderCode!'),
                                backgroundColor: printRes['success'] == true
                                    ? const Color(0xFF059669)
                                    : (printRes['isWebFallback'] == true ? const Color(0xFF0284C7) : const Color(0xFFD97706)),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${mm}mm',
          style: TextStyle(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5),
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? const Color(0xFF059669) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

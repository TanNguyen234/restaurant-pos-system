import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dining_table.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/table_repository.dart';
import '../../utils/database_helper.dart';
import 'order_detail_page.dart';

class OrderCheckoutPage extends StatefulWidget {
  final int? preSelectedTableId;
  final String? preSelectedTableName;

  const OrderCheckoutPage({
    super.key,
    this.preSelectedTableId,
    this.preSelectedTableName,
  });

  @override
  State<OrderCheckoutPage> createState() => _OrderCheckoutPageState();
}

class _OrderCheckoutPageState extends State<OrderCheckoutPage> {
  final _customerNameController = TextEditingController(text: 'Khách lẻ');
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  final _orderRepo = OrderRepository();
  final _dbHelper = DatabaseHelper();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<DiningTable> _tables = [];
  int? _selectedTableId;
  String _selectedPaymentMethod = 'VietQR'; // 'Cash', 'VietQR', 'VNPay'
  int _orderType = 1; // 1: Tại bàn, 2: Mang về

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTableId = widget.preSelectedTableId;
    _initData();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    final tables = await TableRepository.getAllTables();
    final cart = await _dbHelper.getCartItems();

    final activeCart = List<Map<String, dynamic>>.from(cart);

    if (!mounted) return;

    setState(() {
      _tables = tables;
      _cartItems = activeCart;
      if (_selectedTableId == null && tables.isNotEmpty) {
        _selectedTableId = tables.first.id;
      }
      _isLoading = false;
    });
  }

  double get _subtotal {
    return _cartItems.fold<double>(
      0.0,
      (sum, item) => sum + ((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toDouble(),
    );
  }

  double get _discount => 0; // Có thể mở rộng voucher
  double get _finalAmount => _subtotal - _discount;

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 món ăn trước khi đặt')),
      );
      return;
    }

    if (_orderType == 1 && _selectedTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn bàn phục vụ')));
      return;
    }
    if (_cartItems.any((item) => (item['product_id'] ?? item['productId']) is! int || ((item['product_id'] ?? item['productId']) as int) <= 0 || (item['quantity'] as num? ?? 0) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giỏ hàng chứa món không hợp lệ, vui lòng cập nhật lại')));
      return;
    }
    setState(() => _isSubmitting = true);

    // Chuẩn bị payload tạo đơn
    final itemsPayload = _cartItems.map((item) {
      return {
        'productId': item['product_id'] ?? item['productId'],
        'quantity': item['quantity'] ?? 1,
        'unitPrice': (item['price'] as num? ?? 0).toDouble(),
        'itemNote': item['note'],
      };
    }).toList();

    final orderData = {
      'tableId': _orderType == 1 ? _selectedTableId : null,
      'customerName': _customerNameController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'orderType': _orderType,
      'note': _noteController.text.trim(),
      'totalAmount': _subtotal,
      'discountAmount': _discount,
      'finalAmount': _finalAmount,
      'items': itemsPayload,
    };

    final result = await _orderRepo.createOrder(orderData);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      final bool isOffline = result['isOffline'] == true;
      final int? orderId = result['orderId'] as int?;
      await _dbHelper.clearCart();
      if (!mounted) return;
      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đơn đã lưu ngoại tuyến, sẽ được đồng bộ khi có kết nối. Chưa thể thanh toán cho đến khi server xác nhận.')));
        Navigator.pop(context);
        return;
      }
      if (orderId == null || orderId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máy chủ trả về đơn không hợp lệ; vui lòng kiểm tra danh sách đơn.')));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đặt hàng thành công!'),
          backgroundColor: isOffline ? const Color(0xFFD97706) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Chuyển sang màn hình Chi Tiết Đơn Hàng & VietQR
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            orderId: orderId,
            initialPaymentMethod: _selectedPaymentMethod,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đặt hàng thất bại'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Xác nhận đặt món & Thanh toán'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Loại đơn hàng (Tại bàn / Mang về)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hình thức phục vụ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Dùng tại bàn')),
                                  selected: _orderType == 1,
                                  onSelected: (val) {
                                    if (val) setState(() => _orderType = 1);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Mang về (Takeaway)')),
                                  selected: _orderType == 2,
                                  onSelected: (val) {
                                    if (val) setState(() => _orderType = 2);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_orderType == 1) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _selectedTableId,
                              decoration: InputDecoration(
                                labelText: 'Chọn bàn phục vụ',
                                prefixIcon: const Icon(Icons.table_restaurant_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _tables.map((t) {
                                return DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text('${t.name} (Sức chứa: ${t.capacity} chỗ)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedTableId = val);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thông tin khách hàng & Ghi chú
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin khách hàng & Ghi chú',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              labelText: 'Tên khách hàng',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại liên hệ (tùy chọn)',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              labelText: 'Ghi chú cho bếp / pha chế',
                              hintText: 'Ví dụ: Ít đường, không đá, mang đá riêng...',
                              prefixIcon: const Icon(Icons.edit_note_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Danh sách món đã chọn
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                              const Text(
                                'Món đã chọn',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_cartItems.length} món',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cartItems.length,
                            separatorBuilder: (_, _) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              final price = (item['price'] as num? ?? 0).toDouble();
                              final qty = item['quantity'] as int? ?? 1;
                              final sub = price * qty;

                              return Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['product_name'] ?? item['productName'] ?? 'Món ăn',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${currencyFormatter.format(price)} x $qty',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(sub),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng cộng thanh toán:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                currencyFormatter.format(_finalAmount),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phương thức thanh toán
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phương thức thanh toán',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentOption(
                            value: 'VietQR',
                            title: 'Chuyển khoản VietQR (NAPAS 247)',
                            subtitle: 'Quét mã QR động chuyển tiền tức thì từ mọi App ngân hàng',
                            icon: Icons.qr_code_2_rounded,
                            iconColor: const Color(0xFF0284C7),
                          ),
                          const SizedBox(height: 8),
                          _buildPaymentOption(
                            value: 'Cash',
                            title: 'Tiền mặt (Cash)',
                            subtitle: 'Khách trả tiền mặt trực tiếp cho phục vụ / quầy thu ngân',
                            icon: Icons.money_rounded,
                            iconColor: const Color(0xFF059669),
                          ),
                          const SizedBox(height: 8),
                          _buildPaymentOption(
                            value: 'VNPay',
                            title: 'Cổng thanh toán VNPay Sandbox',
                            subtitle: 'Thanh toán qua ví VNPay / thẻ ATM nội địa',
                            icon: Icons.credit_card_rounded,
                            iconColor: const Color(0xFFEA580C),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nút Xác nhận đặt đơn
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: _isSubmitting ? null : _submitOrder,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Đang gửi đơn...'
                          : 'Xác Nhận Đặt Món (${currencyFormatter.format(_finalAmount)})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? iconColor : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

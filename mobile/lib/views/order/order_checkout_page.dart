import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../models/dining_table.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/table_repository.dart';
import '../../services/qr_table_session.dart';
import '../../services/session_manager.dart';
import '../../utils/database_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/skeleton_loading.dart';
import 'order_detail_page.dart';

class OrderCheckoutPage extends StatefulWidget {
  final int? preSelectedTableId;
  final String? preSelectedTableName;
  final String? initialDiscountCode;

  const OrderCheckoutPage({
    super.key,
    this.preSelectedTableId,
    this.preSelectedTableName,
    this.initialDiscountCode,
  });

  @override
  State<OrderCheckoutPage> createState() => _OrderCheckoutPageState();
}

class _OrderCheckoutPageState extends State<OrderCheckoutPage> {
  final _customerNameController = TextEditingController(text: 'Khách lẻ');
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _voucherController = TextEditingController();

  final _orderRepo = OrderRepository();
  final _dbHelper = DatabaseHelper();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<DiningTable> _tables = [];
  int? _selectedTableId;
  String _selectedPaymentMethod = 'VietQR';
  int _orderType = 1; // 1: Tại bàn, 2: Mang về, 3: Giao hàng

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  String? _appliedDiscountCode;
  double _discountAmount = 0.0;
  bool _isValidatingVoucher = false;
  List<Map<String, dynamic>> _availableDiscounts = [];
  Map<String, int> _ownedVoucherCounts = {};
  bool _isLoadingDiscounts = false;

  @override
  void initState() {
    super.initState();
    final user = SessionManager.instance.currentUser;
    if (user != null) {
      if (user.fullName.trim().isNotEmpty) {
        _customerNameController.text = user.fullName.trim();
      }
      if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
        _phoneController.text = user.phoneNumber!.trim();
      }
    }
    _selectedTableId = widget.preSelectedTableId ?? QrTableSession.instance.activeTableId;
    if (widget.initialDiscountCode != null && widget.initialDiscountCode!.isNotEmpty) {
      _voucherController.text = widget.initialDiscountCode!;
    }
    _initData();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _isLoadingDiscounts = true;
    });
    try {
      List<DiningTable> tables = [];
      try {
        tables = await TableRepository.getAllTables();
      } catch (_) {}

      final cart = await _dbHelper.getCartItems();
      List<Map<String, dynamic>> discounts = [];
      Map<String, int> ownedCounts = {};
      try {
        final res = await ApiConfig.get(Uri.parse('${ApiConfig.baseUrl}/api/discount/active'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          final rawList = decoded is List
              ? decoded
              : (decoded is Map ? (decoded['data'] ?? decoded['items'] ?? []) : []);
          if (decoded is Map && decoded['ownedCounts'] is Map) {
            (decoded['ownedCounts'] as Map).forEach((k, v) {
              ownedCounts[k.toString().toUpperCase()] = (v as num?)?.toInt() ?? 0;
            });
          }
          if (rawList is List) {
            discounts = rawList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {}

      if (!mounted) return;

      final emptyTable = tables.where((t) => t.status == 0).toList();
      setState(() {
        _tables = tables;
        _cartItems = List<Map<String, dynamic>>.from(cart);
        _availableDiscounts = discounts;
        _ownedVoucherCounts = ownedCounts;
        _isLoadingDiscounts = false;
        if (_selectedTableId == null && tables.isNotEmpty) {
          _selectedTableId = (emptyTable.isNotEmpty ? emptyTable.first : tables.first).id;
        }
        _isLoading = false;
      });

      if (widget.initialDiscountCode != null &&
          widget.initialDiscountCode!.trim().isNotEmpty &&
          _cartItems.isNotEmpty) {
        await _applyVoucher(codeOverride: widget.initialDiscountCode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingDiscounts = false;
        _loadError = 'Không thể khởi tạo dữ liệu đặt món: $e';
      });
    }
  }

  double get _subtotal => _cartItems.fold<double>(
        0.0,
        (sum, item) => sum + ((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toDouble(),
      );

  double get _discount => _discountAmount;
  double get _finalAmount => (_subtotal - _discount) < 0 ? 0.0 : (_subtotal - _discount);

  ({bool eligible, bool needsRedeem, int pointsCost, double missingAmount, double estimatedSavings}) _computeVoucherPreview(
    Map<String, dynamic> d,
  ) {
    final code = (d['code'] ?? '').toString().trim().toUpperCase();
    final minOrder = (d['minOrderAmount'] as num?)?.toDouble() ?? 0.0;
    final pct = (d['discountPercent'] as num?)?.toDouble() ?? 0.0;
    final amt = (d['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final maxDisc = (d['maxDiscountAmount'] as num?)?.toDouble() ?? 0.0;
    final pointsCost = (d['pointsCost'] as num?)?.toInt() ?? 0;

    final owned = _ownedVoucherCounts[code] ?? 0;
    final needsRedeem = pointsCost > 0 && owned <= 0;
    final eligible = !needsRedeem && _subtotal >= minOrder;
    final missing = minOrder > _subtotal ? (minOrder - _subtotal) : 0.0;
    double est = pct > 0 ? (_subtotal * pct / 100.0) : amt;
    if (maxDisc > 0 && est > maxDisc) est = maxDisc;
    if (est > _subtotal) est = _subtotal;
    return (eligible: eligible, needsRedeem: needsRedeem, pointsCost: pointsCost, missingAmount: missing, estimatedSavings: est);
  }

  void _clearAppliedVoucher() {
    setState(() {
      _appliedDiscountCode = null;
      _discountAmount = 0.0;
      _voucherController.clear();
    });
  }

  Future<void> _applyVoucher({String? codeOverride}) async {
    final code = (codeOverride ?? _voucherController.text).trim().toUpperCase();
    if (code.isEmpty) return;
    _voucherController.text = code;

    setState(() => _isValidatingVoucher = true);
    try {
      final res = await ApiConfig.post(
        Uri.parse('${ApiConfig.baseUrl}/api/discount/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'orderAmount': _subtotal}),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;

      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _appliedDiscountCode = code;
          _discountAmount = (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
          _isValidatingVoucher = false;
        });
        showAutoDismissSnackBar(
          context,
          message: 'Áp dụng mã "$code" thành công! Giảm ${currencyFormatter.format(_discountAmount)}',
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF059669),
        );
      } else {
        setState(() {
          _appliedDiscountCode = null;
          _discountAmount = 0.0;
          _isValidatingVoucher = false;
        });
        showAutoDismissSnackBar(
          context,
          message: data['message']?.toString() ?? 'Mã giảm giá không hợp lệ hoặc chưa đạt điều kiện',
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFDC2626),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidatingVoucher = false);
      showAutoDismissSnackBar(
        context,
        message: 'Không thể kiểm tra mã giảm giá với máy chủ: $e',
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFFDC2626),
      );
    }
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    if (_cartItems.isEmpty) {
      showAutoDismissSnackBar(
        context,
        message: 'Vui lòng chọn ít nhất 1 món ăn trước khi đặt',
      );
      return;
    }

    if (_orderType == 1 && _selectedTableId == null) {
      showAutoDismissSnackBar(context, message: 'Vui lòng chọn bàn phục vụ');
      return;
    }

    if (_orderType == 3 && _addressController.text.trim().isEmpty) {
      showAutoDismissSnackBar(context, message: 'Vui lòng nhập địa chỉ giao hàng');
      return;
    }

    if (_cartItems.any((item) =>
        (item['product_id'] ?? item['productId']) is! int ||
        ((item['product_id'] ?? item['productId']) as int) <= 0 ||
        (item['quantity'] as num? ?? 0) <= 0)) {
      showAutoDismissSnackBar(
        context,
        message: 'Giỏ hàng chứa món không hợp lệ, vui lòng kiểm tra lại',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final itemsPayload = _cartItems.map((item) {
        List<dynamic> modifiersList = [];
        if (item['modifiers_json'] != null) {
          try {
            modifiersList = jsonDecode(item['modifiers_json'].toString()) as List;
          } catch (_) {}
        }
        return {
          'productId': item['product_id'] ?? item['productId'],
          'quantity': item['quantity'] ?? 1,
          'unitPrice': (item['price'] as num? ?? 0).toDouble(),
          'itemNote': item['note'],
          'modifiers': modifiersList,
        };
      }).toList();

      String composedNote = _noteController.text.trim();
      if (_orderType == 3 && _addressController.text.trim().isNotEmpty) {
        final addr = 'Giao tới: ${_addressController.text.trim()}';
        composedNote = composedNote.isEmpty ? addr : '$addr | $composedNote';
      }

      final orderData = {
        'tableId': _orderType == 1 ? _selectedTableId : null,
        'customerName': _customerNameController.text.trim().isEmpty ? 'Khách lẻ' : _customerNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'orderType': _orderType,
        'note': composedNote.isEmpty ? null : composedNote,
        'discountCode': _appliedDiscountCode,
        'totalAmount': _subtotal,
        'discountAmount': _discount,
        'finalAmount': _finalAmount,
        'items': itemsPayload,
      };

      final bool useQrSelfOrder = QrTableSession.instance.isQrOrderMode && !SessionManager.instance.isStaff;
      final result = useQrSelfOrder
          ? await _orderRepo.createQrSelfOrder(orderData)
          : await _orderRepo.createOrder(orderData);
      if (!mounted) return;

      if (result['success'] == true) {
        final bool isOffline = result['isOffline'] == true;
        final int? orderId = result['orderId'] as int?;
        if (!isOffline && (orderId == null || orderId <= 0)) {
          showAutoDismissSnackBar(
            context,
            message: 'Máy chủ trả về đơn không hợp lệ; kiểm tra danh sách đơn trước khi đặt lại.',
          );
          return;
        }
        await _dbHelper.clearCart();
        if (!mounted) return;
        if (isOffline) {
          showAutoDismissSnackBar(
            context,
            message: result['message']?.toString() ?? 'Đơn đã lưu ngoại tuyến, sẽ đồng bộ khi có mạng.',
            backgroundColor: const Color(0xFFD97706),
          );
          Navigator.pop(context);
          return;
        }
        showAutoDismissSnackBar(
          context,
          message: result['message']?.toString() ?? 'Đặt hàng thành công!',
          backgroundColor: const Color(0xFF059669),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(orderId: orderId!, initialPaymentMethod: _selectedPaymentMethod),
          ),
        );
      } else {
        showAutoDismissSnackBar(
          context,
          message: result['message']?.toString() ?? 'Đặt hàng thất bại',
          backgroundColor: const Color(0xFFDC2626),
        );
      }
    } catch (e) {
      if (mounted) {
        showAutoDismissSnackBar(
          context,
          message: 'Lỗi gửi đơn hàng: $e',
          backgroundColor: const Color(0xFFDC2626),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Xác nhận đặt món & Thanh toán'), elevation: 0),
      body: _isLoading
          ? const SkeletonListPlaceholder(itemCount: 4)
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, style: const TextStyle(color: Color(0xFFDC2626))),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _initData, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _cartItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 64, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            const Text('Giỏ hàng hiện đang trống', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Vui lòng thêm món từ Thực đơn trước khi đặt đơn.', style: TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Quay lại chọn món'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                      const Text('Hình thức phục vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ChoiceChip(
                                            label: const Text('Dùng tại bàn'),
                                            selected: _orderType == 1,
                                            onSelected: (v) {
                                              if (v) setState(() => _orderType = 1);
                                            },
                                          ),
                                          ChoiceChip(
                                            label: const Text('Mang về'),
                                            selected: _orderType == 2,
                                            onSelected: (v) {
                                              if (v) setState(() => _orderType = 2);
                                            },
                                          ),
                                          ChoiceChip(
                                            label: const Text('Giao hàng'),
                                            selected: _orderType == 3,
                                            onSelected: (v) {
                                              if (v) setState(() => _orderType = 3);
                                            },
                                          ),
                                        ],
                                      ),
                                      if (_orderType == 1) ...[
                                        const SizedBox(height: 14),
                                        if (_tables.isEmpty)
                                          const Text('Chưa tải được danh sách bàn (vẫn có thể chọn Mang về).', style: TextStyle(color: Color(0xFFD97706), fontSize: 13))
                                        else
                                          DropdownButtonFormField<int>(
                                            isExpanded: true,
                                            initialValue: _tables.any((t) => t.id == _selectedTableId) ? _selectedTableId : _tables.first.id,
                                            decoration: InputDecoration(
                                              labelText: 'Chọn bàn phục vụ',
                                              prefixIcon: const Icon(Icons.table_restaurant_outlined),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            items: _tables
                                                .map((t) => DropdownMenuItem<int>(
                                                      value: t.id,
                                                      child: Text('${t.name} (${t.capacity} chỗ • ${t.statusText})'),
                                                    ))
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null) setState(() => _selectedTableId = val);
                                            },
                                          ),
                                      ],
                                      if (_orderType == 3) ...[
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _addressController,
                                          decoration: InputDecoration(
                                            labelText: 'Địa chỉ giao hàng *',
                                            prefixIcon: const Icon(Icons.location_on_outlined),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                      const Text('Thông tin khách hàng & Ghi chú', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                          const Text('Món đã chọn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          Text('${_cartItems.length} món', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                                child: Center(
                                                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      (item['product_name'] ?? item['productName'] ?? 'Món ăn').toString(),
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    Text('${currencyFormatter.format(price)} x $qty', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                                  ],
                                                ),
                                              ),
                                              Text(currencyFormatter.format(sub), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildAvailableVouchersSection(),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _voucherController,
                                              textCapitalization: TextCapitalization.characters,
                                              decoration: InputDecoration(
                                                hintText: 'Hoặc nhập mã giảm giá khác',
                                                prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F172A),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            ),
                                            onPressed: _isValidatingVoucher ? null : () => _applyVoucher(),
                                            child: _isValidatingVoucher
                                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                : const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      if (_discountAmount > 0) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Giảm giá (${_appliedDiscountCode ?? ""}):',
                                                style: const TextStyle(fontSize: 14, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            Text(
                                              '-${currencyFormatter.format(_discountAmount)}',
                                              style: const TextStyle(fontSize: 14, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: _clearAppliedVoucher,
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text('Bỏ mã', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Expanded(child: Text('Tổng cộng thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                          Text(
                                            currencyFormatter.format(_finalAmount),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                      const Text('Phương thức thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      _buildPaymentOption(
                                        value: 'VietQR',
                                        title: 'Chuyển khoản VietQR (NAPAS 247)',
                                        subtitle: 'Quét mã QR động chuyển tiền từ mọi App ngân hàng',
                                        icon: Icons.qr_code_2_rounded,
                                        iconColor: const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildPaymentOption(
                                        value: 'Cash',
                                        title: 'Tiền mặt (Cash)',
                                        subtitle: 'Thanh toán tiền mặt tại quầy thu ngân',
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
                              const SizedBox(height: 20),
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
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_circle_outline_rounded),
                                label: Text(
                                  _isSubmitting
                                      ? 'Đang gửi đơn...'
                                      : 'Xác Nhận Đặt Món (${currencyFormatter.format(_finalAmount)})',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildAvailableVouchersSection() {
    if (_isLoadingDiscounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_availableDiscounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<Map<String, dynamic>>.from(_availableDiscounts)
      ..sort((a, b) {
        final ea = _computeVoucherPreview(a).eligible ? 0 : 1;
        final eb = _computeVoucherPreview(b).eligible ? 0 : 1;
        if (ea != eb) return ea.compareTo(eb);
        return _computeVoucherPreview(b)
            .estimatedSavings
            .compareTo(_computeVoucherPreview(a).estimatedSavings);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.local_offer_rounded, size: 16, color: Color(0xFFD97706)),
            SizedBox(width: 6),
            Text(
              'Mã giảm giá có sẵn cho đơn này',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: sorted.map((d) {
            final code = (d['code'] ?? '').toString().trim().toUpperCase();
            final title = (d['title'] ?? code).toString();
            final pct = (d['discountPercent'] as num?)?.toDouble() ?? 0.0;
            final amt = (d['discountAmount'] as num?)?.toDouble() ?? 0.0;
            final minOrder = (d['minOrderAmount'] as num?)?.toDouble() ?? 0.0;
            final preview = _computeVoucherPreview(d);
            final isApplied = _appliedDiscountCode == code;

            final badgeText = pct > 0
                ? 'Giảm ${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%'
                : 'Giảm ${currencyFormatter.format(amt)}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isValidatingVoucher || !preview.eligible
                    ? null
                    : () {
                        if (isApplied) {
                          _clearAppliedVoucher();
                        } else {
                          _applyVoucher(codeOverride: code);
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isApplied
                        ? const Color(0xFFECFDF5)
                        : (preview.eligible ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isApplied
                          ? const Color(0xFF059669)
                          : (preview.eligible ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                      width: isApplied ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: preview.eligible ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: preview.eligible ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preview.needsRedeem
                                  ? '$badgeText • Cần đổi ${preview.pointsCost} PTS ở mục Hội viên'
                                  : preview.eligible
                                      ? '$badgeText • Tiết kiệm ${currencyFormatter.format(preview.estimatedSavings)}'
                                      : '$badgeText • Đơn tối thiểu ${currencyFormatter.format(minOrder)} (thiếu ${currencyFormatter.format(preview.missingAmount)})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: preview.eligible ? const Color(0xFF059669) : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isApplied
                            ? 'Đang dùng'
                            : (preview.needsRedeem
                                ? '${preview.pointsCost} PTS'
                                : (preview.eligible ? 'Dùng ngay' : 'Chưa đủ')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isApplied
                              ? const Color(0xFF059669)
                              : (preview.eligible ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
          border: Border.all(color: isSelected ? iconColor : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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

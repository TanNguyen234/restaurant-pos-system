import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../models/category.dart';
import '../../models/dining_table.dart';
import '../../models/product.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/table_repository.dart';
import '../../services/receipt_printer_service.dart';
import '../../widgets/skeleton_loading.dart';

class CashierPosTerminalPage extends StatefulWidget {
  final int? initialTableId;

  const CashierPosTerminalPage({super.key, this.initialTableId});

  @override
  State<CashierPosTerminalPage> createState() => _CashierPosTerminalPageState();
}

class _CashierPosTerminalPageState extends State<CashierPosTerminalPage> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  // Catalog State
  List<Category> _categories = [];
  List<Product> _products = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoadingCatalog = true;

  // Selected Table & Order State
  List<DiningTable> _tables = [];
  DiningTable? _selectedTable;
  Map<String, dynamic>? _activeOrder;

  // Local Bill Items for the terminal
  final List<Map<String, dynamic>> _billItems = [];

  // Cash Numpad & Quick Payment State
  double _customerCashTendered = 0.0;
  String _numpadBuffer = '';
  double _discountAmount = 0.0;
  double _discountPercent = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final cats = await CategoryRepository.getCategories() ?? [];
      final prodsResult = await ProductRepository.getProducts(page: 1, pageSize: 50);
      final allTables = await TableRepository.getAllTables();

      DiningTable? targetTable;
      if (widget.initialTableId != null) {
        targetTable = allTables.firstWhere((t) => t.id == widget.initialTableId, orElse: () => allTables.first);
      } else {
        targetTable = allTables.isNotEmpty ? allTables.first : null;
      }

      setState(() {
        _categories = cats;
        _products = prodsResult.data;
        _tables = allTables;
        _selectedTable = targetTable;
        _isLoadingCatalog = false;
      });

      if (targetTable != null) {
        await _fetchTableOrder(targetTable.id);
      }
    } catch (_) {
      setState(() => _isLoadingCatalog = false);
    }
  }

  Future<void> _fetchTableOrder(int tableId) async {
    final order = await TableRepository.getActiveOrderByTable(tableId);
    setState(() {
      _activeOrder = order;
      _billItems.clear();
      _numpadBuffer = '';
      _customerCashTendered = 0.0;

      if (order != null && order['details'] != null) {
        for (final d in (order['details'] as List)) {
          _billItems.add({
            'orderDetailId': d['orderDetailId'] ?? d['id'],
            'productId': d['productId'] ?? 0,
            'name': d['productName'] ?? 'Món ăn',
            'price': (d['price'] as num?)?.toDouble() ?? 0.0,
            'quantity': d['quantity'] ?? 1,
            'isExisting': true, // Already sent to kitchen
          });
        }
      }
    });
  }

  double get _subtotal {
    return _billItems.fold(0.0, (sum, item) => sum + ((item['price'] as double) * (item['quantity'] as int)));
  }

  double get _finalAmount {
    final net = _subtotal - _discountAmount;
    return net < 0 ? 0.0 : net;
  }

  double get _changeDue {
    final change = _customerCashTendered - _finalAmount;
    return change < 0 ? 0.0 : change;
  }

  void _addItemToBill(Product product) {
    setState(() {
      final existingIndex = _billItems.indexWhere((i) => i['productId'] == product.productId && i['isExisting'] != true);
      if (existingIndex != -1) {
        _billItems[existingIndex]['quantity'] = (_billItems[existingIndex]['quantity'] as int) + 1;
      } else {
        _billItems.add({
          'productId': product.productId,
          'name': product.productName,
          'price': product.price,
          'quantity': 1,
          'isExisting': false, // Newly added in this session
        });
      }
      _customerCashTendered = _finalAmount; // default to exact amount
    });
  }

  void _onNumpadPress(String key) {
    setState(() {
      if (key == 'C') {
        _numpadBuffer = '';
        _customerCashTendered = 0.0;
      } else if (key == '⌫') {
        if (_numpadBuffer.isNotEmpty) {
          _numpadBuffer = _numpadBuffer.substring(0, _numpadBuffer.length - 1);
          _customerCashTendered = double.tryParse(_numpadBuffer) ?? 0.0;
        }
      } else if (key == '000') {
        if (_numpadBuffer.isNotEmpty && _numpadBuffer.length <= 8) {
          _numpadBuffer += '000';
          _customerCashTendered = double.tryParse(_numpadBuffer) ?? 0.0;
        }
      } else {
        if (_numpadBuffer.length <= 9) {
          _numpadBuffer += key;
          _customerCashTendered = double.tryParse(_numpadBuffer) ?? 0.0;
        }
      }
    });
  }

  void _setExactCash() {
    setState(() {
      _customerCashTendered = _finalAmount;
      _numpadBuffer = _finalAmount.toInt().toString();
    });
  }

  void _setQuickCash(double amount) {
    setState(() {
      _customerCashTendered = amount;
      _numpadBuffer = amount.toInt().toString();
    });
  }


  void _showManualDiscountDialog() {
    double tempPercent = _discountPercent;
    final customAmountController = TextEditingController(
      text: _discountAmount > 0 ? _discountAmount.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.discount_outlined, color: Color(0xFFF59E0B), size: 22),
                SizedBox(width: 8),
                Text('Chiết Khấu Thủ Công (POS)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn mức chiết khấu phần trăm:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [0, 5, 10, 15, 20].map((pct) {
                    final isSel = tempPercent == pct.toDouble() && customAmountController.text.isEmpty;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text('$pct%', style: TextStyle(color: isSel ? const Color(0xFF0F172A) : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: isSel,
                          selectedColor: const Color(0xFFF59E0B),
                          backgroundColor: const Color(0xFF0F172A),
                          onSelected: (_) {
                            setDialogState(() {
                              tempPercent = pct.toDouble();
                              customAmountController.clear();
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Hoặc nhập số tiền giảm giá trực tiếp (VNĐ):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: customAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 30000',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      setDialogState(() => tempPercent = 0.0);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                ),
                onPressed: () {
                  final customAmt = double.tryParse(customAmountController.text.trim()) ?? 0.0;
                  setState(() {
                    if (customAmt > 0) {
                      _discountAmount = customAmt;
                      _discountPercent = 0.0;
                    } else if (tempPercent > 0) {
                      _discountPercent = tempPercent;
                      _discountAmount = _subtotal * (_discountPercent / 100);
                    } else {
                      _discountAmount = 0.0;
                      _discountPercent = 0.0;
                    }
                    _customerCashTendered = _finalAmount;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleReprintReceipt() {
    if (_billItems.isEmpty) return;
    ReceiptPrinterService.showReceiptPreview(
      context: context,
      isPreCheckBill: false,
      isDuplicate: true,
      order: {
        'orderCode': _activeOrder?['orderCode'] ?? 'ORD-REPRINT',
        'tableName': _selectedTable?.name ?? 'Mang về',
        'customerName': 'Khách in lại HĐ',
        'totalAmount': _subtotal,
        'discountAmount': _discountAmount,
        'finalAmount': _finalAmount,
        'details': _billItems.map((i) => {
          'productName': i['name'],
          'quantity': i['quantity'],
          'price': i['price'],
          'subTotal': (i['price'] as double) * (i['quantity'] as int),
        }).toList(),
      },
    );
  }

  void _showSplitPaymentModal() {
    if (_billItems.isEmpty) return;
    double cashPortion = _finalAmount > 50000 ? 50000.0 : _finalAmount / 2;
    double qrPortion = _finalAmount - cashPortion;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final qrUrl = 'https://img.vietqr.io/image/970422-0901234567-compact2.png?amount=${qrPortion.toInt()}&addInfo=SPLIT-${_selectedTable?.name ?? "POS"}&accountName=RESTAURANT_POS';

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.call_split_rounded, color: Color(0xFF38BDF8), size: 22),
                        SizedBox(width: 8),
                        Text('Thanh Toán Hỗn Hợp (Split Pay)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Tổng cần thanh toán: ${_currencyFormat.format(_finalAmount)}',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('1. Tiền mặt:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_currencyFormat.format(cashPortion), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('2. Chuyển khoản VietQR:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_currencyFormat.format(qrPortion), style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      qrUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2, size: 80, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _settleCashPayment();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã xác nhận thanh toán hỗn hợp thành công!'), backgroundColor: Color(0xFF059669)),
                      );
                    }
                  },
                  child: const Text('XÁC NHẬN THU ĐỦ TIỀN MẶT & VIETQR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitNewItemsToTable() async {
    if (_selectedTable == null) return;
    final newItems = _billItems.where((i) => i['isExisting'] != true).toList();
    if (newItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có món ăn mới nào để gửi thêm vào bàn!')),
      );
      return;
    }

    if (_activeOrder == null) {
      // Bàn chưa có đơn -> Tạo đơn mới
      final orderData = {
        'tableId': _selectedTable!.id,
        'customerName': 'Khách tại bàn ${_selectedTable!.name}',
        'orderType': 1,
        'totalAmount': _subtotal,
        'discountAmount': _discountAmount,
        'finalAmount': _finalAmount,
        'items': newItems.map((i) => {
          'productId': i['productId'],
          'quantity': i['quantity'],
          'unitPrice': i['price'],
        }).toList(),
      };
      final res = await OrderRepository().createOrder(orderData);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo đơn cho bàn ${_selectedTable!.name}!'), backgroundColor: const Color(0xFF059669)),
        );
        await _fetchTableOrder(_selectedTable!.id);
      }
    } else {
      // Đã có đơn -> Gửi thêm món vào đơn hiện tại
      final orderId = _activeOrder!['orderId'] ?? _activeOrder!['id'];
      final itemsPayload = newItems.map((i) => {
        'productId': i['productId'],
        'quantity': i['quantity'],
        'unitPrice': i['price'],
      }).toList();

      try {
        final res = await ApiConfig.post(
          Uri.parse('${ApiConfig.baseUrl}/api/order/$orderId/add-items'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'items': itemsPayload}),
        );
        if (!mounted) return;
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã gọi thêm ${newItems.length} món vào bàn ${_selectedTable!.name}!'), backgroundColor: const Color(0xFF059669)),
          );
          await _fetchTableOrder(_selectedTable!.id);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi gọi thêm món: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  Future<void> _settleCashPayment() async {
    if (_billItems.isEmpty) return;
    if (_customerCashTendered < _finalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số tiền khách đưa chưa đủ để thanh toán hóa đơn!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Hiển thị và in hóa đơn thanh toán
    ReceiptPrinterService.showReceiptPreview(
      context: context,
      isPreCheckBill: false,
      order: {
        'orderCode': _activeOrder?['orderCode'] ?? 'ORD-${DateTime.now().millisecondsSinceEpoch % 100000}',
        'tableName': _selectedTable?.name ?? 'Mang về',
        'customerName': 'Khách thanh toán POS',
        'totalAmount': _subtotal,
        'discountAmount': _discountAmount,
        'finalAmount': _finalAmount,
        'details': _billItems.map((i) => {
          'productName': i['name'],
          'quantity': i['quantity'],
          'price': i['price'],
          'subTotal': (i['price'] as double) * (i['quantity'] as int),
        }).toList(),
      },
    );

    // Giải phóng bàn nếu có
    if (_selectedTable != null) {
      await TableRepository.updateStatus(_selectedTable!.id, 0);
      await _fetchTableOrder(_selectedTable!.id);
    }
  }

  void _showPreCheckBill() {
    if (_billItems.isEmpty) return;
    ReceiptPrinterService.showReceiptPreview(
      context: context,
      isPreCheckBill: true,
      order: {
        'orderCode': _activeOrder?['orderCode'] ?? 'ORD-PRECHECK',
        'tableName': _selectedTable?.name ?? 'Mang về',
        'customerName': 'Khách in tạm tính',
        'totalAmount': _subtotal,
        'discountAmount': _discountAmount,
        'finalAmount': _finalAmount,
        'details': _billItems.map((i) => {
          'productName': i['name'],
          'quantity': i['quantity'],
          'price': i['price'],
          'subTotal': (i['price'] as double) * (i['quantity'] as int),
        }).toList(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final matchCat = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      final matchSearch = _searchQuery.isEmpty || p.productName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.point_of_sale_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text('POS Thu Ngân (Split-Screen Terminal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(width: 16),
            if (_selectedTable != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedTable!.status == 1 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Bàn: ${_selectedTable!.name} • ${_selectedTable!.status == 1 ? "Có khách" : "Trống"}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant_rounded),
            tooltip: 'Chọn bàn khác',
            onPressed: _showTablePickerModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Row(
        children: [
          // LEFT PANEL: Product Catalog Grid & Search (Flex 6)
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  // Search & Category Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    color: const Color(0xFF1E293B),
                    child: Column(
                      children: [
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm món ăn, đồ uống...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                        const SizedBox(height: 10),
                        // Category Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryPill(null, 'Tất cả'),
                              ..._categories.map((c) => _buildCategoryPill(c.id, c.name)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Products Grid
                  Expanded(
                    child: _isLoadingCatalog
                        ? const SkeletonGridPlaceholder(itemCount: 8)
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              mainAxisExtent: 130,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final p = filteredProducts[index];
                              return InkWell(
                                onTap: () => _addItemToBill(p),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        p.productName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _currencyFormat.format(p.price),
                                            style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT PANEL: Checkout Bill & Quick Numpad (Flex 5)
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFF1E293B),
              child: Column(
                children: [
                  // Bill Items Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFF0F172A),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('HÓA ĐƠN: ${_selectedTable?.name ?? "Bàn lẻ"}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${_billItems.length} món', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),

                  // Bill Item List
                  Expanded(
                    flex: 3,
                    child: _billItems.isEmpty
                        ? const Center(
                            child: Text('Chưa có món ăn nào trong hóa đơn\nChạm món bên trái để thêm',
                                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _billItems.length,
                            separatorBuilder: (_, _) => const Divider(color: Color(0xFF334155), height: 10),
                            itemBuilder: (context, index) {
                              final item = _billItems[index];
                              final isExisting = item['isExisting'] == true;
                              final sub = (item['price'] as double) * (item['quantity'] as int);

                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'].toString(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${_currencyFormat.format(item['price'])} ${isExisting ? "• [Đang phục vụ]" : "• [Mới thêm]"}',
                                          style: TextStyle(
                                            color: isExisting ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Qty Controls
                                  if (!isExisting) ...[
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white60),
                                      onPressed: () {
                                        setState(() {
                                          if ((item['quantity'] as int) > 1) {
                                            item['quantity'] = (item['quantity'] as int) - 1;
                                          } else {
                                            _billItems.removeAt(index);
                                          }
                                        });
                                      },
                                    ),
                                    Text('${item['quantity']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white60),
                                      onPressed: () => setState(() => item['quantity'] = (item['quantity'] as int) + 1),
                                    ),
                                  ] else ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('x${item['quantity']}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  Text(
                                    _currencyFormat.format(sub),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  const Divider(height: 1, color: Color(0xFF334155)),

                  // Summary & Cash Tendered Section (Flex 4)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF0F172A),
                    child: Column(
                      children: [
                        // Subtotal & Discount Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Chiết khấu:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _showManualDiscountDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFF59E0B)),
                                    ),
                                    child: Text(
                                      _discountAmount > 0 ? '-${_currencyFormat.format(_discountAmount)}' : '+ Thêm CK',
                                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _discountAmount > 0 ? '-${_currencyFormat.format(_discountAmount)}' : '0đ',
                              style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Totals Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tổng tiền thanh toán:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            Text(_currencyFormat.format(_finalAmount),
                                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 17)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Khách đưa / Tiền thối:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            Text(
                              'Đưa: ${_currencyFormat.format(_customerCashTendered)} | Thối: ${_currencyFormat.format(_changeDue)}',
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quick Cash Buttons
                        Row(
                          children: [
                            _buildQuickCashBtn('Đủ tiền', () => _setExactCash()),
                            const SizedBox(width: 6),
                            _buildQuickCashBtn('100k', () => _setQuickCash(100000)),
                            const SizedBox(width: 6),
                            _buildQuickCashBtn('200k', () => _setQuickCash(200000)),
                            const SizedBox(width: 6),
                            _buildQuickCashBtn('500k', () => _setQuickCash(500000)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Compact Numpad
                        _buildCompactNumpad(),
                        const SizedBox(height: 8),

                        // Extra quick buttons: In lại HĐ, Split Pay
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF94A3B8),
                                  side: const BorderSide(color: Color(0xFF334155)),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                                onPressed: _handleReprintReceipt,
                                child: const Text('In lại HĐ (Duplicate)', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                                onPressed: _showSplitPaymentModal,
                                child: const Text('Tách TT (Hỗn hợp)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Action Buttons: Send items, Precheck, Settle
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF475569)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: _showPreCheckBill,
                                child: const Text('In Tạm Tính', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (_billItems.any((i) => i['isExisting'] != true)) ...[
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: _submitNewItemsToTable,
                                  child: const Text('Gọi thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: _settleCashPayment,
                                child: const Text('THANH TOÁN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(int? catId, String title) {
    final isSelected = _selectedCategoryId == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title, style: TextStyle(color: isSelected ? const Color(0xFF0F172A) : Colors.white, fontSize: 12)),
        selected: isSelected,
        selectedColor: const Color(0xFFF59E0B),
        backgroundColor: const Color(0xFF0F172A),
        onSelected: (_) => setState(() => _selectedCategoryId = catId),
      ),
    );
  }

  Widget _buildQuickCashBtn(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF475569)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCompactNumpad() {
    return Column(
      children: [
        Row(
          children: [
            _buildNumKey('1'),
            const SizedBox(width: 6),
            _buildNumKey('2'),
            const SizedBox(width: 6),
            _buildNumKey('3'),
            const SizedBox(width: 6),
            _buildNumKey('C', color: const Color(0xFFDC2626)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildNumKey('4'),
            const SizedBox(width: 6),
            _buildNumKey('5'),
            const SizedBox(width: 6),
            _buildNumKey('6'),
            const SizedBox(width: 6),
            _buildNumKey('000'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildNumKey('7'),
            const SizedBox(width: 6),
            _buildNumKey('8'),
            const SizedBox(width: 6),
            _buildNumKey('9'),
            const SizedBox(width: 6),
            _buildNumKey('⌫', color: const Color(0xFFD97706)),
          ],
        ),
      ],
    );
  }

  Widget _buildNumKey(String label, {Color? color}) {
    return Expanded(
      child: InkWell(
        onTap: () => _onNumpadPress(label),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: color ?? const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
    );
  }

  void _showTablePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn Bàn Phục Vụ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.8, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _tables.length,
                itemBuilder: (context, i) {
                  final t = _tables[i];
                  final isOcc = t.status == 1;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedTable = t);
                      _fetchTableOrder(t.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isOcc ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(isOcc ? 'Có khách' : 'Trống', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

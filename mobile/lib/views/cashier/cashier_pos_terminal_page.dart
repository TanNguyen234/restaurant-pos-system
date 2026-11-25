import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category.dart';
import '../../models/dining_table.dart';
import '../../models/payment.dart';
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
  final _orderRepo = OrderRepository();

  List<Category> _categories = [];
  List<Product> _products = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoadingCatalog = true;
  String? _loadError;

  List<DiningTable> _tables = [];
  DiningTable? _selectedTable;
  Map<String, dynamic>? _activeOrder;

  final List<Map<String, dynamic>> _billItems = [];

  double _customerCashTendered = 0.0;
  String _numpadBuffer = '';
  double _discountAmount = 0.0;
  double _discountPercent = 0.0;
  double _alreadyPaidAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingCatalog = true;
      _loadError = null;
    });
    try {
      final cats = await CategoryRepository.getCategories() ?? [];
      final prodsResult = await ProductRepository.getProducts(page: 1, pageSize: 100);
      final allTables = await TableRepository.getAllTables();

      DiningTable? targetTable;
      if (widget.initialTableId != null && allTables.isNotEmpty) {
        targetTable = allTables.firstWhere((t) => t.id == widget.initialTableId, orElse: () => allTables.first);
      } else if (allTables.isNotEmpty) {
        final occupied = allTables.where((t) => t.status == 1).toList();
        targetTable = occupied.isNotEmpty ? occupied.first : allTables.first;
      }

      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCatalog = false;
        _loadError = 'Không thể tải dữ liệu POS Thu Ngân: $e';
      });
    }
  }

  Future<void> _fetchTableOrder(int tableId) async {
    final order = await TableRepository.getActiveOrderByTable(tableId);
    if (!mounted) return;
    setState(() {
      _activeOrder = order;
      _billItems.clear();
      _numpadBuffer = '';
      _customerCashTendered = 0.0;
      _discountPercent = 0.0;
      _discountAmount = (order?['discountAmount'] as num?)?.toDouble() ?? 0.0;
      _alreadyPaidAmount = (order?['paidAmount'] as num?)?.toDouble() ?? 0.0;

      if (order != null && order['details'] is List) {
        for (final raw in (order['details'] as List)) {
          final d = Map<String, dynamic>.from(raw as Map);
          if ((d['cookingStatus'] as num?)?.toInt() == 4) continue; // Bỏ qua món đã hủy
          _billItems.add({
            'orderDetailId': d['orderDetailId'] ?? d['id'],
            'productId': d['productId'] ?? 0,
            'name': d['productName'] ?? 'Món ăn',
            'price': (d['unitPrice'] ?? d['price'] as num?)?.toDouble() ?? 0.0,
            'quantity': (d['quantity'] as num?)?.toInt() ?? 1,
            'isExisting': true,
          });
        }
      }
    });
  }

  double get _subtotal => _billItems.fold(0.0, (sum, item) => sum + ((item['price'] as double) * (item['quantity'] as int)));

  double get _finalAmount {
    final net = _subtotal - _discountAmount;
    return net < 0 ? 0.0 : net;
  }

  double get _remainingAmount {
    final rem = _finalAmount - _alreadyPaidAmount;
    return rem < 0 ? 0.0 : rem;
  }

  double get _changeDue {
    final change = _customerCashTendered - _remainingAmount;
    return change < 0 ? 0.0 : change;
  }

  void _addItemToBill(Product product) {
    if (!product.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Món "${product.productName}" đang tạm hết!'), backgroundColor: const Color(0xFFDC2626)),
      );
      return;
    }

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
          'isExisting': false,
        });
      }
      _customerCashTendered = _remainingAmount;
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
        if (_numpadBuffer.isNotEmpty && _numpadBuffer.length <= 7) {
          _numpadBuffer += '000';
          _customerCashTendered = double.tryParse(_numpadBuffer) ?? 0.0;
        }
      } else if (key == '0') {
        if (_numpadBuffer.isNotEmpty && _numpadBuffer.length <= 9) {
          _numpadBuffer += '0';
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
      _customerCashTendered = _remainingAmount;
      _numpadBuffer = _remainingAmount.toInt().toString();
    });
  }

  void _setQuickCash(double amount) {
    setState(() {
      _customerCashTendered = amount;
      _numpadBuffer = amount.toInt().toString();
    });
  }

  Future<void> _showManualDiscountDialog() async {
    double tempPercent = _discountPercent;
    final customAmountController = TextEditingController(
      text: _discountAmount > 0 ? _discountAmount.toInt().toString() : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.discount_outlined, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Expanded(child: Text('Chiết Khấu Thủ Công (POS)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn mức chiết khấu %:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [0, 5, 10, 15, 20].map((pct) {
                  final isSel = tempPercent == pct.toDouble() && customAmountController.text.isEmpty;
                  return ChoiceChip(
                    label: Text('$pct%', style: TextStyle(color: isSel ? const Color(0xFF0F172A) : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (_) => setDialogState(() {
                      tempPercent = pct.toDouble();
                      customAmountController.clear();
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Hoặc nhập số tiền giảm trực tiếp (VNĐ):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
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
                  if (val.isNotEmpty) setDialogState(() => tempPercent = 0.0);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF0F172A)),
              onPressed: () async {
                final customAmt = double.tryParse(customAmountController.text.trim()) ?? 0.0;
                double nextAmount = 0.0;
                double nextPct = 0.0;
                if (customAmt > 0) {
                  nextAmount = customAmt > _subtotal ? _subtotal : customAmt;
                } else if (tempPercent > 0) {
                  nextPct = tempPercent;
                  nextAmount = _subtotal * (nextPct / 100);
                }

                Navigator.pop(ctx);
                if (_activeOrder != null) {
                  final orderId = _activeOrder!['orderId'] ?? _activeOrder!['id'];
                  if (orderId is int) {
                    final res = await _orderRepo.applyManualDiscount(
                      orderId: orderId,
                      discountPercent: nextPct > 0 ? nextPct : null,
                      discountAmount: nextPct > 0 ? null : nextAmount,
                      reason: 'Chiết khấu trực tiếp tại quầy POS',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message']?.toString() ?? 'Đã lưu chiết khấu'),
                          backgroundColor: res['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      );
                    }
                    if (_selectedTable != null && res['success'] == true) {
                      await _fetchTableOrder(_selectedTable!.id);
                      return;
                    }
                  }
                }
                setState(() {
                  _discountAmount = nextAmount;
                  _discountPercent = nextPct;
                  _customerCashTendered = _remainingAmount;
                });
              },
              child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
        'customerName': _activeOrder?['customerName'] ?? 'Khách lẻ',
        'totalAmount': _subtotal,
        'discountAmount': _discountAmount,
        'finalAmount': _finalAmount,
        'details': _billItems
            .map((i) => {
                  'productName': i['name'],
                  'quantity': i['quantity'],
                  'unitPrice': i['price'],
                  'subTotal': (i['price'] as double) * (i['quantity'] as int),
                })
            .toList(),
      },
    );
  }

  Future<int?> _ensureActiveOrderForPayment() async {
    if (_activeOrder != null) {
      final hasUnsent = _billItems.any((i) => i['isExisting'] != true);
      if (hasUnsent) {
        final ok = await _submitNewItemsToTable(silent: true);
        if (!ok) return null;
      }
      return (_activeOrder?['orderId'] ?? _activeOrder?['id']) as int?;
    }

    if (_billItems.isEmpty) return null;
    final res = await _orderRepo.createOrder({
      'tableId': _selectedTable?.id,
      'customerName': _selectedTable != null ? 'Khách tại ${_selectedTable!.name}' : 'Khách quầy POS',
      'orderType': _selectedTable != null ? 1 : 2,
      'items': _billItems
          .map((i) => {
                'productId': i['productId'],
                'quantity': i['quantity'],
                'unitPrice': i['price'],
              })
          .toList(),
    });
    if (res['success'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Không tạo được đơn hàng'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
      return null;
    }
    final newId = res['orderId'] as int?;
    if (_discountAmount > 0 && newId != null) {
      await _orderRepo.applyManualDiscount(
        orderId: newId,
        discountPercent: _discountPercent > 0 ? _discountPercent : null,
        discountAmount: _discountPercent > 0 ? null : _discountAmount,
      );
    }
    if (_selectedTable != null) {
      await _fetchTableOrder(_selectedTable!.id);
    }
    return newId;
  }

  Future<void> _showSplitPaymentModal() async {
    if (_billItems.isEmpty || _remainingAmount <= 0) return;
    final orderId = await _ensureActiveOrderForPayment();
    if (orderId == null || !mounted) return;

    double cashPortion = (_remainingAmount > 50000 ? 50000.0 : _remainingAmount / 2).roundToDouble();
    double qrPortion = (_remainingAmount - cashPortion).roundToDouble();
    VietQrModel? splitQr;
    try {
      splitQr = await _orderRepo.getVietQr(orderId, amount: qrPortion);
    } catch (_) {}
    if (!mounted) return;

    final cashCtrl = TextEditingController(text: cashPortion.toInt().toString());
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.call_split_rounded, color: Color(0xFF38BDF8), size: 22),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text('Thanh Toán Tách (Tiền mặt + VietQR)',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Cần thanh toán: ${_currencyFormat.format(_remainingAmount)}',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phần trả Tiền mặt (VNĐ)',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: TextButton(
                      onPressed: () async {
                        final parsed = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
                        cashPortion = parsed.clamp(0.0, _remainingAmount);
                        qrPortion = (_remainingAmount - cashPortion).clamp(0.0, _remainingAmount);
                        try {
                          splitQr = qrPortion > 0 ? await _orderRepo.getVietQr(orderId, amount: qrPortion) : null;
                        } catch (_) {}
                        setModalState(() {});
                      },
                      child: const Text('Cập nhật QR', style: TextStyle(color: Color(0xFF38BDF8))),
                    ),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim()) ?? 0.0;
                    setModalState(() {
                      cashPortion = parsed.clamp(0.0, _remainingAmount);
                      qrPortion = (_remainingAmount - cashPortion).clamp(0.0, _remainingAmount);
                    });
                  },
                ),
                const SizedBox(height: 12),
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
                            Text(_currencyFormat.format(cashPortion), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)),
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
                            const Text('2. VietQR còn lại:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_currencyFormat.format(qrPortion), style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (splitQr != null && qrPortion > 0) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        splitQr!.qrImageUrl,
                        width: 165,
                        height: 165,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(Icons.qr_code_2, size: 80, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          if (cashPortion > 0) {
                            final cRes = await _orderRepo.confirmPayment(
                              orderId: orderId,
                              paymentMethod: 'Cash',
                              amount: cashPortion,
                              note: 'Split Pay - Tiền mặt',
                            );
                            if (cRes['success'] != true) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(cRes['message'] ?? 'Lỗi thanh toán tiền mặt'), backgroundColor: const Color(0xFFDC2626)),
                                );
                              }
                              return;
                            }
                          }
                          if (qrPortion > 0) {
                            final qRes = await _orderRepo.confirmPayment(
                              orderId: orderId,
                              paymentMethod: 'VietQR',
                              amount: qrPortion,
                              note: 'Split Pay - Chuyển khoản VietQR',
                            );
                            if (qRes['success'] != true) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(qRes['message'] ?? 'Lỗi xác nhận VietQR'), backgroundColor: const Color(0xFFDC2626)),
                                );
                              }
                              return;
                            }
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (_selectedTable != null) {
                            await _loadInitialData();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thanh toán hỗn hợp thành công & đã giải phóng bàn!'), backgroundColor: Color(0xFF059669)),
                            );
                          }
                        },
                  child: Text(
                    isSubmitting ? 'Đang ghi nhận...' : 'XÁC NHẬN THU ĐỦ TIỀN MẶT & VIETQR',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _submitNewItemsToTable({bool silent = false}) async {
    if (_selectedTable == null) return false;
    final newItems = _billItems.where((i) => i['isExisting'] != true).toList();
    if (newItems.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có món mới nào để gửi!')));
      }
      return true;
    }

    final itemsPayload = newItems
        .map((i) => {
              'productId': i['productId'],
              'quantity': i['quantity'],
              'unitPrice': i['price'],
            })
        .toList();

    if (_activeOrder == null) {
      final res = await _orderRepo.createOrder({
        'tableId': _selectedTable!.id,
        'customerName': 'Khách tại bàn ${_selectedTable!.name}',
        'orderType': 1,
        'items': itemsPayload,
      });
      if (!mounted) return false;
      if (res['success'] == true) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã tạo đơn cho bàn ${_selectedTable!.name}!'), backgroundColor: const Color(0xFF059669)),
          );
        }
        await _fetchTableOrder(_selectedTable!.id);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Tạo đơn thất bại'), backgroundColor: const Color(0xFFDC2626)),
        );
        return false;
      }
    } else {
      final orderId = _activeOrder!['orderId'] ?? _activeOrder!['id'];
      if (orderId is! int) return false;
      final res = await _orderRepo.addItemsToOrder(orderId, itemsPayload);
      if (!mounted) return false;
      if (res['success'] == true) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã gọi thêm ${newItems.length} món vào bàn ${_selectedTable!.name}!'), backgroundColor: const Color(0xFF059669)),
          );
        }
        await _fetchTableOrder(_selectedTable!.id);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Lỗi gọi thêm món'), backgroundColor: const Color(0xFFDC2626)),
        );
        return false;
      }
    }
  }

  Future<void> _settleCashPayment() async {
    if (_billItems.isEmpty) return;
    if (_customerCashTendered < _remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền khách đưa chưa đủ để thanh toán hóa đơn!'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final orderId = await _ensureActiveOrderForPayment();
    if (orderId == null || !mounted) return;

    final res = await _orderRepo.confirmPayment(
      orderId: orderId,
      paymentMethod: 'Cash',
      amount: _remainingAmount,
      note: 'Thanh toán tiền mặt tại POS Thu Ngân (Khách đưa: ${_currencyFormat.format(_customerCashTendered)})',
    );
    if (!mounted) return;

    if (res['success'] == true) {
      final receiptSnapshot = {
        'orderCode': _activeOrder?['orderCode'] ?? 'ORD-$orderId',
        'tableName': _selectedTable?.name ?? 'Mang về',
        'customerName': _activeOrder?['customerName'] ?? 'Khách thanh toán POS',
        'totalAmount': _subtotal,
        'discountAmount': _discountAmount,
        'finalAmount': _finalAmount,
        'details': _billItems
            .map((i) => {
                  'productName': i['name'],
                  'quantity': i['quantity'],
                  'unitPrice': i['price'],
                  'subTotal': (i['price'] as double) * (i['quantity'] as int),
                })
            .toList(),
      };
      await _loadInitialData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Thanh toán thành công!'), backgroundColor: const Color(0xFF059669)),
      );
      ReceiptPrinterService.showReceiptPreview(context: context, isPreCheckBill: false, order: receiptSnapshot);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Thanh toán thất bại'), backgroundColor: const Color(0xFFDC2626)),
      );
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
        'details': _billItems
            .map((i) => {
                  'productName': i['name'],
                  'quantity': i['quantity'],
                  'unitPrice': i['price'],
                  'subTotal': (i['price'] as double) * (i['quantity'] as int),
                })
            .toList(),
      },
    );
  }

  Widget _buildCatalogPanel(List<Product> filteredProducts) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryPill(null, 'Tất cả'),
                      ..._categories.map((c) => _buildCategoryPill(c.id, c.name)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingCatalog
                ? const SkeletonGridPlaceholder(itemCount: 6)
                : _loadError != null && _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadInitialData, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 185,
                          mainAxisExtent: 158,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          final soldOut = !p.isAvailable;
                          return InkWell(
                            onTap: () => _addItemToBill(p),
                            borderRadius: BorderRadius.circular(12),
                            child: Opacity(
                              opacity: soldOut ? 0.6 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: soldOut ? const Color(0xFFDC2626) : const Color(0xFF334155)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                      child: SizedBox(
                                        height: 66,
                                        width: double.infinity,
                                        child: p.fullImageUrl.isNotEmpty
                                            ? Image.network(
                                                p.fullImageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => const Center(child: Icon(Icons.coffee, color: Color(0xFFF59E0B))),
                                              )
                                            : const Center(child: Icon(Icons.coffee, color: Color(0xFFF59E0B))),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              p.productName,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    soldOut ? 'HẾT MÓN' : _currencyFormat.format(p.price),
                                                    style: TextStyle(
                                                      color: soldOut ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11.5,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                                                  child: Icon(soldOut ? Icons.block : Icons.add, size: 15, color: Colors.white),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillPanel() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'HÓA ĐƠN: ${_selectedTable?.name ?? "Mang về"}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${_billItems.length} món', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: _billItems.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có món ăn nào trong hóa đơn\nChạm món để thêm hoặc chọn bàn đang phục vụ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
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
                                Text(item['name'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  '${_currencyFormat.format(item['price'])} ${isExisting ? "• [Đã gửi bếp]" : "• [Mới thêm]"}',
                                  style: TextStyle(color: isExisting ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
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
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('x${item['quantity']}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                            ),
                          Text(_currencyFormat.format(sub), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Chiết khấu:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _showManualDiscountDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cần thanh toán:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    Text(_currencyFormat.format(_remainingAmount), style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 17)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Đưa / Thối:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    Flexible(
                      child: Text(
                        'Đưa: ${_currencyFormat.format(_customerCashTendered)} | Thối: ${_currencyFormat.format(_changeDue)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildQuickCashBtn('Đủ tiền', _setExactCash),
                    const SizedBox(width: 6),
                    _buildQuickCashBtn('100k', () => _setQuickCash(100000)),
                    const SizedBox(width: 6),
                    _buildQuickCashBtn('200k', () => _setQuickCash(200000)),
                    const SizedBox(width: 6),
                    _buildQuickCashBtn('500k', () => _setQuickCash(500000)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCompactNumpad(),
                const SizedBox(height: 8),
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
                        child: const Text('In lại HĐ', style: TextStyle(fontSize: 11.5)),
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
                        child: const Text('Tách TT (Cash+QR)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                        child: const Text('Tạm tính', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_billItems.any((i) => i['isExisting'] != true)) ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                          onPressed: () => _submitNewItemsToTable(),
                          child: const Text('Gọi thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final matchCat = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      final matchSearch = _searchQuery.isEmpty || p.productName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                children: [
                  const Icon(Icons.point_of_sale_rounded, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  const Text('POS Thu Ngân (Split-Screen)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(width: 14),
                  if (_selectedTable != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedTable!.status == 1 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedTable!.name} • ${_selectedTable!.statusText}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.table_restaurant_rounded), tooltip: 'Chọn bàn khác', onPressed: _showTablePickerModal),
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadInitialData),
              ],
            ),
            body: Row(
              children: [
                Expanded(flex: 6, child: _buildCatalogPanel(filteredProducts)),
                Expanded(flex: 5, child: _buildBillPanel()),
              ],
            ),
          );
        }

        // Mobile / Narrow Tablet 2-tab POS Terminal
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(
                _selectedTable != null ? 'POS • ${_selectedTable!.name}' : 'POS Thu Ngân',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.table_restaurant_rounded), tooltip: 'Chọn bàn', onPressed: _showTablePickerModal),
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadInitialData),
              ],
              bottom: TabBar(
                labelColor: const Color(0xFFF59E0B),
                unselectedLabelColor: Colors.white70,
                indicatorColor: const Color(0xFFF59E0B),
                tabs: [
                  const Tab(text: 'Chọn món'),
                  Tab(text: 'Hóa đơn (${_billItems.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildCatalogPanel(filteredProducts),
                _buildBillPanel(),
              ],
            ),
          ),
        );
      },
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
        Row(children: [_buildNumKey('1'), const SizedBox(width: 6), _buildNumKey('2'), const SizedBox(width: 6), _buildNumKey('3'), const SizedBox(width: 6), _buildNumKey('C', color: const Color(0xFFDC2626))]),
        const SizedBox(height: 6),
        Row(children: [_buildNumKey('4'), const SizedBox(width: 6), _buildNumKey('5'), const SizedBox(width: 6), _buildNumKey('6'), const SizedBox(width: 6), _buildNumKey('000')]),
        const SizedBox(height: 6),
        Row(children: [_buildNumKey('7'), const SizedBox(width: 6), _buildNumKey('8'), const SizedBox(width: 6), _buildNumKey('9'), const SizedBox(width: 6), _buildNumKey('0'), const SizedBox(width: 6), _buildNumKey('⌫', color: const Color(0xFFD97706))]),
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
          decoration: BoxDecoration(color: color ?? const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5))),
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
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
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
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(t.statusText, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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

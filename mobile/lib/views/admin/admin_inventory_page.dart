import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/product_repository.dart';
import '../../services/realtime_service.dart';
import '../../widgets/skeleton_loading.dart';

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.##', 'vi_VN');
  final _currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Product> _products = [];
  int _lowStockCount = 0;
  bool _lowStockOnly = false;
  bool _isLoading = true;
  String? _error;

  Product? _selectedProduct;
  List<Map<String, dynamic>> _currentRecipes = [];
  bool _isLoadingRecipes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    PosRealtimeService.instance.ensureStarted();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final invRes = await InventoryRepository.getIngredients(
        search: _searchCtrl.text.trim(),
        lowStockOnly: _lowStockOnly,
      );
      final txRes = await InventoryRepository.getTransactions(limit: 80);
      final prodRes = await ProductRepository.getProducts(page: 1, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _ingredients = (invRes['data'] as List<Map<String, dynamic>>?) ?? [];
        _lowStockCount = (invRes['lowStockCount'] as int?) ?? 0;
        _transactions = txRes;
        _products = prodRes.data;
        if (_selectedProduct == null && _products.isNotEmpty) {
          _selectedProduct = _products.first;
        }
        _isLoading = false;
      });
      if (_selectedProduct != null) {
        await _loadRecipes(_selectedProduct!.productId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadRecipes(int productId) async {
    setState(() => _isLoadingRecipes = true);
    try {
      final list = await InventoryRepository.getRecipes(productId);
      if (!mounted) return;
      setState(() {
        _currentRecipes = list;
        _isLoadingRecipes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRecipes = false);
    }
  }

  Future<void> _showIngredientDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['ingredientName']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: existing?['unit']?.toString() ?? 'gram');
    final stockCtrl = TextEditingController(text: (existing?['currentStock'] ?? 0).toString());
    final minCtrl = TextEditingController(text: (existing?['minThreshold'] ?? 200).toString());
    final costCtrl = TextEditingController(text: (existing?['costPerUnit'] ?? 0).toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Thêm nguyên liệu kho' : 'Cập nhật nguyên liệu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên nguyên liệu *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Đơn vị (gram / ml / quả / cái)', border: OutlineInputBorder()),
              ),
              if (existing == null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tồn kho ban đầu', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ngưỡng cảnh báo sắp hết', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá vốn / đơn vị (đ)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final payload = {
                'ingredientName': nameCtrl.text.trim(),
                'unit': unitCtrl.text.trim().isEmpty ? 'gram' : unitCtrl.text.trim(),
                'currentStock': double.tryParse(stockCtrl.text.trim()) ?? 0,
                'minThreshold': double.tryParse(minCtrl.text.trim()) ?? 0,
                'costPerUnit': double.tryParse(costCtrl.text.trim()) ?? 0,
                'isActive': true,
              };
              final res = existing == null
                  ? await InventoryRepository.createIngredient(payload)
                  : await InventoryRepository.updateIngredient(existing['ingredientId'] as int, payload);
              if (!ctx.mounted) return;
              if (res['success'] == true) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(res['message']?.toString() ?? 'Lỗi lưu nguyên liệu'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok == true) _loadAll();
  }

  Future<void> _showAdjustDialog(Map<String, dynamic> ing) async {
    final qtyCtrl = TextEditingController(text: '500');
    final noteCtrl = TextEditingController();
    String mode = 'IMPORT';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Nhập / Điều chỉnh: ${ing['ingredientName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tồn hiện tại: ${_fmt.format(ing['currentStock'] ?? 0)} ${ing['unit']}'),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'IMPORT', label: Text('Nhập kho (+)')),
                  ButtonSegment(value: 'WASTE', label: Text('Hao hụt (-)')),
                ],
                selected: {mode},
                onSelectionChanged: (v) => setS(() => mode = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Số lượng (${ing['unit']})', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú phiếu kho', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                final rawVal = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (rawVal <= 0) return;
                final delta = mode == 'WASTE' ? -rawVal : rawVal;
                final res = await InventoryRepository.adjustStock(
                  ingredientId: ing['ingredientId'] as int,
                  changeAmount: delta,
                  type: mode,
                  note: noteCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                if (res['success'] == true) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(res['message']?.toString() ?? 'Lỗi điều chỉnh'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  Future<void> _showAddRecipeItemDialog() async {
    if (_selectedProduct == null || _ingredients.isEmpty) return;
    int selectedIngId = _ingredients.first['ingredientId'] as int;
    final qtyCtrl = TextEditingController(text: '25');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Thêm định lượng cho ${_selectedProduct!.productName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedIngId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nguyên liệu', border: OutlineInputBorder()),
                items: _ingredients
                    .map((i) => DropdownMenuItem<int>(
                          value: i['ingredientId'] as int,
                          child: Text('${i['ingredientName']} (${i['unit']})', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setS(() => selectedIngId = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Định lượng / 1 phần bán', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (q <= 0) return;
                final next = _currentRecipes
                    .where((r) => r['ingredientId'] != selectedIngId)
                    .map((r) => {'ingredientId': r['ingredientId'], 'quantityRequired': r['quantityRequired']})
                    .toList();
                next.add({'ingredientId': selectedIngId, 'quantityRequired': q});
                final res = await InventoryRepository.saveRecipes(_selectedProduct!.productId, next);
                if (!ctx.mounted) return;
                if (res['success'] == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Lưu công thức'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && _selectedProduct != null) {
      await _loadRecipes(_selectedProduct!.productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kho & Định lượng BOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Tồn kho nguyên liệu & trừ tự động theo đơn ($_lowStockCount sắp hết)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới', onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'Tồn kho'),
            Tab(text: 'Định lượng BOM'),
            Tab(text: 'Lịch sử kho'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 1 ? 'Thêm BOM' : 'Thêm nguyên liệu'),
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddRecipeItemDialog();
          } else {
            _showIngredientDialog();
          }
        },
      ),
      body: _isLoading
          ? const SkeletonListPlaceholder(itemCount: 5)
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStockTab(),
                    _buildRecipeTab(),
                    _buildTransactionsTab(),
                  ],
                ),
    );
  }

  Widget _buildStockTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tìm nguyên liệu...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _loadAll(),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Sắp hết ($_lowStockCount)'),
                selected: _lowStockOnly,
                selectedColor: const Color(0xFFFEF3C7),
                onSelected: (v) {
                  setState(() => _lowStockOnly = v);
                  _loadAll();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: _ingredients.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final ing = _ingredients[i];
              final stock = (ing['currentStock'] as num?)?.toDouble() ?? 0;
              final minT = (ing['minThreshold'] as num?)?.toDouble() ?? 0;
              final isLow = stock <= minT;
              final unit = (ing['unit'] ?? '').toString();
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isLow ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                    child: Icon(
                      isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                      color: isLow ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    ),
                  ),
                  title: Text(ing['ingredientName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Tồn: ${_fmt.format(stock)} $unit • Ngưỡng: ${_fmt.format(minT)} $unit • Vốn: ${_currencyFmt.format(ing['costPerUnit'] ?? 0)}',
                    style: TextStyle(fontSize: 12, color: isLow ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_box_outlined, color: Color(0xFF0284C7)),
                        tooltip: 'Nhập / Xuất kho',
                        onPressed: () => _showAdjustDialog(ing),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF475569)),
                        tooltip: 'Sửa thông tin',
                        onPressed: () => _showIngredientDialog(existing: ing),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeTab() {
    return Column(
      children: [
        if (_products.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<int>(
              initialValue: _selectedProduct?.productId ?? _products.first.productId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn món để cấu hình định lượng (BOM)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: _products
                  .map((p) => DropdownMenuItem<int>(
                        value: p.productId,
                        child: Text(p.productName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (pid) {
                if (pid == null) return;
                final prod = _products.firstWhere((p) => p.productId == pid);
                setState(() => _selectedProduct = prod);
                _loadRecipes(pid);
              },
            ),
          ),
        Expanded(
          child: _isLoadingRecipes
              ? const Center(child: CircularProgressIndicator())
              : _currentRecipes.isEmpty
                  ? const Center(child: Text('Món này chưa cấu hình định lượng BOM. Bấm "Thêm BOM" để gắn nguyên liệu.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _currentRecipes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final r = _currentRecipes[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.science_outlined, color: Color(0xFF7C3AED)),
                            title: Text(r['ingredientName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Định mức: ${_fmt.format(r['quantityRequired'] ?? 0)} ${r['unit']} / 1 phần • Kho còn: ${_fmt.format(r['currentStock'] ?? 0)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                              onPressed: () async {
                                final next = _currentRecipes
                                    .where((x) => x['ingredientId'] != r['ingredientId'])
                                    .map((x) => {'ingredientId': x['ingredientId'], 'quantityRequired': x['quantityRequired']})
                                    .toList();
                                if (_selectedProduct != null) {
                                  await InventoryRepository.saveRecipes(_selectedProduct!.productId, next);
                                  await _loadRecipes(_selectedProduct!.productId);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final tx = _transactions[i];
        final delta = (tx['changeAmount'] as num?)?.toDouble() ?? 0;
        final isPlus = delta >= 0;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            leading: Icon(
              isPlus ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isPlus ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
            title: Text('${tx['ingredientName']} (${isPlus ? '+' : ''}${_fmt.format(delta)} ${tx['unit']})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('[${tx['type']}] ${tx['note'] ?? ''}', style: const TextStyle(fontSize: 11.5)),
          ),
        );
      },
    );
  }
}

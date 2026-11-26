import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import '../services/qr_table_session.dart';
import '../services/session_manager.dart';
import '../utils/database_helper.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/skeleton_loading.dart';
import 'admin/admin_category_page.dart';
import 'admin/admin_product_page.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

class HomePage extends StatefulWidget {
  final int? initialCategoryId;
  const HomePage({super.key, this.initialCategoryId});

  /// Xây dựng payload giỏ hàng khi bấm thêm nhanh, tự động chọn option mặc định cho các nhóm bắt buộc.
  @visibleForTesting
  static Map<String, dynamic> buildQuickAddCartItem(Product product) {
    final requiredGroups = <String>{};
    if (product.attributes.isNotEmpty) {
      for (final a in product.attributes) {
        if (a.isRequired && a.attributeGroup.trim().isNotEmpty) {
          requiredGroups.add(a.attributeGroup);
        }
      }
    }

    final selected = <ProductAttribute>[];
    for (final group in requiredGroups) {
      final groupAttrs = product.attributes.where((a) => a.attributeGroup == group);
      if (groupAttrs.isNotEmpty) {
        selected.add(
          groupAttrs.reduce((a, b) => a.extraPrice <= b.extraPrice ? a : b),
        );
      }
    }

    final extraTotal = selected.fold<double>(0.0, (sum, a) => sum + a.extraPrice);
    final unitPrice = product.price + extraTotal;
    final modifiers = selected
        .map((a) => {
              'attributeId': a.attributeId,
              'modifierName': a.attributeName,
              'modifierGroup': a.attributeGroup,
              'extraPrice': a.extraPrice,
            })
        .toList();
    final note = selected.isNotEmpty ? selected.map((a) => a.attributeName).join(' • ') : null;

    return {
      'product_id': product.productId,
      'product_name': product.productName,
      'price': unitPrice,
      'quantity': 1,
      'image_url': product.imageUrl,
      'note': note,
      'modifiers_json': modifiers.isNotEmpty ? jsonEncode(modifiers) : null,
    };
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Category> _categories = [];
  int? _selectedCategoryId;

  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  bool _isLoading = true;
  bool _isLoadingFeatured = true;
  String? _errorMessage;

  int _currentPage = 1;
  final int _pageSize = 8;
  int _totalPages = 1;
  int _totalItems = 0;
  String _selectedSort = 'default';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _loadCategories();
    _loadFeaturedProducts();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await CategoryRepository.getCategories();
      if (!mounted) return;
      setState(() => _categories = cats ?? []);
    } catch (_) {}
  }

  Future<void> _loadFeaturedProducts() async {
    setState(() => _isLoadingFeatured = true);
    try {
      final featured = await ProductRepository.getFeaturedProducts(limit: 6);
      if (!mounted) return;
      setState(() {
        _featuredProducts = featured;
        _isLoadingFeatured = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFeatured = false);
    }
  }

  Future<void> _loadProducts({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ProductRepository.getProducts(
        categoryId: _selectedCategoryId,
        search: _searchController.text.trim(),
        page: page,
        pageSize: _pageSize,
        sortBy: _selectedSort == 'default' ? null : _selectedSort,
      );

      if (!mounted) return;
      setState(() {
        _products = result.data;
        _currentPage = result.page;
        _totalPages = result.totalPages > 0 ? result.totalPages : 1;
        _totalItems = result.totalItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách món ăn. Vui lòng thử lại.';
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _loadProducts(page: 1);
    });
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    _loadProducts(page: 1);
  }

  Future<void> _quickAddToCart(Product product) async {
    if (!product.isAvailable) {
      showAutoDismissSnackBar(
        context,
        message: 'Món "${product.productName}" hiện đã tạm hết!',
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    final cartItem = HomePage.buildQuickAddCartItem(product);
    await _dbHelper.insertOrUpdateCart(cartItem);

    if (!mounted) return;
    showAutoDismissSnackBar(
      context,
      message: 'Đã thêm 1 x "${product.productName}" vào giỏ',
      duration: const Duration(milliseconds: 2500),
      backgroundColor: const Color(0xFF0F172A),
      actionLabel: 'GIỎ HÀNG',
      onAction: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = SessionManager.instance.isManager;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restaurant & Cafe POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Thực đơn món ăn & Đồ uống F&B', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _dbHelper.cartCountNotifier,
            builder: (context, count, _) => IconButton(
              icon: count > 0
                  ? Badge(
                      label: Text('$count'),
                      backgroundColor: const Color(0xFFEF4444),
                      child: const Icon(Icons.shopping_cart_outlined),
                    )
                  : const Icon(Icons.shopping_cart_outlined),
              tooltip: 'Giỏ hàng',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              ),
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Tùy chọn quản trị',
              onSelected: (val) {
                if (val == 'admin_category') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoryPage()))
                      .then((_) => _loadCategories());
                } else if (val == 'admin_product') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductPage()))
                      .then((_) => _loadProducts(page: _currentPage));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'admin_category',
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, color: Color(0xFF0F172A), size: 20),
                      SizedBox(width: 8),
                      Text('Quản trị Danh mục (Admin)', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'admin_product',
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A), size: 20),
                      SizedBox(width: 8),
                      Text('Quản trị Món ăn (Admin)', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadCategories();
          await _loadFeaturedProducts();
          await _loadProducts(page: 1);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<int?>(
                valueListenable: QrTableSession.instance.activeTableIdNotifier,
                builder: (context, tableId, _) {
                  if (tableId == null) return const SizedBox.shrink();
                  final tName = QrTableSession.instance.activeTableName ?? 'Bàn #$tableId';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF059669), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đang gọi món QR tại $tName — Đơn gửi thẳng xuống bếp!',
                            style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Color(0xFF065F46)),
                          tooltip: 'Thoát chế độ QR bàn',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: QrTableSession.instance.clear,
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildSearchBar(),
              _buildHorizontalCategories(),
              if (_featuredProducts.isNotEmpty && _selectedCategoryId == null && _searchController.text.isEmpty)
                _buildFeaturedSection(),
              _buildFilterAndSortBar(),
              _buildProductGrid(),
              if (_totalPages > 1) _buildPaginationControls(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tên món ăn, đồ uống, mô tả...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    _loadProducts(page: 1);
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildHorizontalCategories() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll ? _selectedCategoryId == null : _selectedCategoryId == _categories[index - 1].id;
          final label = isAll ? 'Tất cả món' : _categories[index - 1].name;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text(label),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF0F172A),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
              ),
              onSelected: (_) => _onCategorySelected(isAll ? null : _categories[index - 1].id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedSection() {
    if (!_isLoadingFeatured && _featuredProducts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 6),
              Text(
                'Món Nổi Bật & Bán Chạy',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _featuredProducts.length,
            itemBuilder: (context, index) {
              final item = _featuredProducts[index];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductDetailPage(product: item)),
                ),
                child: Container(
                  width: 136,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: Container(
                          height: 76,
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: item.fullImageUrl.isNotEmpty
                              ? Image.network(
                                  item.fullImageUrl,
                                  height: 76,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 36),
                                  ),
                                )
                              : const Center(child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 36)),
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
                                item.productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _currencyFormat.format(item.price),
                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilterAndSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Danh sách món ($_totalItems)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<String>(
            value: _selectedSort,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.sort, size: 18, color: Color(0xFF0F172A)),
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
            items: const [
              DropdownMenuItem(value: 'default', child: Text('Mặc định')),
              DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
              DropdownMenuItem(value: 'price_asc', child: Text('Giá thấp đến cao')),
              DropdownMenuItem(value: 'price_desc', child: Text('Giá cao đến thấp')),
              DropdownMenuItem(value: 'name_asc', child: Text('Tên A-Z')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedSort = val);
                _loadProducts(page: 1);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const SkeletonGridPlaceholder(itemCount: 4);
    }

    if (_errorMessage != null && _products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 52, color: Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF475569))),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _loadProducts(page: _currentPage),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('Không tìm thấy món ăn nào phù hợp', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.70,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) => _buildProductCard(_products[index]),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final soldOut = !product.isAvailable;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
      ),
      child: Opacity(
        opacity: soldOut ? 0.72 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 118,
                      width: double.infinity,
                      color: const Color(0xFF0F172A),
                      child: product.fullImageUrl.isNotEmpty
                          ? Image.network(
                              product.fullImageUrl,
                              height: 118,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.restaurant, color: Color(0xFFF59E0B), size: 44),
                              ),
                            )
                          : const Center(child: Icon(Icons.restaurant, color: Color(0xFFF59E0B), size: 44)),
                    ),
                  ),
                  if (soldOut)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HẾT MÓN',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  if (product.resolvedImages.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '${product.resolvedImages.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (product.isFeatured && !soldOut)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HOT',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (product.description != null && product.description!.isNotEmpty)
                            Text(
                              product.description!,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _currencyFormat.format(product.price),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _quickAddToCart(product),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: soldOut ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                soldOut ? Icons.block : Icons.add_shopping_cart,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
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
  }

  Widget _buildPaginationControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentPage > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.arrow_back_ios, size: 12),
            label: const Text('Trước', style: TextStyle(fontSize: 12)),
            onPressed: _currentPage > 1 ? () => _loadProducts(page: _currentPage - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Trang $_currentPage / $_totalPages',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentPage < _totalPages ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: const Text('Sau', style: TextStyle(fontSize: 12)),
            icon: const Icon(Icons.arrow_forward_ios, size: 12),
            onPressed: _currentPage < _totalPages ? () => _loadProducts(page: _currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}

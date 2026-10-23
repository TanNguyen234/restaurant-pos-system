import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import '../utils/database_helper.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'admin/admin_category_page.dart';
import 'admin/admin_product_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Category> _categories = [];
  int? _selectedCategoryId; // null = Tất cả

  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  bool _isLoading = true;
  bool _isLoadingFeatured = true;

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 8;
  int _totalPages = 1;
  int _totalItems = 0;
  String _selectedSort = 'default';

  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFeaturedProducts();
    _loadProducts();
    _loadCartCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCartCount() async {
    final count = await _dbHelper.getCartItemCount();
    if (!mounted) return;
    setState(() => _cartCount = count);
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryRepository.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats ?? [];
    });
  }

  Future<void> _loadFeaturedProducts() async {
    setState(() => _isLoadingFeatured = true);
    final featured = await ProductRepository.getFeaturedProducts(limit: 6);
    if (!mounted) return;
    setState(() {
      _featuredProducts = featured;
      _isLoadingFeatured = false;
    });
  }

  Future<void> _loadProducts({int page = 1}) async {
    setState(() => _isLoading = true);
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
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _loadProducts(page: 1);
    });
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadProducts(page: 1);
  }

  Future<void> _quickAddToCart(Product product) async {
    final cartItem = {
      'product_id': product.productId,
      'product_name': product.productName,
      'price': product.price,
      'quantity': 1,
      'image_url': product.imageUrl,
      'note': null,
    };
    await _dbHelper.insertOrUpdateCart(cartItem);
    await _loadCartCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm 1 x "${product.productName}" vào giỏ'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
        action: SnackBarAction(
          label: 'GIỎ HÀNG',
          textColor: const Color(0xFFF59E0B),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            ).then((_) => _loadCartCount());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurant & Cafe POS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Thực đơn món ăn & Đồ uống F&B',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Giỏ hàng',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartPage()),
                  ).then((_) => _loadCartCount());
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Tùy chọn quản trị',
            onSelected: (val) {
              if (val == 'admin_category') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminCategoryPage()),
                ).then((_) => _loadCategories());
              } else if (val == 'admin_product') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProductPage()),
                ).then((_) => _loadProducts(page: _currentPage));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'admin_category',
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, color: Color(0xFF0F172A), size: 20),
                    SizedBox(width: 8),
                    Text('Quản trị Danh mục (Admin)', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
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
          await _loadCartCount();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh tìm kiếm
              _buildSearchBar(),

              // Danh mục cuộn ngang
              _buildHorizontalCategories(),

              // Banner món nổi bật / bán chạy
              if (_featuredProducts.isNotEmpty && _selectedCategoryId == null && _searchController.text.isEmpty)
                _buildFeaturedSection(),

              // Bộ lọc sắp xếp & Tổng số món
              _buildFilterAndSortBar(),

              // Danh sách món ăn phân trang dạng GridView
              _buildProductGrid(),

              // Bộ điều khiển phân trang
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
                    _loadProducts(page: 1);
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
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
          final isSelected = isAll
              ? _selectedCategoryId == null
              : _selectedCategoryId == _categories[index - 1].id;

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
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                ),
              ),
              onSelected: (_) {
                _onCategorySelected(isAll ? null : _categories[index - 1].id);
              },
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _featuredProducts.length,
            itemBuilder: (context, index) {
              final item = _featuredProducts[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(product: item),
                    ),
                  ).then((_) => _loadCartCount());
                },
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: Container(
                          height: 75,
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: item.fullImageUrl.isNotEmpty
                              ? Image.network(
                                  item.fullImageUrl,
                                  height: 75,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 36),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 36),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(item.price),
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFilterAndSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Danh sách món ($_totalItems)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          DropdownButton<String>(
            value: _selectedSort,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.sort, size: 18, color: Color(0xFF0F172A)),
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
            items: const [
              DropdownMenuItem(value: 'default', child: Text('Mặc định')),
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
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F172A)),
        ),
      );
    }

    if (_products.isEmpty) {
      return Container(
        height: 250,
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        ).then((_) => _loadCartCount());
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh món
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFF0F172A),
                    child: product.fullImageUrl.isNotEmpty
                        ? Image.network(
                            product.fullImageUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.restaurant, color: Color(0xFFF59E0B), size: 44),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.restaurant, color: Color(0xFFF59E0B), size: 44),
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
                if (product.isFeatured)
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Nội dung
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (product.description != null && product.description!.isNotEmpty)
                          Text(
                            product.description!,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFFEF4444),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => _quickAddToCart(product),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../utils/database_helper.dart';
import 'cart_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _noteController = TextEditingController();

  int _quantity = 1;
  int _cartCount = 0;
  ProductAttribute? _selectedSize;
  String _selectedSugar = '100% đường';
  String _selectedIce = 'Đá bình thường';
  final Set<ProductAttribute> _selectedToppings = {};

  List<Product> _relatedProducts = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _initDefaultOptions();
    _loadCartCount();
    _loadRelatedProducts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initDefaultOptions() {
    // Tìm Size mặc định
    final sizes = widget.product.attributes.where((a) => a.attributeGroup == 'Size').toList();
    if (sizes.isNotEmpty) {
      _selectedSize = sizes.first;
    }
  }

  Future<void> _loadCartCount() async {
    final count = await _dbHelper.getCartItemCount();
    if (!mounted) return;
    setState(() => _cartCount = count);
  }

  Future<void> _loadRelatedProducts() async {
    setState(() => _isLoadingRelated = true);
    final result = await ProductRepository.getRelatedProducts(
      widget.product.productId,
      page: 1,
      pageSize: 4,
    );
    if (!mounted) return;
    setState(() {
      _relatedProducts = result.data;
      _isLoadingRelated = false;
    });
  }

  double get _currentUnitPrice {
    double total = widget.product.price;
    if (_selectedSize != null) {
      total += _selectedSize!.extraPrice;
    }
    for (var topping in _selectedToppings) {
      total += topping.extraPrice;
    }
    return total;
  }

  double get _totalPrice => _currentUnitPrice * _quantity;

  Future<void> _addToCart() async {
    // Tổng hợp ghi chú tùy chọn F&B
    List<String> options = [];
    if (_selectedSize != null) {
      options.add(_selectedSize!.attributeName);
    }
    if (_selectedSugar != '100% đường') {
      options.add(_selectedSugar);
    }
    if (_selectedIce != 'Đá bình thường') {
      options.add(_selectedIce);
    }
    for (var top in _selectedToppings) {
      options.add(top.attributeName);
    }
    if (_noteController.text.trim().isNotEmpty) {
      options.add('Ghi chú: ${_noteController.text.trim()}');
    }

    final noteString = options.isNotEmpty ? options.join(' • ') : null;

    final cartItem = {
      'product_id': widget.product.productId,
      'product_name': widget.product.productName,
      'price': _currentUnitPrice,
      'quantity': _quantity,
      'image_url': widget.product.imageUrl,
      'note': noteString,
    };

    await _dbHelper.insertOrUpdateCart(cartItem);
    await _loadCartCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm $_quantity x "${widget.product.productName}" vào giỏ hàng!'),
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'XEM GIỎ',
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
    final sizes = widget.product.attributes.where((a) => a.attributeGroup == 'Size').toList();
    final toppings = widget.product.attributes.where((a) => a.attributeGroup == 'Topping').toList();
    final isDrink = widget.product.categoryId <= 3; // Danh mục nước/trà/cà phê

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.product.productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh lớn sản phẩm
            _buildHeroImage(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin cơ bản: Tên, Phân loại, Giá
                  _buildHeaderInfo(),
                  const SizedBox(height: 16),
                  const Divider(),

                  // Tùy chọn Kích thước (Size)
                  if (sizes.isNotEmpty) ...[
                    _buildSectionTitle('Kích thước (Size)'),
                    _buildSizeOptions(sizes),
                    const SizedBox(height: 16),
                  ],

                  // Tùy chọn Mức đường & Đá (cho đồ uống)
                  if (isDrink) ...[
                    _buildSectionTitle('Mức đường'),
                    _buildSugarOptions(),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Mức đá'),
                    _buildIceOptions(),
                    const SizedBox(height: 16),
                  ],

                  // Tùy chọn Topping
                  if (toppings.isNotEmpty) ...[
                    _buildSectionTitle('Topping thêm'),
                    _buildToppingOptions(toppings),
                    const SizedBox(height: 16),
                  ],

                  // Ô nhập Ghi chú riêng
                  _buildSectionTitle('Ghi chú cho quầy pha chế / bếp'),
                  _buildNoteField(),
                  const SizedBox(height: 24),

                  // Món ăn liên quan (cùng danh mục)
                  _buildRelatedSection(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomAddToCartBar(),
    );
  }

  Widget _buildHeroImage() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              size: 90,
              color: Color(0xFFF59E0B),
            ),
          ),
          if (widget.product.isFeatured)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Món nổi bật',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.product.productName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Text(
              _currencyFormat.format(widget.product.price),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.product.categoryName ?? 'Thực đơn F&B',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Đơn vị: ${widget.product.unit}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        if (widget.product.description != null && widget.product.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.product.description!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildSizeOptions(List<ProductAttribute> sizes) {
    return Wrap(
      spacing: 8,
      children: sizes.map((size) {
        final isSelected = _selectedSize?.attributeId == size.attributeId;
        return ChoiceChip(
          label: Text(
            size.extraPrice > 0
                ? '${size.attributeName} (+${_currencyFormat.format(size.extraPrice)})'
                : size.attributeName,
          ),
          selected: isSelected,
          selectedColor: const Color(0xFF0F172A),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          onSelected: (val) {
            if (val) setState(() => _selectedSize = size);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSugarOptions() {
    final levels = ['100% đường', '70% đường', '50% đường', '30% đường', 'Không đường'];
    return Wrap(
      spacing: 8,
      children: levels.map((sugar) {
        final isSelected = _selectedSugar == sugar;
        return ChoiceChip(
          label: Text(sugar),
          selected: isSelected,
          selectedColor: const Color(0xFF0F172A),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          onSelected: (val) {
            if (val) setState(() => _selectedSugar = sugar);
          },
        );
      }).toList(),
    );
  }

  Widget _buildIceOptions() {
    final levels = ['Đá bình thường', 'Ít đá (50%)', 'Không đá', 'Đá riêng'];
    return Wrap(
      spacing: 8,
      children: levels.map((ice) {
        final isSelected = _selectedIce == ice;
        return ChoiceChip(
          label: Text(ice),
          selected: isSelected,
          selectedColor: const Color(0xFF0F172A),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          onSelected: (val) {
            if (val) setState(() => _selectedIce = ice);
          },
        );
      }).toList(),
    );
  }

  Widget _buildToppingOptions(List<ProductAttribute> toppings) {
    return Column(
      children: toppings.map((top) {
        final isChecked = _selectedToppings.contains(top);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: const Color(0xFF0F172A),
          title: Text(top.attributeName, style: const TextStyle(fontSize: 14)),
          subtitle: Text('+${_currencyFormat.format(top.extraPrice)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          value: isChecked,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedToppings.add(top);
              } else {
                _selectedToppings.remove(top);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        hintText: 'Ví dụ: Mang đá riêng, ít ngọt, không thêm kem bơ...',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildRelatedSection() {
    if (_isLoadingRelated) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        _buildSectionTitle('Món ăn cùng danh mục (Gợi ý)'),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              final item = _relatedProducts[index];
              return InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(product: item),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 90,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Center(
                          child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 36),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
      ],
    );
  }

  Widget _buildBottomAddToCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bộ tăng giảm số lượng
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Nút Thêm vào giỏ
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart, color: Color(0xFFF59E0B)),
                  label: Text(
                    'THÊM ${_currencyFormat.format(_totalPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _addToCart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../utils/database_helper.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/skeleton_loading.dart';
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

  late Product _detailProduct;
  int _quantity = 1;
  int _currentImageIndex = 0;
  ProductAttribute? _selectedSize;
  String _selectedSugar = '100% đường';
  String _selectedIce = 'Đá bình thường';
  final Set<ProductAttribute> _selectedToppings = {};

  List<Product> _relatedProducts = [];
  bool _isLoadingRelated = true;
  int _relatedPage = 1;
  int _relatedTotalPages = 1;

  @override
  void initState() {
    super.initState();
    _detailProduct = widget.product;
    _initDefaultOptions();
    _fetchFullDetail();
    _loadRelatedProducts(page: 1);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initDefaultOptions() {
    final sizes = _detailProduct.attributes.where((a) => a.attributeGroup == 'Size').toList();
    if (sizes.isNotEmpty) {
      _selectedSize = sizes.first;
    }
  }

  Future<void> _fetchFullDetail() async {
    try {
      final fetched = await ProductRepository.getProductDetail(widget.product.productId);
      if (!mounted || fetched.productId <= 0) return;
      setState(() {
        _detailProduct = fetched;
        final sizes = fetched.attributes.where((a) => a.attributeGroup == 'Size').toList();
        if (sizes.isNotEmpty && (_selectedSize == null || !sizes.contains(_selectedSize))) {
          _selectedSize = sizes.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadRelatedProducts({int page = 1}) async {
    setState(() => _isLoadingRelated = true);
    try {
      final result = await ProductRepository.getRelatedProducts(
        widget.product.productId,
        page: page,
        pageSize: 4,
      );
      if (!mounted) return;
      setState(() {
        _relatedProducts = result.data;
        _relatedPage = result.page;
        _relatedTotalPages = result.totalPages > 0 ? result.totalPages : 1;
        _isLoadingRelated = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRelated = false);
    }
  }

  double get _currentUnitPrice {
    double total = _detailProduct.price;
    if (_selectedSize != null) {
      total += _selectedSize!.extraPrice;
    }
    for (final topping in _selectedToppings) {
      total += topping.extraPrice;
    }
    return total;
  }

  double get _totalPrice => _currentUnitPrice * _quantity;

  Future<void> _addToCart() async {
    if (!_detailProduct.isAvailable) return;

    final options = <String>[];
    if (_selectedSize != null) options.add(_selectedSize!.attributeName);
    if (_selectedSugar != '100% đường') options.add(_selectedSugar);
    if (_selectedIce != 'Đá bình thường') options.add(_selectedIce);
    for (final top in _selectedToppings) {
      options.add(top.attributeName);
    }
    if (_noteController.text.trim().isNotEmpty) {
      options.add('Ghi chú: ${_noteController.text.trim()}');
    }

    final noteString = options.isNotEmpty ? options.join(' • ') : null;

    final modifiers = <Map<String, dynamic>>[];
    if (_selectedSize != null) {
      modifiers.add({
        'attributeId': _selectedSize!.attributeId,
        'modifierName': _selectedSize!.attributeName,
        'modifierGroup': 'Size',
        'extraPrice': _selectedSize!.extraPrice,
      });
    }
    for (final top in _selectedToppings) {
      modifiers.add({
        'attributeId': top.attributeId,
        'modifierName': top.attributeName,
        'modifierGroup': 'Topping',
        'extraPrice': top.extraPrice,
      });
    }

    final cartItem = {
      'product_id': _detailProduct.productId,
      'product_name': _detailProduct.productName,
      'price': _currentUnitPrice,
      'quantity': _quantity,
      'image_url': _detailProduct.imageUrl,
      'note': noteString,
      'modifiers_json': modifiers.isNotEmpty ? jsonEncode(modifiers) : null,
    };

    await _dbHelper.insertOrUpdateCart(cartItem);

    if (!mounted) return;
    showAutoDismissSnackBar(
      context,
      message: 'Đã thêm $_quantity x "${_detailProduct.productName}" vào giỏ hàng!',
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFF0F172A),
      actionLabel: 'XEM GIỎ',
      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = _detailProduct.attributes.where((a) => a.attributeGroup == 'Size').toList();
    final toppings = _detailProduct.attributes.where((a) => a.attributeGroup == 'Topping').toList();
    final isDrink = _detailProduct.categoryId <= 4;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _detailProduct.productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _dbHelper.cartCountNotifier,
            builder: (context, cartCount, _) => IconButton(
              icon: cartCount > 0
                  ? Badge(
                      label: Text('$cartCount'),
                      backgroundColor: const Color(0xFFEF4444),
                      child: const Icon(Icons.shopping_cart_outlined),
                    )
                  : const Icon(Icons.shopping_cart_outlined),
              tooltip: 'Giỏ hàng',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroImage(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(),
                      const SizedBox(height: 16),
                      const Divider(),
                      if (sizes.isNotEmpty) ...[
                        _buildSectionTitle('Kích thước (Size)'),
                        _buildSizeOptions(sizes),
                        const SizedBox(height: 16),
                      ],
                      if (isDrink) ...[
                        _buildSectionTitle('Mức đường'),
                        _buildSugarOptions(),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Mức đá'),
                        _buildIceOptions(),
                        const SizedBox(height: 16),
                      ],
                      if (toppings.isNotEmpty) ...[
                        _buildSectionTitle('Topping thêm'),
                        _buildToppingOptions(toppings),
                        const SizedBox(height: 16),
                      ],
                      _buildSectionTitle('Ghi chú cho quầy pha chế / bếp'),
                      _buildNoteField(),
                      const SizedBox(height: 24),
                      _buildRelatedSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAddToCartBar(),
    );
  }

  Widget _buildHeroImage() {
    final images = _detailProduct.allFullImageUrls;
    final hasMultiple = images.length > 1;

    return Container(
      width: double.infinity,
      height: 250,
      decoration: const BoxDecoration(color: Color(0xFF0F172A)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (images.isNotEmpty)
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _currentImageIndex = index),
              itemBuilder: (context, index) => Image.network(
                images[index],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(child: Icon(Icons.restaurant_menu, size: 90, color: Color(0xFFF59E0B))),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
              child: const Icon(Icons.restaurant_menu, size: 90, color: Color(0xFFF59E0B)),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          if (!_detailProduct.isAvailable)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(20)),
                child: const Text('TẠM HẾT MÓN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          if (_detailProduct.isFeatured)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Món nổi bật', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          if (hasMultiple)
            Positioned(
              bottom: 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (hasMultiple)
            Positioned(
              bottom: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index ? const Color(0xFFF59E0B) : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
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
                _detailProduct.productName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _currencyFormat.format(_detailProduct.price),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
              child: Text(
                _detailProduct.categoryName ?? 'Thực đơn F&B',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              ),
            ),
            Text('Đơn vị: ${_detailProduct.unit}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        if (_detailProduct.description != null && _detailProduct.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _detailProduct.description!,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
    );
  }

  Widget _buildSizeOptions(List<ProductAttribute> sizes) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
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
      runSpacing: 6,
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
      runSpacing: 6,
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }

  Widget _buildRelatedSection() {
    if (_isLoadingRelated) {
      return const SkeletonShimmer(child: SkeletonCardPlaceholder());
    }
    if (_relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Món ăn cùng danh mục (Gợi ý)'),
            if (_relatedTotalPages > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _relatedPage > 1 ? () => _loadRelatedProducts(page: _relatedPage - 1) : null,
                  ),
                  Text('$_relatedPage/$_relatedTotalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _relatedPage < _relatedTotalPages ? () => _loadRelatedProducts(page: _relatedPage + 1) : null,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 184,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              final item = _relatedProducts[index];
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductDetailPage(product: item)),
                ),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Container(
                          height: 90,
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: item.fullImageUrl.isNotEmpty
                              ? Image.network(
                                  item.fullImageUrl,
                                  height: 90,
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
      ],
    );
  }

  Widget _buildBottomAddToCartBar() {
    final soldOut = !_detailProduct.isAvailable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: (!soldOut && _quantity > 1) ? () => setState(() => _quantity--) : null,
                  ),
                  Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: !soldOut ? () => setState(() => _quantity++) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: soldOut ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(soldOut ? Icons.block : Icons.add_shopping_cart, color: soldOut ? Colors.white : const Color(0xFFF59E0B)),
                  label: Text(
                    soldOut ? 'MÓN ĐÃ TẠM HẾT' : 'THÊM ${_currencyFormat.format(_totalPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: soldOut ? null : _addToCart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

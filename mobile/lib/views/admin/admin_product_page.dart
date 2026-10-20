import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/product_repository.dart';

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;

  List<Product> _products = [];
  bool _isLoading = true;

  int _currentPage = 1;
  final int _pageSize = 8;
  int _totalPages = 1;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryRepository.getCategories();
    if (!mounted) return;
    setState(() => _categories = cats ?? []);
  }

  Future<void> _loadProducts({int page = 1}) async {
    setState(() => _isLoading = true);
    final result = await ProductRepository.getProducts(
      categoryId: _selectedCategoryId,
      search: _searchController.text.trim(),
      page: page,
      pageSize: _pageSize,
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

  void _showProductFormDialog({Product? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.productName ?? '');
    final priceController = TextEditingController(text: product != null ? product.price.toInt().toString() : '');
    final unitController = TextEditingController(text: product?.unit ?? 'Ly');
    final descController = TextEditingController(text: product?.description ?? '');

    int selectedCatId = product?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : 1);
    bool isFeatured = product?.isFeatured ?? false;
    bool isAvailable = product?.isAvailable ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEditing ? 'Chỉnh sửa món ăn' : 'Thêm món ăn mới',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên món ăn / thức uống (*)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedCatId,
                  decoration: const InputDecoration(labelText: 'Danh mục thực đơn (*)'),
                  items: _categories.map((c) {
                    return DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCatId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Đơn giá (VND) (*)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Đơn vị tính'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Mô tả món ăn'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Món nổi bật (HOT / Bán chạy)'),
                  value: isFeatured,
                  onChanged: (val) => setDialogState(() => isFeatured = val ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Đang phục vụ (Còn hàng)'),
                  value: isAvailable,
                  onChanged: (val) => setDialogState(() => isAvailable = val ?? true),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF0F172A)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload ảnh: Tự động lưu & xóa ảnh cũ wwwroot/images/products',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0;
                if (name.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên món và giá hợp lệ!')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                final data = {
                  'CategoryId': selectedCatId,
                  'ProductName': name,
                  'Price': price,
                  'Unit': unitController.text.trim().isNotEmpty ? unitController.text.trim() : 'Ly',
                  'Description': descController.text.trim(),
                  'IsFeatured': isFeatured,
                  'IsAvailable': isAvailable,
                };

                Map<String, dynamic> result;
                if (isEditing) {
                  result = await ProductRepository.updateProduct(product.productId, data);
                } else {
                  result = await ProductRepository.createProduct(data);
                }

                await _loadProducts(page: _currentPage);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? (result['success'] == true ? 'Thành công' : 'Thất bại')),
                    backgroundColor: result['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              },
              child: Text(isEditing ? 'Cập nhật' : 'Thêm mới'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa món', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa món "${product.productName}" khỏi thực đơn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final result = await ProductRepository.deleteProduct(product.productId);
    await _loadProducts(page: _currentPage);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đã xóa món thành công'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      // Hiển thị dialog cảnh báo bảo toàn kế toán khi món đã phát sinh trong Order
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 28),
              SizedBox(width: 8),
              Text('Ràng buộc Kế toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Text(
            result['message'] ??
                'Sản phẩm đã có trong hóa đơn, không được xóa để bảo toàn số liệu kế toán! Hãy chọn ẩn sản phẩm.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quản trị Món ăn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Admin • Quản lý thực đơn phân trang & giá', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFF59E0B)),
            tooltip: 'Thêm món',
            onPressed: () => _showProductFormDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bộ lọc tìm kiếm & Danh mục
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadProducts(page: 1),
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm tên món...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Color(0xFF0F172A)),
                        onPressed: () => _loadProducts(page: 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<int?>(
                    value: _selectedCategoryId,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Tất cả', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả', style: TextStyle(fontSize: 13)),
                      ),
                      ..._categories.map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name, style: const TextStyle(fontSize: 13)),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedCategoryId = val);
                      _loadProducts(page: 1);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Danh sách món ăn
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _products.isEmpty
                    ? const Center(child: Text('Không tìm thấy món ăn nào'))
                    : RefreshIndicator(
                        onRefresh: () => _loadProducts(page: _currentPage),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final item = _products[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 24),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isFeatured)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('HOT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_currencyFormat.format(item.price)} / ${item.unit}',
                                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (item.description != null && item.description!.isNotEmpty)
                                      Text(
                                        item.description!,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                                      tooltip: 'Sửa món',
                                      onPressed: () => _showProductFormDialog(product: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                      tooltip: 'Xóa món',
                                      onPressed: () => _deleteProduct(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Phân trang
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1 ? () => _loadProducts(page: _currentPage - 1) : null,
                  ),
                  Text('Trang $_currentPage / $_totalPages (Tổng $_totalItems món)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages ? () => _loadProducts(page: _currentPage + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Color(0xFFF59E0B)),
        label: const Text('Thêm món', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showProductFormDialog(),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/picked_images_preview.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/product_repository.dart';
import 'admin_inventory_page.dart';

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Category> _categories = [];
  int? _selectedFilterCategoryId;

  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _fromCache = false;

  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalPages = 1;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadCategories();
    await _loadProducts(page: 1);
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await CategoryRepository.getCategories(includeInactive: true);
      if (mounted && cats != null) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadProducts({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ProductRepository.getProducts(
        page: page,
        pageSize: _pageSize,
        categoryId: _selectedFilterCategoryId,
        search: _searchController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _products = result.data;
        _fromCache = result.fromCache;
        _currentPage = result.page;
        _totalPages = result.totalPages > 0 ? result.totalPages : 1;
        _totalItems = result.totalItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách món ăn: $e';
      });
    }
  }

  Future<void> _toggleAvailability(Product item) async {
    final res = await ProductRepository.toggleAvailability(item.productId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? 'Đã cập nhật trạng thái món'),
        backgroundColor: res['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
      ),
    );
    if (res['success'] == true) {
      await _loadProducts(page: _currentPage);
    }
  }

  Future<void> _showAttributesDialog(Product product) async {
    Product detail;
    try {
      detail = await ProductRepository.getProductDetail(product.productId);
    } catch (_) {
      detail = product;
    }
    if (!mounted) return;

    final groupCtrl = TextEditingController(text: 'Size');
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    bool isRequired = false;
    List<ProductAttribute> attrs = List<ProductAttribute>.from(detail.attributes);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Size / Topping: ${product.productName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (attrs.isEmpty)
                    const Text('Món này chưa có tùy chọn Size/Topping.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                  else
                    ...attrs.map((a) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${a.attributeGroup}: ${a.attributeName} (+${_currencyFormat.format(a.extraPrice)})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: a.isRequired ? const Text('Bắt buộc chọn', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))) : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 20),
                            onPressed: () async {
                              final r = await ProductRepository.deleteAttribute(a.attributeId);
                              if (!dCtx.mounted) return;
                              if (r['success'] == true) {
                                final refreshed = await ProductRepository.getProductDetail(product.productId);
                                if (!dCtx.mounted) return;
                                setD(() => attrs = refreshed.attributes);
                              }
                            },
                          ),
                        )),
                  const Divider(height: 20),
                  const Text('Thêm tùy chọn mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: groupCtrl.text,
                    decoration: const InputDecoration(labelText: 'Nhóm', border: OutlineInputBorder(), isDense: true),
                    items: const ['Size', 'Topping', 'Đường', 'Đá']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) groupCtrl.text = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Tên tùy chọn (VD: Size L / Trân châu)', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Phụ thu (VNĐ)', border: OutlineInputBorder(), isDense: true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Bắt buộc chọn theo nhóm', style: TextStyle(fontSize: 13)),
                    value: isRequired,
                    onChanged: (v) => setD(() => isRequired = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final r = await ProductRepository.addAttribute(
                  productId: product.productId,
                  attributeGroup: groupCtrl.text.trim(),
                  attributeName: nameCtrl.text.trim(),
                  extraPrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                  isRequired: isRequired,
                );
                if (!dCtx.mounted) return;
                if (r['success'] == true) {
                  nameCtrl.clear();
                  priceCtrl.text = '0';
                  final refreshed = await ProductRepository.getProductDetail(product.productId);
                  if (!dCtx.mounted) return;
                  setD(() => attrs = refreshed.attributes);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductFormDialog({Product? product}) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có danh mục nào. Vui lòng tạo danh mục trước!'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.productName ?? '');
    final priceController = TextEditingController(text: product != null ? product.price.toInt().toString() : '');
    final unitController = TextEditingController(text: product?.unit ?? 'Ly');
    final descController = TextEditingController(text: product?.description ?? '');
    final imageController = TextEditingController(text: product?.imageUrl ?? '');

    int selectedCatId = _categories.any((c) => c.id == product?.categoryId)
        ? product!.categoryId
        : _categories.first.id;
    bool isFeatured = product?.isFeatured ?? false;
    bool isAvailable = product?.isAvailable ?? true;
    List<Uint8List> pickedImages = [];
    List<String> pickedNames = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                  initialValue: selectedCatId,
                  decoration: const InputDecoration(labelText: 'Danh mục thực đơn (*)'),
                  items: _categories
                      .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCatId = val);
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
                        decoration: const InputDecoration(labelText: 'Đơn giá (VNĐ) (*)'),
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    pickedImages.isEmpty
                        ? 'Chọn ảnh món ăn (hỗ trợ nhiều ảnh)'
                        : 'Đã chọn ${pickedImages.length} ảnh mới',
                  ),
                  onPressed: () async {
                    final files = await _picker.pickMultiImage(imageQuality: 85);
                    if (files.isNotEmpty) {
                      final bytesList = <Uint8List>[];
                      final namesList = <String>[];
                      for (final f in files) {
                        bytesList.add(await f.readAsBytes());
                        namesList.add(f.name);
                      }
                      setDialogState(() {
                        pickedImages = bytesList;
                        pickedNames = namesList;
                      });
                    }
                  },
                ),
                if (pickedImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  PickedImagesPreview(images: pickedImages),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: imageController,
                  decoration: InputDecoration(
                    labelText: 'Hoặc tên file / URL (nếu không upload mới)',
                    hintText: 'default_product.png',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    suffixIcon: imageController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setDialogState(() => imageController.clear()),
                          )
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (pickedImages.isEmpty && imageController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Builder(builder: (c) {
                    final firstImg = imageController.text.trim().split(';').first.trim();
                    final previewUrl = firstImg.startsWith('http')
                        ? firstImg
                        : '${ApiConfig.baseUrl.replaceAll('/api', '')}/images/products/$firstImg';
                    return Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFFF1F5F9),
                            child: Image.network(
                              previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Xem trước ảnh hiện tại', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                      ],
                    );
                  }),
                ],
                const SizedBox(height: 10),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
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
                  if (pickedImages.isEmpty)
                    'ImageUrl': imageController.text.trim().isNotEmpty ? imageController.text.trim() : 'default_product.png',
                  'IsFeatured': isFeatured,
                  'IsAvailable': isAvailable,
                };

                final Map<String, dynamic> result;
                if (isEditing) {
                  result = await ProductRepository.updateProduct(
                    product.productId,
                    data,
                    multipleImageBytes: pickedImages.isNotEmpty ? pickedImages : null,
                    multipleFileNames: pickedNames.isNotEmpty ? pickedNames : null,
                  );
                } else {
                  result = await ProductRepository.createProduct(
                    data,
                    multipleImageBytes: pickedImages.isNotEmpty ? pickedImages : null,
                    multipleFileNames: pickedNames.isNotEmpty ? pickedNames : null,
                  );
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa ngay'),
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
        SnackBar(content: Text('Đã xóa món "${product.productName}" thành công!'), backgroundColor: const Color(0xFF10B981)),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Ràng buộc dữ liệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(result['message'] ?? 'Không thể xóa món ăn này vì đã gắn liền với các đơn hàng lịch sử.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedFilterCategoryId,
                      hint: const Text('Tất cả nhóm', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Tất cả nhóm', style: TextStyle(fontSize: 12))),
                        ..._categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedFilterCategoryId = val);
                        _loadProducts(page: 1);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_fromCache)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF3C7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Không kết nối được máy chủ: đang hiển thị dữ liệu offline (không có ảnh, có thể cũ). Kiểm tra backend rồi bấm làm mới.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                  TextButton(onPressed: () => _loadProducts(page: _currentPage), child: const Text('Làm mới')),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 14),
                              FilledButton(onPressed: () => _loadProducts(page: _currentPage), child: const Text('Thử lại')),
                            ],
                          ),
                        ),
                      )
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
                                    boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        color: const Color(0xFF0F172A),
                                        child: item.fullImageUrl.isNotEmpty
                                            ? Image.network(
                                                item.fullImageUrl,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => const Center(child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 24)),
                                              )
                                            : const Center(child: Icon(Icons.coffee, color: Color(0xFFF59E0B), size: 24)),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.productName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              decoration: item.isAvailable ? null : TextDecoration.lineThrough,
                                              color: item.isAvailable ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!item.isAvailable)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('HẾT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        if (item.isFeatured)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
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
                                        if (item.recipeCount > 0 || item.autoDisabledByStock)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'BOM: ${item.recipeCount} NL • Vốn: ${_currencyFormat.format(item.estimatedCogs)}${item.maxServings != null ? ' • Còn: ${item.maxServings} phần' : ''}${item.autoDisabledByStock ? ' • [TỰ TẮT KHO]' : ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: item.autoDisabledByStock ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (item.description != null && item.description!.isNotEmpty)
                                          Text(item.description!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.science_outlined, color: Color(0xFF7C3AED), size: 20),
                                          tooltip: 'Định lượng BOM',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AdminInventoryPage(
                                                initialProductId: item.productId,
                                                initialTab: 1,
                                              ),
                                            ),
                                          ).then((_) => _loadProducts(page: _currentPage)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20),
                                          tooltip: 'Size / Topping',
                                          onPressed: () => _showAttributesDialog(item),
                                        ),
                                        Switch(
                                          value: item.isAvailable,
                                          onChanged: (_) => _toggleAvailability(item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF0F172A), size: 20),
                                          tooltip: 'Chỉnh sửa',
                                          onPressed: () => _showProductFormDialog(product: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                          tooltip: 'Xóa',
                                          onPressed: () => _deleteProduct(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: Colors.white,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPage > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.arrow_back_ios, size: 12),
                    label: const Text('Trước', style: TextStyle(fontSize: 12)),
                    onPressed: _currentPage > 1 ? () => _loadProducts(page: _currentPage - 1) : null,
                  ),
                  Text('Trang $_currentPage / $_totalPages (Tổng: $_totalItems)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPage < _totalPages ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    label: const Text('Sau', style: TextStyle(fontSize: 12)),
                    icon: const Icon(Icons.arrow_forward_ios, size: 12),
                    onPressed: _currentPage < _totalPages ? () => _loadProducts(page: _currentPage + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

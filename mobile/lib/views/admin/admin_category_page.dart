import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../models/category.dart';
import '../../repositories/category_repository.dart';

class AdminCategoryPage extends StatefulWidget {
  const AdminCategoryPage({super.key});

  @override
  State<AdminCategoryPage> createState() => _AdminCategoryPageState();
}

class _AdminCategoryPageState extends State<AdminCategoryPage> {
  final ImagePicker _picker = ImagePicker();
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await CategoryRepository.getCategories(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _categories = data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách danh mục: $e';
      });
    }
  }

  void _showCategoryFormDialog({Category? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final titleController = TextEditingController(text: category?.title ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final sortController = TextEditingController(text: (category?.sortOrder ?? 0).toString());
    final iconController = TextEditingController(text: category?.icon ?? '');
    bool isActive = category?.isActive ?? true;
    Uint8List? pickedBytes;
    String? pickedFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final iconText = iconController.text.trim();
          final previewUrl = iconText.isEmpty
              ? ''
              : (iconText.startsWith('http')
                  ? iconText
                  : '${ApiConfig.baseUrl.replaceAll('/api', '')}/images/categories/$iconText');

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEditing ? 'Chỉnh sửa danh mục' : 'Thêm danh mục mới',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên danh mục (*)', hintText: 'Ví dụ: Cà phê pha máy'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Tiêu đề phụ', hintText: 'Ví dụ: Hương vị Ý nguyên bản'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Mô tả chi tiết', hintText: 'Giới thiệu ngắn về nhóm món này'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Thứ tự hiển thị', hintText: '1, 2, 3...'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(pickedFileName != null ? 'Đã chọn: $pickedFileName' : 'Chọn ảnh danh mục từ máy'),
                    onPressed: () async {
                      final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (xFile != null) {
                        final bytes = await xFile.readAsBytes();
                        setDialogState(() {
                          pickedBytes = bytes;
                          pickedFileName = xFile.name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: iconController,
                    decoration: InputDecoration(
                      labelText: 'Hoặc tên file ảnh / URL',
                      hintText: 'default_category.png',
                      suffixIcon: iconText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setDialogState(() => iconController.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (pickedBytes != null)
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(pickedBytes!, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Ảnh tải lên mới (multipart)', style: TextStyle(fontSize: 12, color: Color(0xFF059669)))),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setDialogState(() {
                            pickedBytes = null;
                            pickedFileName = null;
                          }),
                        ),
                      ],
                    )
                  else if (previewUrl.isNotEmpty)
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 52,
                            height: 52,
                            color: const Color(0xFFF1F5F9),
                            child: Image.network(
                              previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Xem trước hình ảnh danh mục', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                      ],
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Hiển thị danh mục (Đang hoạt động)'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v ?? true),
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
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập tên danh mục!')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);

                  final data = {
                    'Name': name,
                    'Title': titleController.text.trim(),
                    'Description': descController.text.trim(),
                    'SortOrder': int.tryParse(sortController.text.trim()) ?? 0,
                    'IsActive': isActive,
                    if (pickedBytes == null)
                      'Icon': iconController.text.trim().isNotEmpty ? iconController.text.trim() : 'default_category.png',
                  };

                  final Map<String, dynamic> result;
                  if (isEditing) {
                    result = await CategoryRepository.updateCategory(
                      category.id,
                      data,
                      imageBytes: pickedBytes,
                      imageFileName: pickedFileName,
                    );
                  } else {
                    result = await CategoryRepository.createCategory(
                      data,
                      imageBytes: pickedBytes,
                      imageFileName: pickedFileName,
                    );
                  }

                  await _loadCategories();

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
          );
        },
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa danh mục', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa danh mục "${category.name}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final result = await CategoryRepository.deleteCategory(category.id);
    await _loadCategories();

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Đã xóa danh mục thành công'), backgroundColor: const Color(0xFF10B981)),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
              SizedBox(width: 8),
              Text('Chặn thao tác xóa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Text(result['message'] ?? 'Không thể xóa danh mục vì vẫn còn sản phẩm thuộc danh mục này!', style: const TextStyle(height: 1.4)),
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
            Text('Quản trị Danh mục', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Admin • Phân loại thực đơn F&B', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFF59E0B)),
            tooltip: 'Thêm danh mục',
            onPressed: () => _showCategoryFormDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : _errorMessage != null && _categories.isEmpty
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
                        FilledButton(onPressed: _loadCategories, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : _categories.isEmpty
                  ? const Center(child: Text('Chưa có danh mục nào'))
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final item = _categories[index];
                          final imgUrl = item.fullIconUrl.trim();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                  child: imgUrl.isNotEmpty
                                      ? Image.network(
                                          imgUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(Icons.category, color: Color(0xFF0F172A)),
                                        )
                                      : const Icon(Icons.category, color: Color(0xFF0F172A)),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: item.isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                                    child: Text('STT: ${item.sortOrder}', style: const TextStyle(fontSize: 10)),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item.description.isNotEmpty ? item.description : item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                                    tooltip: 'Chỉnh sửa',
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showCategoryFormDialog(category: item),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                    tooltip: 'Xóa danh mục',
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteCategory(item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Color(0xFFF59E0B)),
        label: const Text('Thêm danh mục', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCategoryFormDialog(),
      ),
    );
  }
}

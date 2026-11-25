import 'package:flutter/material.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../services/session_manager.dart';
import '../utils/database_helper.dart';
import '../widgets/skeleton_loading.dart';
import 'admin/admin_category_page.dart';
import 'cart_page.dart';
import 'home_page.dart';

class CategoryPage extends StatefulWidget {
  final String title;

  const CategoryPage({super.key, required this.title});

  @override
  State<StatefulWidget> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Category> categories = [];
  bool isLoading = true;
  String? errorMessage;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await CategoryRepository.getCategories();
      if (!mounted) return;
      setState(() {
        categories = data ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Không thể tải danh mục món ăn. Vui lòng thử lại.';
      });
    }
  }

  Widget _buildCategoryIcon(Category item) {
    final url = item.fullIconUrl.trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 48,
            height: 48,
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            child: const Icon(Icons.restaurant_menu, color: Color(0xFF0F172A), size: 24),
          ),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant_menu, color: Color(0xFF0F172A), size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = SessionManager.instance.isManager;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.3),
            ),
            const Text(
              'Thực đơn món ăn & Đồ uống',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            ),
          ],
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartPage()),
              ),
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Quản trị danh mục (Admin)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminCategoryPage()),
                ).then((_) => _initData());
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLoading
          ? const SkeletonListPlaceholder(itemCount: 5)
          : errorMessage != null && categories.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF475569))),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _initData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _initData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HomePage()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.storefront, color: Color(0xFFF59E0B), size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Xem Trang chủ & Thực đơn đầy đủ',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Món mới phân trang, tìm kiếm & sắp xếp nhanh',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có danh mục nào',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      else
                        ...categories.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: _buildCategoryIcon(item),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.description.isNotEmpty ? item.description : item.title,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HomePage(initialCategoryId: item.id),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

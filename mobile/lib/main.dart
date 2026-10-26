import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/offline_sync_service.dart';
import 'services/session_manager.dart';
import 'models/user.dart';
import 'utils/database_helper.dart';
import 'views/category_page.dart';
import 'views/admin/admin_category_page.dart';
import 'views/admin/admin_product_page.dart';
import 'views/admin/admin_order_list_page.dart';
import 'views/admin/admin_user_page.dart';
import 'views/auth/login_page.dart';
import 'views/kitchen/kitchen_display_page.dart';
import 'views/order/order_checkout_page.dart';
import 'views/cart_page.dart';
import 'views/home_page.dart';
import 'views/table/floor_table_page.dart';
import 'models/product.dart';
import 'repositories/product_repository.dart';
import 'views/product_detail_page.dart';
import 'views/order/order_detail_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.instance.initialize();
  runApp(const RestaurantPosApp());
}

class RestaurantPosApp extends StatelessWidget {
  const RestaurantPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant & Cafe POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFFF59E0B),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.black12,
          indicatorColor: const Color(0xFF0F172A),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Color(0xFF64748B));
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            );
          }),
        ),
      ),
      home: const MainNavigationPage(),
      routes: {
        '/floor': (_) => const FloorTablePage(),
        '/home': (_) => const HomePage(),
        '/category': (_) => const CategoryPage(title: 'Thực đơn & Danh mục'),
        '/cart': (_) => const CartPage(),
        '/checkout': (_) => const OrderCheckoutPage(),
        '/login': (_) => const LoginPage(),
        '/kds': (_) => const KitchenDisplayPage(),
        '/admin/orders': (_) => const AdminOrderListPage(),
        '/admin/categories': (_) => const AdminCategoryPage(),
        '/admin/products': (_) => const AdminProductPage(),
        '/admin/users': (_) => const AdminUserPage(),
        '/product-detail': (_) => const _SampleProductDetailPage(),
        '/order-detail': (_) => const _SampleOrderDetailPage(),
      },
    );
  }
}

class _SampleProductDetailPage extends StatefulWidget {
  const _SampleProductDetailPage();

  @override
  State<_SampleProductDetailPage> createState() => _SampleProductDetailPageState();
}

class _SampleProductDetailPageState extends State<_SampleProductDetailPage> {
  Product? _product;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ProductRepository.getProductDetail(1).then((p) {
      if (mounted) setState(() { _product = p; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
      );
    }
    if (_product == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: Text('Không tìm thấy thông tin sản phẩm mẫu')),
      );
    }
    return ProductDetailPage(product: _product!);
  }
}

class _SampleOrderDetailPage extends StatelessWidget {
  const _SampleOrderDetailPage();

  @override
  Widget build(BuildContext context) {
    return const OrderDetailPage(orderId: 1);
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    SessionManager.instance.initialize();
    DatabaseHelper().refreshCartNotifier();
    _syncService.initialize();
    _syncService.startPeriodicSync(interval: const Duration(seconds: 45));
  }

  @override
  void dispose() {
    _syncService.stopPeriodicSync();
    super.dispose();
  }

  final List<Widget> _pages = const [
    FloorTablePage(),
    HomePage(),
    CategoryPage(title: 'Thực đơn & Danh mục'),
    CartPage(),
    OrdersSyncPage(),
  ];

  Color _getRoleColor(String role) {
    final r = role.toUpperCase();
    if (r == 'ADMIN') return const Color(0xFFDC2626);
    if (r == 'MANAGER') return const Color(0xFFD97706);
    if (r == 'CASHIER') return const Color(0xFF059669);
    if (r == 'WAITER') return const Color(0xFF0284C7);
    if (r == 'KITCHEN' || r.contains('CHEF') || r.contains('BARISTA')) return const Color(0xFF7C3AED);
    return const Color(0xFF64748B);
  }

  Future<void> _handleLogout(BuildContext sheetContext) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản hiện tại khỏi hệ thống POS?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionManager.instance.logout();
      if (!mounted) return;
      if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
        Navigator.pop(sheetContext);
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã đăng xuất khỏi tài khoản thành công.'),
          backgroundColor: Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showOperationsMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        void go(Widget page) {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
        }

        return SafeArea(
          child: ValueListenableBuilder<UserAccount?>(
            valueListenable: SessionManager.instance.currentUserNotifier,
            builder: (context, currentUser, _) {
              final bool isLoggedIn = currentUser != null;
              final bool isAdminOrManager = currentUser != null && (currentUser.isAdmin || currentUser.isManager);
              final bool canAccessKitchen = currentUser != null && (currentUser.isKitchen || currentUser.isAdmin || currentUser.isManager);
              final bool canAccessOrders = currentUser != null && (currentUser.isCashier || currentUser.isAdmin || currentUser.isManager);

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header User Card
                      if (isLoggedIn) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: _getRoleColor(currentUser.role),
                                child: Text(
                                  currentUser.fullName.isNotEmpty ? currentUser.fullName.substring(0, 1).toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentUser.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(currentUser.role).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              currentUser.roleName,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _getRoleColor(currentUser.role),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '@',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.logout_rounded, size: 16),
                                label: const Text('Đăng xuất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _handleLogout(sheetContext),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Trung tâm vận hành', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4),
                                  Text('Khách vãng lai • Chưa đăng nhập', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.login_rounded, size: 16),
                              label: const Text('Đăng nhập'),
                              onPressed: () => go(const LoginPage()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),

                      // Navigation Items with RBAC
                      ListTile(
                        leading: const Icon(Icons.shopping_cart_checkout_outlined, color: Color(0xFF0F172A)),
                        title: const Text('Tạo đơn hàng'),
                        subtitle: const Text('Lập order & thanh toán cho khách'),
                        onTap: () => go(const OrderCheckoutPage()),
                      ),
                      if (canAccessKitchen)
                        ListTile(
                          leading: const Icon(Icons.kitchen_outlined, color: Color(0xFF7C3AED)),
                          title: const Text('Màn hình bếp & pha chế (KDS)'),
                          subtitle: const Text('Tiếp nhận order & theo dõi chế biến'),
                          onTap: () => go(const KitchenDisplayPage()),
                        ),
                      if (canAccessOrders)
                        ListTile(
                          leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0284C7)),
                          title: const Text('Quản lý đơn hàng'),
                          subtitle: const Text('Theo dõi trạng thái & doanh thu'),
                          onTap: () => go(const AdminOrderListPage()),
                        ),

                      if (isAdminOrManager) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.category_outlined, color: Color(0xFF0F172A)),
                          title: const Text('Quản lý danh mục'),
                          subtitle: const Text('Thêm, sửa, sắp xếp nhóm món ăn'),
                          onTap: () => go(const AdminCategoryPage()),
                        ),
                        ListTile(
                          leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A)),
                          title: const Text('Quản lý sản phẩm'),
                          subtitle: const Text('Thực đơn, hình ảnh và thuộc tính món'),
                          onTap: () => go(const AdminProductPage()),
                        ),
                        ListTile(
                          leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFFD97706)),
                          title: const Text('Quản trị người dùng & vai trò'),
                          subtitle: const Text('Danh sách nhân sự & phân quyền RBAC'),
                          onTap: () => go(const AdminUserPage()),
                        ),
                      ],

                      if (isLoggedIn) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
                          title: const Text('Tài khoản của tôi'),
                          subtitle: Text('@${currentUser.username} • ${currentUser.roleName}'),
                          onTap: () => go(const LoginPage()),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pos_operations',
        tooltip: 'Trung tâm vận hành',
        onPressed: _showOperationsMenu,
        child: const Icon(Icons.tune_rounded),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant_rounded),
            label: 'Sơ đồ bàn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Thực đơn',
          ),
          NavigationDestination(
            icon: ValueListenableBuilder<int>(
              valueListenable: DatabaseHelper().cartCountNotifier,
              builder: (context, count, child) {
                if (count == 0) {
                  return const Icon(Icons.shopping_cart_outlined);
                }
                return Badge(
                  label: Text('$count'),
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(Icons.shopping_cart_outlined),
                );
              },
            ),
            selectedIcon: const Icon(Icons.shopping_cart_rounded),
            label: 'Giỏ hàng',
          ),
          NavigationDestination(
            icon: ValueListenableBuilder<int>(
              valueListenable: _syncService.unsyncedCountNotifier,
              builder: (context, count, child) {
                if (count == 0) {
                  return const Icon(Icons.sync_outlined);
                }
                return Badge(
                  label: Text('$count'),
                  backgroundColor: const Color(0xFFD97706),
                  child: const Icon(Icons.sync_outlined),
                );
              },
            ),
            selectedIcon: const Icon(Icons.sync_rounded),
            label: 'Đồng bộ đơn',
          ),
        ],
      ),
    );
  }
}

class OrdersSyncPage extends StatefulWidget {
  const OrdersSyncPage({super.key});

  @override
  State<OrdersSyncPage> createState() => _OrdersSyncPageState();
}

class _OrdersSyncPageState extends State<OrdersSyncPage> {
  List<Map<String, dynamic>> _offlineOrders = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final OfflineSyncService _syncService = OfflineSyncService();
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await _dbHelper.getAllOfflineOrders();
    if (!mounted) return;
    setState(() {
      _offlineOrders = orders;
      _isLoading = false;
    });
  }

  Future<void> _triggerSync() async {
    final result = await _syncService.syncNow();
    await _loadOrders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.failed == 0
            ? const Color(0xFF059669)
            : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              'Đơn hàng ngoại tuyến',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              'Trạng thái đồng bộ hàng đợi SQLite',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng: ${_offlineOrders.length} đơn hàng trong SQLite',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tự động đồng bộ mỗi 45s khi có kết nối',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _triggerSync,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: const Text('Đồng bộ ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _offlineOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cloud_done_outlined,
                                size: 48,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Không có đơn hàng chờ đồng bộ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tất cả đơn hàng ngoại tuyến đã được tải lên máy chủ',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _offlineOrders.length,
                        itemBuilder: (context, index) {
                          final order = _offlineOrders[index];
                          final isSynced = order['is_synced'] == 1;
                          final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                          final customer = order['customer_name'] ?? 'Khách lẻ';
                          final tableId = order['table_id'];
                          final createdAt = order['created_at'] != null
                              ? DateTime.tryParse(order['created_at'].toString())
                              : null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSynced
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFFFCD34D),
                                width: isSynced ? 1 : 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSynced
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isSynced
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.schedule_rounded,
                                      color: isSynced
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Đơn #${order['id']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                tableId != null ? 'Bàn #$tableId' : 'Mang về',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Khách: $customer${createdAt != null ? ' • ${DateFormat('HH:mm dd/MM').format(createdAt)}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormatter.format(totalAmount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSynced
                                              ? const Color(0xFFECFDF5)
                                              : const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isSynced ? 'Đã đồng bộ' : 'Chờ đồng bộ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isSynced
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
}

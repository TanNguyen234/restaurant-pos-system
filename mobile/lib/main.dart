import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/product.dart';
import 'models/user.dart';
import 'repositories/product_repository.dart';
import 'services/offline_sync_service.dart';
import 'services/session_manager.dart';
import 'utils/database_helper.dart';
import 'views/admin/admin_category_page.dart';
import 'views/admin/admin_order_list_page.dart';
import 'views/admin/admin_product_page.dart';
import 'views/admin/admin_user_page.dart';
import 'views/auth/login_page.dart';
import 'views/auth/profile_page.dart';
import 'views/cart_page.dart';
import 'views/cashier/cashier_pos_terminal_page.dart';
import 'views/cashier/shift_management_page.dart';
import 'views/category_page.dart';
import 'views/home_page.dart';
import 'views/kitchen/kitchen_display_page.dart';
import 'views/member/member_home_page.dart';
import 'views/order/order_checkout_page.dart';
import 'views/order/order_detail_page.dart';
import 'views/product_detail_page.dart';
import 'views/table/floor_table_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseHelper.initDesktopFfi();
  await DatabaseHelper().initWebPersistence();
  await SessionManager.instance.initialize();
  await OfflineSyncService().initialize();
  runApp(const RestaurantPosApp());
}

class RestaurantPosApp extends StatelessWidget {
  const RestaurantPosApp({super.key});

  Route<dynamic> _buildGuardedRoute(
    RouteSettings settings,
    Widget Function() builder, {
    bool Function(SessionManager session)? guard,
    String deniedReason = 'Bạn không có quyền truy cập chức năng này.',
  }) {
    if (guard != null && !guard(SessionManager.instance)) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => _UnauthorizedAccessPage(message: deniedReason),
      );
    }
    return MaterialPageRoute(settings: settings, builder: (_) => builder());
  }

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
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              );
            }
            return const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            );
          }),
        ),
      ),
      home: const MainNavigationPage(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _buildGuardedRoute(settings, () => const MainNavigationPage());
          case '/floor':
            return _buildGuardedRoute(settings, () => const FloorTablePage());
          case '/home':
            return _buildGuardedRoute(settings, () => const HomePage());
          case '/category':
            return _buildGuardedRoute(
              settings,
              () => const CategoryPage(title: 'Thực đơn & Danh mục'),
            );
          case '/cart':
            return _buildGuardedRoute(settings, () => const CartPage());
          case '/checkout':
            return _buildGuardedRoute(settings, () => const OrderCheckoutPage());
          case '/login':
            return _buildGuardedRoute(settings, () => const LoginPage());
          case '/profile':
            return _buildGuardedRoute(settings, () => const ProfilePage());
          case '/member':
            return _buildGuardedRoute(settings, () => const MemberHomePage());
          case '/kds':
            return _buildGuardedRoute(
              settings,
              () => const KitchenDisplayPage(),
              guard: (s) => s.isKitchen,
              deniedReason: 'Chỉ Bếp / Pha chế / Quản lý / Admin mới được truy cập màn hình KDS.',
            );
          case '/cashier/pos':
            return _buildGuardedRoute(
              settings,
              () => const CashierPosTerminalPage(),
              guard: (s) => s.isCashier || s.isManager,
              deniedReason: 'Chỉ Thu ngân / Quản lý / Admin mới được truy cập POS Thu Ngân.',
            );
          case '/cashier/shift':
            return _buildGuardedRoute(
              settings,
              () => const ShiftManagementPage(),
              guard: (s) => s.isCashier || s.isManager,
              deniedReason: 'Chỉ Thu ngân / Quản lý / Admin mới được truy cập Quản lý Ca làm việc.',
            );
          case '/admin/orders':
            return _buildGuardedRoute(
              settings,
              () => const AdminOrderListPage(),
              guard: (s) => s.isCashier || s.isManager,
              deniedReason: 'Chỉ Thu ngân / Quản lý / Admin mới được xem quản trị đơn hàng.',
            );
          case '/admin/categories':
            return _buildGuardedRoute(
              settings,
              () => const AdminCategoryPage(),
              guard: (s) => s.isManager,
              deniedReason: 'Chỉ Quản lý / Admin mới được quản lý danh mục.',
            );
          case '/admin/products':
            return _buildGuardedRoute(
              settings,
              () => const AdminProductPage(),
              guard: (s) => s.isManager,
              deniedReason: 'Chỉ Quản lý / Admin mới được quản lý thực đơn.',
            );
          case '/admin/users':
            return _buildGuardedRoute(
              settings,
              () => const AdminUserPage(),
              guard: (s) => s.isManager,
              deniedReason: 'Chỉ Quản lý / Admin mới được phân quyền người dùng.',
            );
          case '/product-detail':
            final arg = settings.arguments;
            if (arg is Product) {
              return _buildGuardedRoute(settings, () => ProductDetailPage(product: arg));
            }
            return _buildGuardedRoute(settings, () => const _SampleProductDetailPage());
          case '/order-detail':
            final arg = settings.arguments;
            if (arg is int) {
              return _buildGuardedRoute(settings, () => OrderDetailPage(orderId: arg));
            }
            return _buildGuardedRoute(settings, () => const _SampleOrderDetailPage());
          default:
            return _buildGuardedRoute(settings, () => const MainNavigationPage());
        }
      },
    );
  }
}

class _UnauthorizedAccessPage extends StatelessWidget {
  final String message;
  const _UnauthorizedAccessPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Truy cập bị từ chối')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: Color(0xFFDC2626)),
              const SizedBox(height: 16),
              const Text(
                'Không đủ thẩm quyền (403)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Quay lại'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text('Đăng nhập tài khoản khác'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      if (mounted) {
        setState(() {
          _product = p;
          _loading = false;
        });
      }
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

class _NavItemSpec {
  final Widget page;
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  const _NavItemSpec({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  String _lastRoleKey = '';
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    DatabaseHelper().refreshCartNotifier();
    _syncService.initialize();
    _syncService.startPeriodicSync(interval: const Duration(seconds: 45));
  }

  @override
  void dispose() {
    _syncService.stopPeriodicSync();
    super.dispose();
  }

  Widget _cartBadgeIcon(bool selected) {
    final baseIcon = Icon(selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined);
    return ValueListenableBuilder<int>(
      valueListenable: DatabaseHelper().cartCountNotifier,
      builder: (context, count, _) {
        if (count == 0) return baseIcon;
        return Badge(
          label: Text('$count'),
          backgroundColor: const Color(0xFFEF4444),
          child: baseIcon,
        );
      },
    );
  }

  Widget _syncBadgeIcon(bool selected) {
    final baseIcon = Icon(selected ? Icons.sync_rounded : Icons.sync_outlined);
    return ValueListenableBuilder<int>(
      valueListenable: _syncService.unsyncedCountNotifier,
      builder: (context, count, _) {
        if (count == 0) return baseIcon;
        return Badge(
          label: Text('$count'),
          backgroundColor: const Color(0xFFD97706),
          child: baseIcon,
        );
      },
    );
  }

  List<_NavItemSpec> _buildTabsForRole(UserAccount? user) {
    if (user == null || user.isMember) {
      return [
        const _NavItemSpec(
          page: HomePage(),
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu_rounded),
          label: 'Thực đơn',
        ),
        const _NavItemSpec(
          page: CategoryPage(title: 'Danh mục món ăn'),
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Danh mục',
        ),
        _NavItemSpec(
          page: const CartPage(),
          icon: _cartBadgeIcon(false),
          selectedIcon: _cartBadgeIcon(true),
          label: 'Giỏ hàng',
        ),
        const _NavItemSpec(
          page: MemberHomePage(),
          icon: Icon(Icons.card_membership_outlined),
          selectedIcon: Icon(Icons.card_membership_rounded),
          label: 'Hội viên',
        ),
        _NavItemSpec(
          page: const ProfilePage(),
          icon: Icon(user == null ? Icons.login_outlined : Icons.person_outline),
          selectedIcon: Icon(user == null ? Icons.login_rounded : Icons.person_rounded),
          label: user == null ? 'Đăng nhập' : 'Tài khoản',
        ),
      ];
    }

    if (user.isManager) {
      return [
        const _NavItemSpec(
          page: FloorTablePage(),
          icon: Icon(Icons.table_restaurant_outlined),
          selectedIcon: Icon(Icons.table_restaurant_rounded),
          label: 'Sơ đồ bàn',
        ),
        const _NavItemSpec(
          page: KitchenDisplayPage(),
          icon: Icon(Icons.kitchen_outlined),
          selectedIcon: Icon(Icons.kitchen_rounded),
          label: 'Bếp KDS',
        ),
        const _NavItemSpec(
          page: CashierPosTerminalPage(),
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale_rounded),
          label: 'Thu ngân',
        ),
        const _NavItemSpec(
          page: AdminOrderListPage(),
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Đơn hàng',
        ),
        const _NavItemSpec(
          page: _OperationsHubPage(),
          icon: Icon(Icons.dashboard_customize_outlined),
          selectedIcon: Icon(Icons.dashboard_customize_rounded),
          label: 'Quản trị',
        ),
      ];
    }

    if (user.isCashier) {
      return [
        const _NavItemSpec(
          page: CashierPosTerminalPage(),
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale_rounded),
          label: 'Thu ngân',
        ),
        const _NavItemSpec(
          page: ShiftManagementPage(),
          icon: Icon(Icons.lock_clock_outlined),
          selectedIcon: Icon(Icons.lock_clock_rounded),
          label: 'Ca làm',
        ),
        const _NavItemSpec(
          page: FloorTablePage(),
          icon: Icon(Icons.table_restaurant_outlined),
          selectedIcon: Icon(Icons.table_restaurant_rounded),
          label: 'Sơ đồ bàn',
        ),
        const _NavItemSpec(
          page: AdminOrderListPage(),
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Đơn hàng',
        ),
        const _NavItemSpec(
          page: _OperationsHubPage(),
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune_rounded),
          label: 'Vận hành',
        ),
      ];
    }

    if (user.isChef) {
      return [
        const _NavItemSpec(
          page: KitchenDisplayPage(),
          icon: Icon(Icons.kitchen_outlined),
          selectedIcon: Icon(Icons.kitchen_rounded),
          label: 'Bếp KDS',
        ),
        const _NavItemSpec(
          page: HomePage(),
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu_rounded),
          label: 'Thực đơn',
        ),
        const _NavItemSpec(
          page: ProfilePage(),
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Tài khoản',
        ),
      ];
    }

    // WAITER default staff flow
    return [
      const _NavItemSpec(
        page: FloorTablePage(),
        icon: Icon(Icons.table_restaurant_outlined),
        selectedIcon: Icon(Icons.table_restaurant_rounded),
        label: 'Sơ đồ bàn',
      ),
      const _NavItemSpec(
        page: HomePage(),
        icon: Icon(Icons.restaurant_menu_outlined),
        selectedIcon: Icon(Icons.restaurant_menu_rounded),
        label: 'Thực đơn',
      ),
      _NavItemSpec(
        page: const CartPage(),
        icon: _cartBadgeIcon(false),
        selectedIcon: _cartBadgeIcon(true),
        label: 'Giỏ hàng',
      ),
      _NavItemSpec(
        page: const OrdersSyncPage(),
        icon: _syncBadgeIcon(false),
        selectedIcon: _syncBadgeIcon(true),
        label: 'Đồng bộ',
      ),
      const _NavItemSpec(
        page: ProfilePage(),
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Tài khoản',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserAccount?>(
      valueListenable: SessionManager.instance.currentUserNotifier,
      builder: (context, currentUser, _) {
        final roleKey = currentUser == null ? 'GUEST' : '${currentUser.accountId}:${currentUser.role}';
        if (_lastRoleKey != roleKey) {
          _lastRoleKey = roleKey;
          _currentIndex = 0;
        }
        final tabs = _buildTabsForRole(currentUser);
        final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: tabs.map((t) => t.page).toList(),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: tabs
                .map(
                  (t) => NavigationDestination(
                    icon: t.icon,
                    selectedIcon: t.selectedIcon,
                    label: t.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _OperationsHubPage extends StatelessWidget {
  const _OperationsHubPage();

  Color _getRoleColor(String role) {
    final r = role.toUpperCase();
    if (r == 'ADMIN') return const Color(0xFFDC2626);
    if (r == 'MANAGER') return const Color(0xFFD97706);
    if (r == 'CASHIER') return const Color(0xFF059669);
    if (r == 'WAITER') return const Color(0xFF0284C7);
    if (r == 'KITCHEN' || r.contains('CHEF') || r.contains('BARISTA')) return const Color(0xFF7C3AED);
    return const Color(0xFF64748B);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản hiện tại khỏi hệ thống POS?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SessionManager.instance.logout();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đăng xuất khỏi tài khoản.'), backgroundColor: Color(0xFF0F172A)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Trung tâm vận hành POS'),
        actions: [
          IconButton(
            tooltip: 'Tài khoản của tôi',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),
      body: ValueListenableBuilder<UserAccount?>(
        valueListenable: SessionManager.instance.currentUserNotifier,
        builder: (context, currentUser, _) {
          if (currentUser == null) return const LoginPage();

          final bool isAdminOrManager = currentUser.isAdmin || currentUser.isManager;
          final bool canAccessCashier = currentUser.isCashier || isAdminOrManager;
          final bool canAccessKitchen = currentUser.isKitchen || isAdminOrManager;

          void go(Widget page) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _getRoleColor(currentUser.role),
                            child: Text(
                              currentUser.fullName.isNotEmpty ? currentUser.fullName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(currentUser.role).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        currentUser.roleName,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getRoleColor(currentUser.role)),
                                      ),
                                    ),
                                    Text(
                                      '@${currentUser.username}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text('Đăng xuất'),
                            onPressed: () => _confirmLogout(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF0F172A)),
                            title: const Text('Thực đơn & Đặt món'),
                            subtitle: const Text('Xem danh sách món ăn, giá và thêm vào giỏ'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => go(const HomePage()),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.shopping_cart_checkout_outlined, color: Color(0xFF0284C7)),
                            title: const Text('Giỏ hàng & Tạo đơn nhanh'),
                            subtitle: const Text('Kiểm tra giỏ hàng cục bộ và thanh toán'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => go(const CartPage()),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.sync_rounded, color: Color(0xFFD97706)),
                            title: const Text('Hàng đợi đồng bộ đơn Offline'),
                            subtitle: const Text('Xem trạng thái SQLite / đẩy đơn còn tồn'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => go(const OrdersSyncPage()),
                          ),
                          if (canAccessCashier) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.lock_clock_outlined, color: Color(0xFF059669)),
                              title: const Text('Quản lý Ca làm việc & Z-Report'),
                              subtitle: const Text('Mở ca nhập float, kết ca đối soát két tiền'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => go(const ShiftManagementPage()),
                            ),
                          ],
                          if (canAccessKitchen) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.kitchen_outlined, color: Color(0xFF7C3AED)),
                              title: const Text('Màn hình bếp & pha chế (KDS)'),
                              subtitle: const Text('Tiếp nhận order & cập nhật chế biến'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => go(const KitchenDisplayPage()),
                            ),
                          ],
                          if (isAdminOrManager) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.category_outlined, color: Color(0xFF0F172A)),
                              title: const Text('Quản trị Danh mục món'),
                              subtitle: const Text('Thêm, sửa, xóa & upload ảnh danh mục'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => go(const AdminCategoryPage()),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F172A)),
                              title: const Text('Quản trị Sản phẩm & Hết món'),
                              subtitle: const Text('Thêm/sửa món, gallery ảnh & trạng thái bán'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => go(const AdminProductPage()),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFFDC2626)),
                              title: const Text('Quản trị Nhân sự & Vai trò (RBAC)'),
                              subtitle: const Text('Phân quyền và khóa/mở tài khoản'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => go(const AdminUserPage()),
                            ),
                          ],
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.badge_outlined, color: Color(0xFF475569)),
                            title: const Text('Hồ sơ cá nhân & Xác thực Email'),
                            subtitle: const Text('Cập nhật thông tin, xác thực OTP & đổi mật khẩu'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => go(const ProfilePage()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
    _syncService.unsyncedCountNotifier.addListener(_onQueueChanged);
  }

  void _onQueueChanged() {
    if (mounted) _loadOrders();
  }

  @override
  void dispose() {
    _syncService.unsyncedCountNotifier.removeListener(_onQueueChanged);
    super.dispose();
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
        backgroundColor: result.failed == 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deletePendingOrder(int id) async {
    await _dbHelper.deleteOfflineOrder(id);
    await _syncService.refreshUnsyncedCount();
    await _loadOrders();
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.3),
            ),
            Text(
              'Trạng thái đồng bộ hàng đợi cục bộ',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
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
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng: ${_offlineOrders.length} đơn hàng trong hàng đợi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tự động đồng bộ mỗi 45s khi có kết nối (có chống trùng Idempotency)',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                              child: const Icon(Icons.cloud_done_outlined, size: 48, color: Color(0xFF059669)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Không có đơn hàng chờ đồng bộ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                          final orderId = order['id'] as int;
                          final isSynced = order['is_synced'] == 1;
                          final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                          final customer = order['customer_name'] ?? 'Khách lẻ';
                          final tableId = order['table_id'];
                          final lastError = order['last_error']?.toString();
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
                                    : (lastError != null && lastError.isNotEmpty)
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFFCD34D),
                                width: isSynced ? 1 : 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isSynced ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isSynced ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                                          color: isSynced ? const Color(0xFF059669) : const Color(0xFFD97706),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  'Đơn #$orderId',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    tableId != null ? 'Bàn #$tableId' : 'Mang về',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Khách: $customer${createdAt != null ? ' • ${DateFormat('HH:mm dd/MM').format(createdAt)}' : ''}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currencyFormatter.format(totalAmount),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSynced ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isSynced ? 'Đã đồng bộ' : 'Chờ đồng bộ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isSynced ? const Color(0xFF059669) : const Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (!isSynced && lastError != null && lastError.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              lastError,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (!isSynced) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _deletePendingOrder(orderId),
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                          label: const Text('Xóa đơn chờ', style: TextStyle(color: Color(0xFFDC2626))),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: _triggerSync,
                                          icon: const Icon(Icons.sync, size: 16),
                                          label: const Text('Thử đồng bộ'),
                                        ),
                                      ],
                                    ),
                                  ],
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

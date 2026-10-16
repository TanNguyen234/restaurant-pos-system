import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/offline_sync_service.dart';
import 'utils/database_helper.dart';
import 'views/category_page.dart';
import 'views/table/floor_table_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    );
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
    CategoryPage(title: 'Thực đơn & Danh mục'),
    OrdersSyncPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Thực đơn',
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
              'Hàng đợi lưu trữ SQLite cục bộ',
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
                      const Text(
                        'Trạng thái đồng bộ hàng đợi SQLite',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<int>(
                        valueListenable: _syncService.unsyncedCountNotifier,
                        builder: (context, count, _) {
                          return Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: count == 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                count == 0
                                    ? 'Tất cả đơn hàng đã được gửi lên máy chủ'
                                    : '$count đơn hàng chưa đồng bộ',
                                style: TextStyle(
                                  color: count == 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _syncService.isSyncingNotifier,
                  builder: (context, isSyncing, _) {
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSyncing ? null : _triggerSync,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        isSyncing ? 'Đang gửi...' : 'Đồng bộ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
                                Icons.receipt_long_rounded,
                                size: 52,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Chưa có đơn hàng ngoại tuyến nào trong SQLite',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _offlineOrders.length,
                        itemBuilder: (context, index) {
                          final order = _offlineOrders[index];
                          final isSynced = (order['is_synced'] as int? ?? 0) == 1;
                          final total = (order['total_amount'] as num? ?? 0).toDouble();

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSynced
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
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
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_rounded,
                                  color: isSynced
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                'Đơn #${order['id']} - ${order['customer_name'] ?? 'Khách lẻ'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Bàn: ${order['table_id'] ?? 'Mang về'} • ${order['created_at'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormatter.format(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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

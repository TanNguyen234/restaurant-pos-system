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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E342E), // Deep Coffee Brown
          primary: const Color(0xFF4E342E),
          secondary: const Color(0xFFFF8F00), // Amber Gold
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 2,
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
            selectedIcon: Icon(Icons.table_restaurant),
            label: 'Sơ đồ bàn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
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
                  backgroundColor: Colors.amber.shade800,
                  child: const Icon(Icons.sync_outlined),
                );
              },
            ),
            selectedIcon: const Icon(Icons.sync),
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
            ? Colors.green.shade800
            : Colors.orange.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Đơn hàng & Đồng bộ ngoại tuyến',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Sync Controller Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.brown.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trạng thái đồng bộ hàng đợi SQLite',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<int>(
                        valueListenable: _syncService.unsyncedCountNotifier,
                        builder: (context, count, _) {
                          return Text(
                            count == 0
                                ? 'Tất cả đơn hàng đã được gửi lên máy chủ'
                                : '$count đơn hàng chưa đồng bộ',
                            style: TextStyle(
                              color: count == 0
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFEF6C00),
                              fontWeight: FontWeight.w600,
                            ),
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
                        backgroundColor: Colors.brown.shade700,
                        foregroundColor: Colors.white,
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
                          : const Icon(Icons.cloud_upload),
                      label: Text(isSyncing ? 'Đang gửi...' : 'Đồng bộ'),
                    );
                  },
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _offlineOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có đơn hàng ngoại tuyến nào trong SQLite',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _offlineOrders.length,
                        itemBuilder: (context, index) {
                          final order = _offlineOrders[index];
                          final isSynced = (order['is_synced'] as int? ?? 0) == 1;
                          final total = (order['total_amount'] as num? ?? 0).toDouble();

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSynced
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                child: Icon(
                                  isSynced ? Icons.check_circle : Icons.schedule,
                                  color: isSynced
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFEF6C00),
                                ),
                              ),
                              title: Text(
                                'Đơn #${order['id']} - ${order['customer_name'] ?? 'Khách lẻ'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Bàn: ${order['table_id'] ?? 'Mang về'} | ${order['created_at'] ?? ''}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormatter.format(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown,
                                    ),
                                  ),
                                  Text(
                                    isSynced ? 'Đã đồng bộ' : 'Chờ đồng bộ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSynced
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFEF6C00),
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

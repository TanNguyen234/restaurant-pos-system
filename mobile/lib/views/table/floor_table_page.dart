import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../models/dining_table.dart';
import '../../repositories/table_repository.dart';
import '../../services/offline_sync_service.dart';

class FloorTablePage extends StatefulWidget {
  const FloorTablePage({super.key});

  @override
  State<FloorTablePage> createState() => _FloorTablePageState();
}

class _FloorTablePageState extends State<FloorTablePage>
    with SingleTickerProviderStateMixin {
  List<Area> _areas = [];
  List<DiningTable> _allTables = [];
  bool _isLoading = true;
  TabController? _tabController;
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    _syncService.initialize();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final areas = await TableRepository.getAreas();
      final tables = await TableRepository.getAllTables();

      if (!mounted) return;

      // Update TabController if areas changed
      if (_tabController == null || _tabController!.length != areas.length) {
        _tabController?.dispose();
        _tabController = TabController(length: areas.length, vsync: this);
      }

      setState(() {
        _areas = areas;
        _allTables = tables;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTableStatus(DiningTable table, int newStatus) async {
    final success = await TableRepository.updateStatus(table.id, newStatus);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật trạng thái ${table.name} thành "${newStatus == 0 ? "Trống" : newStatus == 1 ? "Có khách" : "Đã đặt trước"}".',
          ),
          backgroundColor: Colors.brown.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật trạng thái bàn.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleTableTransfer(DiningTable sourceTable) async {
    // Chỉ lấy các bàn đang trống (status == 0) và khác bàn hiện tại
    final availableTables = _allTables
        .where((t) => t.status == 0 && t.id != sourceTable.id)
        .toList();

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có bàn trống nào để chuyển đến!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    DiningTable? selectedTarget = availableTables.first;

    final targetTable = await showDialog<DiningTable>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.brown),
                  const SizedBox(width: 8),
                  const Text('Chuyển bàn ăn'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bàn chuyển đi: ${sourceTable.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn bàn trống chuyển đến:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DiningTable>(
                        isExpanded: true,
                        value: selectedTarget,
                        items: availableTables.map((t) {
                          final area = _areas.firstWhere(
                            (a) => a.id == t.areaId,
                            orElse: () => Area(id: 0, name: 'Khác'),
                          );
                          return DropdownMenuItem<DiningTable>(
                            value: t,
                            child: Text(
                              '${t.name} (${t.capacity} ghế - ${area.name})',
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTarget = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, selectedTarget),
                  child: const Text('Xác nhận chuyển'),
                ),
              ],
            );
          },
        );
      },
    );

    if (targetTable == null || !mounted) return;

    final success = await TableRepository.transferTable(
      sourceTable.id,
      targetTable.id,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chuyển từ ${sourceTable.name} sang ${targetTable.name} thành công!',
          ),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chuyển bàn thất bại. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTableActionSheet(DiningTable table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with table name and status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sức chứa: ${table.capacity} khách',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: table.statusBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: table.statusColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(table.statusIcon, color: table.statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            table.statusText,
                            style: TextStyle(
                              color: table.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Table quick action list
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.edit_note, color: Color(0xFF2E7D32)),
                  ),
                  title: const Text('Đổi trạng thái bàn'),
                  subtitle: const Text('Trống (Xanh), Có khách (Đỏ), Đặt trước (Cam)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _showChangeStatusDialog(table);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.swap_horiz, color: Color(0xFFEF6C00)),
                  ),
                  title: const Text('Chuyển bàn ăn'),
                  subtitle: const Text('Chuyển khách và đơn sang bàn trống khác'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _handleTableTransfer(table);
                  },
                ),
                if (table.status == 1) ...[
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(Icons.check_circle, color: Color(0xFFC62828)),
                    ),
                    title: const Text('Trả bàn / Đón khách mới'),
                    subtitle: const Text('Chuyển bàn về trạng thái Trống'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _updateTableStatus(table, 0);
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangeStatusDialog(DiningTable table) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Đổi trạng thái: ${table.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption(
                dialogCtx,
                table,
                status: 0,
                title: 'Bàn trống (Available)',
                color: const Color(0xFF2E7D32),
                icon: Icons.check_circle_outline,
              ),
              _buildStatusOption(
                dialogCtx,
                table,
                status: 1,
                title: 'Có khách (Occupied)',
                color: const Color(0xFFC62828),
                icon: Icons.restaurant,
              ),
              _buildStatusOption(
                dialogCtx,
                table,
                status: 2,
                title: 'Đã đặt trước / Chờ phục vụ',
                color: const Color(0xFFEF6C00),
                icon: Icons.bookmark_border,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusOption(
    BuildContext ctx,
    DiningTable table, {
    required int status,
    required String title,
    required Color color,
    required IconData icon,
  }) {
    final isCurrent = table.status == status;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: isCurrent ? color : Colors.black87,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isCurrent ? Icon(Icons.check, color: color) : null,
      onTap: () {
        Navigator.pop(ctx);
        if (!isCurrent) {
          _updateTableStatus(table, status);
        }
      },
    );
  }

  void _showSyncStatusDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cloud_sync, color: Colors.brown),
              const SizedBox(width: 8),
              const Text('Đồng bộ ngoại tuyến'),
            ],
          ),
          content: ValueListenableBuilder<int>(
            valueListenable: _syncService.unsyncedCountNotifier,
            builder: (context, count, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 0
                        ? 'Tất cả đơn hàng ngoại tuyến đã được đồng bộ với máy chủ.'
                        : 'Hiện có $count đơn hàng ngoại tuyến đang chờ gửi lên máy chủ.',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: _syncService.isSyncingNotifier,
                    builder: (context, isSyncing, _) {
                      if (isSyncing) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade700,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Đồng bộ ngay'),
              onPressed: () async {
                final result = await _syncService.syncNow();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.failed == 0
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBar() {
    final available = _allTables.where((t) => t.status == 0).length;
    final occupied = _allTables.where((t) => t.status == 1).length;
    final reserved = _allTables.where((t) => t.status == 2).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.brown.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryChip('Tổng bàn: ${_allTables.length}', Colors.brown.shade800),
          _buildSummaryChip('Trống: $available', const Color(0xFF2E7D32)),
          _buildSummaryChip('Có khách: $occupied', const Color(0xFFC62828)),
          _buildSummaryChip('Đặt trước: $reserved', const Color(0xFFEF6C00)),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTableGrid(int areaId) {
    final areaTables = _allTables.where((t) => t.areaId == areaId).toList();

    if (areaTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Chưa có bàn nào trong khu vực này',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.15,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: areaTables.length,
          itemBuilder: (context, index) {
            final table = areaTables[index];
            return _buildTableCard(table);
          },
        );
      },
    );
  }

  Widget _buildTableCard(DiningTable table) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: table.statusColor.withAlpha(120),
          width: 1.5,
        ),
      ),
      color: table.statusBackgroundColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTableActionSheet(table),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Table name & Status icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      table.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(table.statusIcon, color: table.statusColor, size: 20),
                ],
              ),

              // Middle: Capacity
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '${table.capacity} ghế',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (table.currentOrderId != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${table.currentOrderId}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Bottom: Status badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: table.statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    table.statusText.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sơ đồ Bàn ăn (Floor Plan)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Unsynced offline orders indicator
          ValueListenableBuilder<int>(
            valueListenable: _syncService.unsyncedCountNotifier,
            builder: (context, count, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_queue),
                    tooltip: 'Đồng bộ đơn ngoại tuyến',
                    onPressed: _showSyncStatusDialog,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
        bottom: _areas.isNotEmpty && _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.amber,
                indicatorWeight: 3,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.white70,
                tabs: _areas
                    .map((area) => Tab(text: area.name))
                    .toList(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _areas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Không thể tải danh sách khu vực bàn ăn.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSummaryBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: TabBarView(
                          controller: _tabController,
                          children: _areas
                              .map((area) => _buildTableGrid(area.id))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

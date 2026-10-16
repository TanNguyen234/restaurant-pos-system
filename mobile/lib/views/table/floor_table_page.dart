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
      final statusName = newStatus == 0
          ? 'Trống'
          : newStatus == 1
              ? 'Có khách'
              : 'Đã đặt trước';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật trạng thái ${table.name} thành "$statusName".'),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể cập nhật trạng thái bàn.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleTableTransfer(DiningTable sourceTable) async {
    final availableTables = _allTables
        .where((t) => t.status == 0 && t.id != sourceTable.id)
        .toList();

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không có bàn trống nào để chuyển đến!'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: Color(0xFF0F172A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Chuyển bàn ăn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.table_restaurant_outlined,
                          size: 18,
                          color: Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bàn chuyển đi: ${sourceTable.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn bàn trống chuyển đến:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DiningTable>(
                        isExpanded: true,
                        value: selectedTarget,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F172A)),
                        items: availableTables.map((t) {
                          final area = _areas.firstWhere(
                            (a) => a.id == t.areaId,
                            orElse: () => Area(id: 0, name: 'Khác'),
                          );
                          return DropdownMenuItem<DiningTable>(
                            value: t,
                            child: Text(
                              '${t.name} (${t.capacity} ghế - ${area.name})',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, selectedTarget),
                  child: const Text(
                    'Xác nhận chuyển',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chuyển bàn thất bại. Vui lòng thử lại.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showTableActionSheet(DiningTable table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: table.status == 0
                                ? const Color(0xFFECFDF5)
                                : table.status == 1
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: table.status == 0
                                  ? const Color(0xFFA7F3D0)
                                  : table.status == 1
                                      ? const Color(0xFFFECACA)
                                      : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Icon(
                            Icons.table_restaurant_rounded,
                            color: table.status == 0
                                ? const Color(0xFF059669)
                                : table.status == 1
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              table.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Sức chứa: ${table.capacity} khách',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildStatusPill(table.status),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFF0F9FF),
                  title: 'Đổi trạng thái bàn',
                  subtitle: 'Trống, Đang có khách, Đã đặt trước',
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _showChangeStatusDialog(table);
                  },
                ),
                _buildActionTile(
                  icon: Icons.swap_horiz_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFFBEB),
                  title: 'Chuyển bàn ăn',
                  subtitle: 'Chuyển khách và đơn sang bàn trống khác',
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _handleTableTransfer(table);
                  },
                ),
                if (table.status == 1) ...[
                  _buildActionTile(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    title: 'Trả bàn / Đón khách mới',
                    subtitle: 'Chuyển bàn về trạng thái Trống',
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _updateTableStatus(table, 0);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showChangeStatusDialog(DiningTable table) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          title: Text(
            'Đổi trạng thái: ${table.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption(
                dialogCtx,
                table,
                status: 0,
                title: 'Bàn trống',
                subtitle: 'Sẵn sàng xếp chỗ đón khách',
                color: const Color(0xFF059669),
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 8),
              _buildStatusOption(
                dialogCtx,
                table,
                status: 1,
                title: 'Có khách',
                subtitle: 'Khách đang ngồi dùng bữa / gọi món',
                color: const Color(0xFFDC2626),
                icon: Icons.restaurant,
              ),
              const SizedBox(height: 8),
              _buildStatusOption(
                dialogCtx,
                table,
                status: 2,
                title: 'Đã đặt trước',
                subtitle: 'Khách hẹn giờ trước giữ chỗ',
                color: const Color(0xFFD97706),
                icon: Icons.bookmark_border,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
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
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    final isCurrent = table.status == status;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        if (!isCurrent) {
          _updateTableStatus(table, status);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? color : const Color(0xFFE2E8F0),
            width: isCurrent ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrent ? color.withValues(alpha: 0.15) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isCurrent ? color : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_circle_rounded, color: color, size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  void _showSyncStatusDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync,
                  color: Color(0xFF0F172A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Đồng bộ ngoại tuyến',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
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
                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
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
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: isCompact ? WrapAlignment.start : WrapAlignment.spaceBetween,
            children: [
              _buildSummaryCard(
                label: 'Tổng bàn: ${_allTables.length}',
                count: '${_allTables.length}',
                title: 'Tổng bàn',
                icon: Icons.grid_view_rounded,
                color: const Color(0xFF334155),
                bgColor: const Color(0xFFF1F5F9),
              ),
              _buildSummaryCard(
                label: 'Trống: $available',
                count: '$available',
                title: 'Trống',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
              _buildSummaryCard(
                label: 'Có khách: $occupied',
                count: '$occupied',
                title: 'Có khách',
                icon: Icons.restaurant_rounded,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
              ),
              _buildSummaryCard(
                label: 'Đặt trước: $reserved',
                count: '$reserved',
                title: 'Đặt trước',
                icon: Icons.event_seat_rounded,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String count,
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(int status) {
    Color bg;
    Color fg;
    Color dot;
    String text;

    switch (status) {
      case 0:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        dot = const Color(0xFF10B981);
        text = 'TRỐNG';
        break;
      case 1:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        dot = const Color(0xFFEF4444);
        text = 'CÓ KHÁCH';
        break;
      case 2:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        dot = const Color(0xFFF59E0B);
        text = 'ĐÃ ĐẶT';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        dot = const Color(0xFF94A3B8);
        text = 'KHÁC';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant,
                size: 56,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có bàn nào trong khu vực này',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thêm bàn mới hoặc chọn khu vực khác',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 900 ? 4 : width > 600 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.15,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
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
    Color borderColor;
    Color glowColor;
    Color actionBg;
    Color actionFg;
    IconData actionIcon;
    String actionLabel;

    switch (table.status) {
      case 0:
        borderColor = const Color(0xFF10B981);
        glowColor = const Color(0x1010B981);
        actionBg = const Color(0xFFECFDF5);
        actionFg = const Color(0xFF047857);
        actionIcon = Icons.add_circle_outline_rounded;
        actionLabel = 'Mở bàn';
        break;
      case 1:
        borderColor = const Color(0xFFEF4444);
        glowColor = const Color(0x15EF4444);
        actionBg = const Color(0xFFFEF2F2);
        actionFg = const Color(0xFFB91C1C);
        actionIcon = Icons.receipt_long_rounded;
        actionLabel = 'Xem đơn';
        break;
      case 2:
        borderColor = const Color(0xFFF59E0B);
        glowColor = const Color(0x12F59E0B);
        actionBg = const Color(0xFFFFFBEB);
        actionFg = const Color(0xFFB45309);
        actionIcon = Icons.check_circle_outline_rounded;
        actionLabel = 'Nhận bàn';
        break;
      default:
        borderColor = const Color(0xFF94A3B8);
        glowColor = Colors.transparent;
        actionBg = const Color(0xFFF1F5F9);
        actionFg = const Color(0xFF475569);
        actionIcon = Icons.info_outline;
        actionLabel = 'Chi tiết';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTableActionSheet(table),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        table.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusPill(table.status),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${table.capacity} chỗ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    if (table.currentOrderId != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          '#HD-${table.currentOrderId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: actionBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(actionIcon, size: 14, color: actionFg),
                      const SizedBox(width: 4),
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: actionFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sơ đồ bàn ăn',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
            const Text(
              'Hệ thống quản lý dịch vụ phòng bàn',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _syncService.unsyncedCountNotifier,
            builder: (context, count, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_queue_rounded),
                    tooltip: 'Đồng bộ đơn ngoại tuyến',
                    onPressed: _showSyncStatusDialog,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
          const SizedBox(width: 6),
        ],
        bottom: _areas.isNotEmpty && _tabController != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    indicator: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: _areas
                        .map((area) => Tab(text: area.name))
                        .toList(),
                  ),
                ),
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không thể tải danh sách khu vực bàn ăn.',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Thử lại'),
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
                        color: const Color(0xFF0F172A),
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

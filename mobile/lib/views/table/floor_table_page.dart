import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../models/dining_table.dart';
import '../../repositories/table_repository.dart';
import '../../services/offline_sync_service.dart';
import '../order/order_checkout_page.dart';

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

  Future<void> _handleTableMerge(DiningTable sourceTable) async {
    final targetCandidates = _allTables
        .where((t) => t.status == 1 && t.id != sourceTable.id)
        .toList();

    if (targetCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không có bàn đang có khách nào khác để gộp vào!'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    DiningTable? selectedTarget = targetCandidates.first;

    final targetTable = await showDialog<DiningTable>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.merge_type_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Gộp bàn ăn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gộp tất cả món ăn & hóa đơn từ "${sourceTable.name}" vào bàn đích:',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DiningTable>(
                        value: selectedTarget,
                        isExpanded: true,
                        items: targetCandidates.map((t) {
                          return DropdownMenuItem<DiningTable>(
                            value: t,
                            child: Text('${t.name} (Sức chứa ${t.capacity} khách)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedTarget = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, selectedTarget),
                  child: const Text('Xác nhận gộp bàn', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (targetTable == null || !mounted) return;

    final result = await TableRepository.mergeTables(sourceTable.id, targetTable.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Gộp bàn thành công!' : 'Gộp bàn thất bại')),
        backgroundColor: result['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (result['success'] == true) {
      await _loadData();
    }
  }

  Future<void> _handleTableSplit(DiningTable sourceTable) async {
    final emptyTables = _allTables.where((t) => t.status == 0 && t.id != sourceTable.id).toList();
    if (emptyTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không có bàn trống nào để tách món sang!'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final activeOrder = await TableRepository.getActiveOrderByTable(sourceTable.id);
    if (activeOrder == null || activeOrder['details'] == null || (activeOrder['details'] as List).isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bàn không có món ăn nào trong đơn hiện tại để tách!'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final details = (activeOrder['details'] as List).cast<Map<String, dynamic>>();
    final selectedDetailIds = <int>{};
    DiningTable? selectedTarget = emptyTables.first;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.call_split_rounded, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Tách bàn / Tách đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chọn các món muốn tách từ "${sourceTable.name}" sang bàn mới:',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: details.length,
                        itemBuilder: (context, index) {
                          final item = details[index];
                          final id = item['orderDetailId'] as int? ?? item['id'] as int? ?? 0;
                          final name = item['productName']?.toString() ?? 'Món ăn';
                          final qty = item['quantity'] ?? 1;
                          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                          final isChecked = selectedDetailIds.contains(id);

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('$name x$qty', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(price * (qty as num))),
                            value: isChecked,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedDetailIds.add(id);
                                } else {
                                  selectedDetailIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),
                    const Text('Chọn bàn trống đích để tách sang:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DiningTable>(
                          value: selectedTarget,
                          isExpanded: true,
                          items: emptyTables.map((t) {
                            return DropdownMenuItem<DiningTable>(
                              value: t,
                              child: Text('${t.name} (Bàn trống • Sức chứa ${t.capacity})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedTarget = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: selectedDetailIds.isEmpty
                      ? null
                      : () => Navigator.pop(dialogCtx, true),
                  child: const Text('Tách bàn ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted || selectedTarget == null) return;

    final result = await TableRepository.splitTable(sourceTable.id, selectedTarget!.id, selectedDetailIds.toList());
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Tách bàn thành công!' : 'Tách bàn thất bại')),
        backgroundColor: result['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (result['success'] == true) {
      await _loadData();
    }
  }

  Future<void> _handleTableReservation(DiningTable table) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final guestCtrl = TextEditingController(text: table.capacity.toString());
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bookmark_add_outlined, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Đặt trước ${table.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Họ tên khách hàng *', hintText: 'VD: Anh Tuấn'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Số điện thoại *', hintText: 'VD: 0987654321'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: guestCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số lượng khách', hintText: '2'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Ghi chú', hintText: 'VD: Chuẩn bị ghế trẻ em'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập họ tên và số điện thoại!')),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Xác nhận đặt bàn', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final guestCount = int.tryParse(guestCtrl.text) ?? table.capacity;
    final result = await TableRepository.reserveTable(
      tableId: table.id,
      customerName: nameCtrl.text.trim(),
      phoneNumber: phoneCtrl.text.trim(),
      guestCount: guestCount,
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (result['success'] == true ? 'Đặt bàn thành công!' : 'Đặt bàn thất bại')),
        backgroundColor: result['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (result['success'] == true) {
      await _loadData();
    }
  }

  Future<void> _handleCheckInReservation(DiningTable table) async {
    final success = await TableRepository.updateStatus(table.id, 1);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận bàn ${table.name} thành công. Chuyển sang trạng thái Có khách.'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      await _loadData();
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
          child: SingleChildScrollView(
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
                  icon: Icons.restaurant_menu_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFECFDF5),
                  title: 'Gọi món / Đặt món cho bàn',
                  subtitle: 'Tạo đơn hàng F&B cho ${table.name}',
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderCheckoutPage(
                          preSelectedTableId: table.id,
                          preSelectedTableName: table.name,
                        ),
                      ),
                    );
                  },
                ),
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
                if (table.status == 1) ...[
                  _buildActionTile(
                    icon: Icons.merge_type_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF3E8FF),
                    title: 'Gộp bàn',
                    subtitle: 'Gộp hóa đơn bàn này vào bàn có khách khác',
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _handleTableMerge(table);
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.call_split_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFF0F9FF),
                    title: 'Tách bàn / Tách đơn',
                    subtitle: 'Chuyển một số món sang bàn trống mới',
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _handleTableSplit(table);
                    },
                  ),
                ],
                if (table.status == 0) ...[
                  _buildActionTile(
                    icon: Icons.bookmark_add_outlined,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFFFBEB),
                    title: 'Đặt bàn trước',
                    subtitle: 'Lưu thông tin khách đặt bàn & giờ đến',
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _handleTableReservation(table);
                    },
                  ),
                ],
                if (table.status == 2) ...[
                  _buildActionTile(
                    icon: Icons.how_to_reg_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    title: 'Khách đến nhận bàn',
                    subtitle: 'Chuyển bàn sang trạng thái Có khách',
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _handleCheckInReservation(table);
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.cancel_outlined,
                    iconColor: const Color(0xFFDC2626),
                    iconBg: const Color(0xFFFEF2F2),
                    title: 'Hủy đặt bàn',
                    subtitle: 'Chuyển bàn về trạng thái Trống',
                    onTap: () {
                      Navigator.pop(bottomSheetCtx);
                      _updateTableStatus(table, 0);
                    },
                  ),
                ],
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
            childAspectRatio: 1.0,
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
                if (table.status == 1) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFE11D48)),
                            const SizedBox(width: 3),
                            Text(
                              table.seatingDurationText.isNotEmpty ? table.seatingDurationText : '<1p',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE11D48)),
                            ),
                          ],
                        ),
                        if (table.runningTotal > 0)
                          Text(
                            NumberFormat.compactCurrency(locale: 'vi_VN', symbol: 'đ').format(table.runningTotal),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBE123C)),
                          ),
                      ],
                    ),
                  ),
                ],
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
            icon: const Icon(Icons.table_restaurant_outlined),
            tooltip: 'Quản lý bàn & Khu vực',
            onPressed: _showTableAreaManagerModal,
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

  void _showTableAreaManagerModal() {
    final newTableNameController = TextEditingController();
    final newCapacityController = TextEditingController(text: '4');
    int selectedAreaId = _areas.isNotEmpty ? _areas.first.id : 1;

    final newAreaNameController = TextEditingController();
    final newSortOrderController = TextEditingController(text: (_areas.length + 1).toString());
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Color(0xFF0F172A), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quản lý Phòng Bàn & Khu Vực', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Thêm bàn mới, sửa đổi và quản lý sơ đồ F&B', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const TabBar(
                      labelColor: Color(0xFF0F172A),
                      unselectedLabelColor: Color(0xFF94A3B8),
                      indicatorColor: Color(0xFF0F172A),
                      labelStyle: TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(icon: Icon(Icons.table_bar_outlined, size: 20), text: 'Bàn ăn'),
                        Tab(icon: Icon(Icons.layers_outlined, size: 20), text: 'Khu vực'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Quản lý Bàn
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Thêm bàn mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: newTableNameController,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                labelText: 'Tên bàn (*)',
                                                hintText: 'Bàn 10, VIP 1...',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: TextField(
                                              controller: newCapacityController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                labelText: 'Số chỗ',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              isDense: true,
                                              initialValue: selectedAreaId,
                                              decoration: const InputDecoration(
                                                labelText: 'Khu vực',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: _areas.map((a) {
                                                return DropdownMenuItem<int>(
                                                  value: a.id,
                                                  child: Text(a.name),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) selectedAreaId = val;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F172A),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: isSubmitting
                                                ? null
                                                : () async {
                                                    final name = newTableNameController.text.trim();
                                                    final cap = int.tryParse(newCapacityController.text.trim()) ?? 4;
                                                    if (name.isEmpty) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Vui lòng nhập tên bàn')),
                                                      );
                                                      return;
                                                    }
                                                    setModalState(() => isSubmitting = true);
                                                    final res = await TableRepository.createTable(
                                                      areaId: selectedAreaId,
                                                      tableName: name,
                                                      capacity: cap,
                                                    );
                                                    setModalState(() => isSubmitting = false);
                                                    if (res['success'] == true) {
                                                      if (ctx.mounted) Navigator.pop(ctx);
                                                      await _loadData();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Thành công'), backgroundColor: const Color(0xFF10B981)),
                                                        );
                                                      }
                                                    } else {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Thất bại'), backgroundColor: const Color(0xFFEF4444)),
                                                        );
                                                      }
                                                    }
                                                  },
                                            child: const Text('Thêm'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text('Danh sách bàn ăn hiện tại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _allTables.length,
                                    separatorBuilder: (itemCtx, index) => const Divider(height: 1),
                                    itemBuilder: (itemCtx, index) {
                                      final t = _allTables[index];
                                      final area = _areas.firstWhere((a) => a.id == t.areaId, orElse: () => Area(id: 0, name: 'Khác', sortOrder: 0));
                                      final canDelete = t.status == 0 && t.currentOrderId == null;

                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: t.statusColor.withValues(alpha: 0.15),
                                          child: Icon(t.statusIcon, size: 16, color: t.statusColor),
                                        ),
                                        title: Text('${t.name} (${t.capacity} chỗ)', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text('${area.name} • ${t.statusText}', style: const TextStyle(fontSize: 12)),
                                        trailing: canDelete
                                            ? IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                                tooltip: 'Xóa bàn trống này',
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text('Xác nhận xóa bàn'),
                                                      content: Text('Bạn có chắc muốn xóa bàn "${t.name}" không?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                                          onPressed: () => Navigator.pop(c, true),
                                                          child: const Text('Xóa'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    final res = await TableRepository.deleteTable(t.id);
                                                    if (res['success'] == true) {
                                                      if (ctx.mounted) Navigator.pop(ctx);
                                                      await _loadData();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Đã xóa bàn'), backgroundColor: const Color(0xFF10B981)),
                                                        );
                                                      }
                                                    } else {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Không thể xóa'), backgroundColor: const Color(0xFFEF4444)),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tab 2: Quản lý Khu vực
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Thêm khu vực mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              controller: newAreaNameController,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                labelText: 'Tên khu vực (*)',
                                                hintText: 'Tầng 1, Sân vườn, VIP...',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: TextField(
                                              controller: newSortOrderController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                labelText: 'Thứ tự',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F172A),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: isSubmitting
                                                ? null
                                                : () async {
                                                    final name = newAreaNameController.text.trim();
                                                    final sort = int.tryParse(newSortOrderController.text.trim()) ?? 0;
                                                    if (name.isEmpty) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Vui lòng nhập tên khu vực')),
                                                      );
                                                      return;
                                                    }
                                                    setModalState(() => isSubmitting = true);
                                                    final res = await TableRepository.createArea(
                                                      areaName: name,
                                                      sortOrder: sort,
                                                    );
                                                    setModalState(() => isSubmitting = false);
                                                    if (res['success'] == true) {
                                                      if (ctx.mounted) Navigator.pop(ctx);
                                                      await _loadData();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Thành công'), backgroundColor: const Color(0xFF10B981)),
                                                        );
                                                      }
                                                    } else {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Thất bại'), backgroundColor: const Color(0xFFEF4444)),
                                                        );
                                                      }
                                                    }
                                                  },
                                            child: const Text('Thêm'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text('Danh sách khu vực hiện tại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _areas.length,
                                    separatorBuilder: (itemCtx, index) => const Divider(height: 1),
                                    itemBuilder: (itemCtx, index) {
                                      final a = _areas[index];
                                      final tableCount = _allTables.where((t) => t.areaId == a.id).length;
                                      final canDelete = tableCount == 0;

                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
                                          child: Text('${a.sortOrder}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12)),
                                        ),
                                        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text('$tableCount bàn ăn thuộc khu vực này', style: const TextStyle(fontSize: 12)),
                                        trailing: canDelete
                                            ? IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                                tooltip: 'Xóa khu vực rỗng',
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text('Xác nhận xóa khu vực'),
                                                      content: Text('Bạn có chắc muốn xóa khu vực "${a.name}" không?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                                          onPressed: () => Navigator.pop(c, true),
                                                          child: const Text('Xóa'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    final res = await TableRepository.deleteArea(a.id);
                                                    if (res['success'] == true) {
                                                      if (ctx.mounted) Navigator.pop(ctx);
                                                      await _loadData();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Đã xóa khu vực'), backgroundColor: const Color(0xFF10B981)),
                                                        );
                                                      }
                                                    } else {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(res['message'] ?? 'Không thể xóa'), backgroundColor: const Color(0xFFEF4444)),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

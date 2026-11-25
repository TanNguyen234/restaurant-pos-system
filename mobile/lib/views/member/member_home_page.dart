import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../models/dining_table.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/table_repository.dart';
import '../../services/session_manager.dart';
import '../auth/login_page.dart';
import '../auth/profile_page.dart';
import '../order/order_checkout_page.dart';
import '../order/order_detail_page.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final _searchQueryController = TextEditingController();
  final _orderRepo = OrderRepository();

  bool _isLoadingLoyalty = true;
  String? _loyaltyError;
  int _userPoints = 0;
  String _tierLabel = 'THÀNH VIÊN';
  List<Map<String, dynamic>> _vouchers = [];
  Set<String> _redeemedVoucherCodes = {};
  List<Map<String, dynamic>> _history = [];

  List<OrderModel> _foundOrders = [];
  bool _isSearchingOrders = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadLoyaltyData();
  }

  @override
  void dispose() {
    _searchQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadLoyaltyData() async {
    setState(() {
      _isLoadingLoyalty = true;
      _loyaltyError = null;
    });

    final user = SessionManager.instance.currentUser;
    if (user == null) {
      // Khách vãng lai: chỉ tải danh sách voucher công khai
      try {
        final res = await ApiConfig.get(Uri.parse('${ApiConfig.baseUrl}/api/discount/active')).timeout(const Duration(seconds: 6));
        if (!mounted) return;
        if (res.statusCode == 200) {
          final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final raw = (body['data'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          setState(() {
            _vouchers = raw;
            _userPoints = 0;
            _tierLabel = 'KHÁCH VÃNG LAI';
            _isLoadingLoyalty = false;
          });
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isLoadingLoyalty = false);
      return;
    }

    try {
      final res = await ApiConfig.get(Uri.parse('${ApiConfig.baseUrl}/api/loyalty/me')).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final data = Map<String, dynamic>.from(body['data'] as Map);
        setState(() {
          _userPoints = (data['loyaltyPoints'] as num? ?? 0).toInt();
          _tierLabel = (data['tier'] ?? 'THÀNH VIÊN').toString();
          _vouchers = (data['availableVouchers'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          _redeemedVoucherCodes = (data['redeemedVoucherCodes'] as List? ?? []).map((e) => e.toString().toUpperCase()).toSet();
          _history = (data['history'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoadingLoyalty = false;
        });
      } else {
        setState(() {
          _loyaltyError = 'Không tải được dữ liệu hội viên (HTTP ${res.statusCode})';
          _isLoadingLoyalty = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loyaltyError = 'Lỗi kết nối máy chủ hội viên: $e';
        _isLoadingLoyalty = false;
      });
    }
  }

  Future<void> _redeemVoucher(Map<String, dynamic> voucher) async {
    final user = SessionManager.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập tài khoản để đổi điểm lấy voucher!')),
      );
      return;
    }

    final code = (voucher['code'] ?? '').toString();
    final cost = (voucher['pointsCost'] as num? ?? 0).toInt();
    if (_userPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn cần thêm ${cost - _userPoints} PTS để đổi mã "$code"'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đổi Voucher $code'),
        content: Text('Sử dụng $cost PTS để đổi mã ưu đãi "${voucher['title'] ?? code}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận đổi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final res = await ApiConfig.post(
        Uri.parse('${ApiConfig.baseUrl}/api/loyalty/redeem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (res.statusCode == 200 && data['success'] == true) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Đổi voucher thành công!'), backgroundColor: const Color(0xFF059669)),
        );
        await _loadLoyaltyData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Không thể đổi voucher'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối khi đổi điểm: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  Future<void> _searchOrders() async {
    final query = _searchQueryController.text.trim();
    if (SessionManager.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để tra cứu lịch sử đơn hàng')),
      );
      return;
    }

    setState(() {
      _isSearchingOrders = true;
      _hasSearched = true;
    });
    try {
      final list = await _orderRepo.lookupOrders(query);
      if (!mounted) return;
      setState(() {
        _foundOrders = list;
        _isSearchingOrders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _foundOrders = [];
        _isSearchingOrders = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _showScanQrDialog() async {
    List<DiningTable> tables = [];
    try {
      tables = await TableRepository.getAllTables();
    } catch (_) {}
    if (!mounted) return;

    DiningTable? chosen = tables.isNotEmpty ? tables.first : null;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(child: Text('Chọn Bàn Tự Gọi Món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn bàn bạn đang ngồi để đặt món từ giỏ hàng hoặc chuyển thẳng sang đơn bàn:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              if (tables.isEmpty)
                const Text('Không tải được danh sách bàn. Vui lòng thử lại sau.', style: TextStyle(color: Color(0xFFDC2626)))
              else
                DropdownButtonFormField<DiningTable>(
                  isExpanded: true,
                  initialValue: chosen,
                  decoration: InputDecoration(
                    labelText: 'Bàn phục vụ',
                    prefixIcon: const Icon(Icons.table_restaurant_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: tables
                      .map((t) => DropdownMenuItem<DiningTable>(
                            value: t,
                            child: Text('${t.name} (${t.capacity} chỗ • ${t.statusText})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDState(() => chosen = v);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            if (chosen != null)
              FilledButton(
                onPressed: () {
                  final selected = chosen!;
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderCheckoutPage(
                        preSelectedTableId: selected.id,
                        preSelectedTableName: selected.name,
                      ),
                    ),
                  );
                },
                child: const Text('Đặt món cho bàn này'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Cổng Khách Hàng & Hội Viên'),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Làm mới', onPressed: _loadLoyaltyData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoyaltyData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 24),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user != null ? user.fullName : 'Quý Khách Hàng',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          user != null ? '@${user.username}' : 'Chưa đăng nhập tài khoản',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(12)),
                              child: Text(_tierLabel, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ĐIỂM TÍCH LŨY HIỆN TẠI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.0)),
                                const SizedBox(height: 4),
                                _isLoadingLoyalty
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)))
                                    : Text(
                                        '${NumberFormat('#,###').format(_userPoints)} PTS',
                                        style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 24),
                                      ),
                              ],
                            ),
                            if (user == null)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF0F172A)),
                                icon: const Icon(Icons.login, size: 16),
                                label: const Text('Đăng nhập tích điểm', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())).then((_) => _loadLoyaltyData()),
                              )
                            else
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                                label: const Text('CHỌN BÀN ĐẶT MÓN'),
                                onPressed: _showScanQrDialog,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_loyaltyError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_loyaltyError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5)),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _showScanQrDialog,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF059669)),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tự Gọi Món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Chọn bàn ngồi', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) => _loadLoyaltyData()),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.badge_outlined, color: Color(0xFF0284C7)),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Hồ Sơ & Bảo Mật', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Email OTP / Đổi MK', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Kho Voucher Ưu Đãi Hội Viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  if (_vouchers.isEmpty && !_isLoadingLoyalty)
                    const Text('Hiện chưa có mã ưu đãi khả dụng.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                  else
                    ..._vouchers.map((v) {
                      final code = (v['code'] ?? '').toString().toUpperCase();
                      final cost = (v['pointsCost'] as num? ?? 0).toInt();
                      final discountPercent = (v['discountPercent'] as num? ?? 0).toDouble();
                      final discountAmt = (v['discountAmount'] as num? ?? 0).toDouble();
                      final badgeText = discountPercent > 0 ? '-${discountPercent.toInt()}%' : '-${_currencyFormat.format(discountAmt)}';
                      final isRedeemed = _redeemedVoucherCodes.contains(code);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: const Color(0xFF0F172A).withValues(alpha: 0.12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF0284C7), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0284C7))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(4)),
                                          child: Text(badgeText, style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold, fontSize: 10)),
                                        ),
                                        if (cost > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                            child: Text('$cost PTS', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text((v['title'] ?? code).toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    if (v['description'] != null)
                                      Text(v['description'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isRedeemed)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFECFDF5),
                                    foregroundColor: const Color(0xFF059669),
                                    elevation: 0,
                                    side: const BorderSide(color: Color(0xFF059669)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                                  label: const Text('DÙNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: code));
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => OrderCheckoutPage(initialDiscountCode: code)),
                                    );
                                  },
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () => _redeemVoucher(v),
                                  child: Text(
                                    cost > 0 ? 'Đổi $cost PTS' : 'Nhận ngay',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Lịch sử điểm thưởng gần đây', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _history.take(5).length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final h = _history[idx];
                          final delta = (h['pointsDelta'] as num? ?? 0).toInt();
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              delta >= 0 ? Icons.add_circle_outline : Icons.redeem_outlined,
                              color: delta >= 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                            title: Text((h['description'] ?? h['type'] ?? '').toString(), style: const TextStyle(fontSize: 13)),
                            trailing: Text(
                              '${delta >= 0 ? '+' : ''}$delta PTS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: delta >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Tra Cứu Đơn Hàng (Mã đơn hoặc SĐT)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      if (_hasSearched)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF0284C7)),
                          tooltip: 'Làm mới',
                          onPressed: _isSearchingOrders ? null : _searchOrders,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchQueryController,
                          onSubmitted: (_) => _searchOrders(),
                          decoration: InputDecoration(
                            hintText: 'VD: ORD- hoặc SĐT (để trống = đơn của tôi)',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        ),
                        onPressed: _isSearchingOrders ? null : _searchOrders,
                        child: _isSearchingOrders
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Tra cứu', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_hasSearched && _foundOrders.isEmpty && !_isSearchingOrders)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Không tìm thấy đơn hàng nào khớp.', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  else
                    ..._foundOrders.map((o) => _buildOrderStatusTracker(o)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatusTracker(OrderModel o) {
    final isCancelled = o.isCancelled;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.orderId))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCancelled ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.orderCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                              Text(
                                '${o.tableName} • ${DateFormat('HH:mm dd/MM').format(o.createdAt)}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_currencyFormat.format(o.finalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD97706))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: o.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          o.paymentStatusText,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: o.isPaid ? const Color(0xFF166534) : const Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              if (isCancelled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Text('Đơn hàng đã được hủy', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )
              else
                _buildProgressSteps(o.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSteps(int status) {
    final step1 = status >= 0;
    final step2 = status >= 1;
    final step3 = status >= 2;
    final step4 = status >= 3;

    return Row(
      children: [
        _buildStepNode(title: 'Tiếp nhận', isDone: step1, isActive: status == 0, icon: Icons.check_circle_rounded),
        Expanded(child: Container(height: 3, color: step2 ? const Color(0xFF059669) : const Color(0xFFE2E8F0))),
        _buildStepNode(title: 'Chế biến', isDone: step2, isActive: status == 1, icon: Icons.soup_kitchen_rounded),
        Expanded(child: Container(height: 3, color: step3 ? const Color(0xFF059669) : const Color(0xFFE2E8F0))),
        _buildStepNode(title: 'Phục vụ', isDone: step3, isActive: status == 2, icon: Icons.room_service_rounded),
        Expanded(child: Container(height: 3, color: step4 ? const Color(0xFF059669) : const Color(0xFFE2E8F0))),
        _buildStepNode(title: 'Hoàn tất', isDone: step4, isActive: status == 3, icon: Icons.verified_rounded),
      ],
    );
  }

  Widget _buildStepNode({
    required String title,
    required bool isDone,
    required bool isActive,
    required IconData icon,
  }) {
    final color = isDone ? const Color(0xFF059669) : (isActive ? const Color(0xFF0284C7) : const Color(0xFF94A3B8));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDone ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: 15, color: isDone ? Colors.white : color),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isDone || isActive ? FontWeight.bold : FontWeight.normal,
            color: isDone || isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

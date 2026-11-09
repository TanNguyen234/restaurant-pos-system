import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/session_manager.dart';
import '../order/order_checkout_page.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final _searchPhoneController = TextEditingController();

  bool _isSearchingOrders = false;
  List<Map<String, dynamic>> _foundOrders = [];

  // OTP Reset Password modal controllers
  final _emailOtpController = TextEditingController();
  final _otpCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isOtpSent = false;

  final List<Map<String, dynamic>> _vouchers = [
    {
      'code': 'BANMOI10',
      'title': 'Ưu đãi Khách Mới 10%',
      'description': 'Giảm 10% trên tổng giá trị hóa đơn món ăn',
      'badge': 'MỚI',
      'color': const Color(0xFF059669),
    },
    {
      'code': 'GIAM20K',
      'title': 'Voucher Giảm 20.000đ',
      'description': 'Áp dụng cho đơn hàng từ 100.000đ trở lên',
      'badge': 'HOT',
      'color': const Color(0xFFD97706),
    },
    {
      'code': 'VIPMEMBER',
      'title': 'Đặc quyền VIP Vàng 15%',
      'description': 'Dành riêng cho khách hàng hạng Vàng & Kim Cương',
      'badge': 'VIP',
      'color': const Color(0xFF7C3AED),
    },
  ];

  Future<void> _searchOrdersByPhone() async {
    final phone = _searchPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại cần tra cứu!')),
      );
      return;
    }

    setState(() => _isSearchingOrders = true);
    try {
      final res = await ApiConfig.get(Uri.parse('${ApiConfig.baseUrl}/api/order?phoneNumber=$phone&pageSize=10'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final items = (data['items'] as List? ?? data['data'] as List? ?? []).cast<Map<String, dynamic>>();
        setState(() {
          _foundOrders = items;
          _isSearchingOrders = false;
        });
      } else {
        setState(() {
          _foundOrders = [];
          _isSearchingOrders = false;
        });
      }
    } catch (_) {
      setState(() {
        _foundOrders = [];
        _isSearchingOrders = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối máy chủ để tra cứu đơn hàng!')),
        );
      }
    }
  }

  void _showScanQrDialog() {
    final tableCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Quét QR Bàn Tự Gọi Món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập số bàn bạn đang ngồi để xem thực đơn số và gửi order trực tiếp xuống bếp:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tableCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số hiệu bàn (Table ID)',
                prefixIcon: const Icon(Icons.table_restaurant_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
            onPressed: () {
              final id = int.tryParse(tableCtrl.text) ?? 1;
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderCheckoutPage(
                    preSelectedTableId: id,
                    preSelectedTableName: 'Bàn T1-0$id',
                  ),
                ),
              );
            },
            child: const Text('Vào gọi món ngay', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOtpResetPasswordDialog() {
    _isOtpSent = false;
    _emailOtpController.clear();
    _otpCodeController.clear();
    _newPasswordController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text('Quên Mật Khẩu (OTP Email)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nhận mã OTP 6 chữ số qua email để thiết lập mật khẩu mới:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailOtpController,
                    enabled: !_isOtpSent,
                    decoration: InputDecoration(
                      labelText: 'Email hoặc Tên đăng nhập *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_isOtpSent)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('GỬI MÃ OTP XÁC THỰC'),
                        onPressed: () async {
                          final idText = _emailOtpController.text.trim();
                          if (idText.isEmpty) return;

                          try {
                            final res = await ApiConfig.post(
                              Uri.parse('${ApiConfig.baseUrl}/api/auth/request-otp'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({'email': idText, 'username': idText}),
                            );
                            final data = jsonDecode(utf8.decode(res.bodyBytes));
                            setDState(() {
                              if (res.statusCode == 200 && data['success'] == true) {
                                _isOtpSent = true;
                                if (data['devOtp'] != null) {
                                  _otpCodeController.text = data['devOtp'].toString();
                                }
                              }
                            });
                            if (dCtx.mounted) {
                              ScaffoldMessenger.of(dCtx).showSnackBar(
                                SnackBar(
                                  content: Text(data['message']?.toString() ?? 'Đã gửi mã OTP!'),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            }
                          } catch (_) {}
                        },
                      ),
                    ),
                  if (_isOtpSent) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otpCodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nhập mã OTP 6 chữ số *',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới (tối thiểu 6 ký tự) *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng', style: TextStyle(color: Color(0xFF64748B))),
              ),
              if (_isOtpSent)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final identity = _emailOtpController.text.trim();
                    final otp = _otpCodeController.text.trim();
                    final pass = _newPasswordController.text.trim();
                    if (otp.isEmpty || pass.length < 6) return;

                    try {
                      final res = await ApiConfig.post(
                        Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password-otp'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'identity': identity,
                          'otp': otp,
                          'newPassword': pass,
                        }),
                      );
                      final data = jsonDecode(utf8.decode(res.bodyBytes));
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(data['message']?.toString() ?? 'Đổi mật khẩu thành công!'),
                            backgroundColor: res.statusCode == 200 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  child: const Text('XÁC NHẬN ĐỔI MẬT KHẨU'),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Cổng Khách Hàng (Member Portal)'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Membership Digital Card
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
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null ? user.fullName : 'Quý Khách Hàng',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                user != null ? '@${user.username}' : 'Thành viên thân thiết',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('VIP GOLD', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('ĐIỂM TÍCH LŨY', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1.1)),
                          SizedBox(height: 4),
                          Text('1,250 PTS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 24)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('QUÉT MÃ BÀN'),
                        onPressed: _showScanQrDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Actions Row
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
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tự Gọi Món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Ngồi tại bàn', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _showOtpResetPasswordDialog,
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
                            child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Đổi Mật Khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Xác thực OTP', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Vouchers & Discounts Engine Section
            const Text('Kho Voucher Ưu Đãi Hội Viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Column(
              children: _vouchers.map((v) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: (v['color'] as Color).withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (v['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.confirmation_number_outlined, color: v['color'] as Color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    v['code'].toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: v['color'] as Color),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (v['color'] as Color).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(v['badge'].toString(),
                                        style: TextStyle(color: v['color'] as Color, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(v['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(v['description'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: v['color'] as Color),
                            foregroundColor: v['color'] as Color,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã chọn mã "${v['code']}". Mã sẽ tự động áp dụng khi thanh toán!'),
                                backgroundColor: const Color(0xFF0F172A),
                              ),
                            );
                          },
                          child: const Text('DÙNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Order History Lookup by Phone
            const Text('Tra Cứu Lịch Sử Đơn Hàng Theo SĐT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Nhập SĐT khách hàng (VD: 0901234567)',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _isSearchingOrders ? null : _searchOrdersByPhone,
                  child: _isSearchingOrders
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Tra cứu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_foundOrders.isNotEmpty)
              Column(
                children: _foundOrders.map((o) {
                  final code = o['orderCode'] ?? 'ORD-000';
                  final amount = (o['finalAmount'] as num?)?.toDouble() ?? 0.0;
                  final status = o['status'] ?? 0;
                  final date = o['createdAt']?.toString() ?? '';

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
                      title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(date, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currencyFormat.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706))),
                          Text(status == 3 ? 'Đã hoàn tất' : 'Đang xử lý', style: TextStyle(fontSize: 11, color: status == 3 ? const Color(0xFF059669) : const Color(0xFF0284C7))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

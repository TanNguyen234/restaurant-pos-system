import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/order_repository.dart';
import '../../services/session_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../order/order_detail_page.dart';
import 'change_password_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final bool isEmbedded;
  const ProfilePage({super.key, this.isEmbedded = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthRepository _authRepo = AuthRepository();
  final OrderRepository _orderRepo = OrderRepository();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  UserAccount? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  List<OrderModel> _myOrders = [];
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _isLoadingOrders = true;
    });
    var session = SessionManager.instance.currentUser ?? await _authRepo.getCurrentSession();
    final remote = session != null ? await _authRepo.getMyProfile() : null;
    if (remote != null) {
      session = remote;
      await SessionManager.instance.setSession(remote);
    }
    List<OrderModel> orders = [];
    if (session != null) {
      try {
        orders = await _orderRepo.lookupOrders('');
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _user = session;
        _fullNameController.text = session?.fullName ?? '';
        _emailController.text = session?.email ?? '';
        _phoneController.text = session?.phoneNumber ?? '';
        _myOrders = orders;
        _isLoading = false;
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final res = await _authRepo.updateProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      await _loadProfile();
      if (!mounted) return;
      showAutoDismissSnackBar(
        context,
        message: res['message']?.toString() ?? 'Cập nhật hồ sơ thành công',
        backgroundColor: const Color(0xFF059669),
      );
    } else {
      showAutoDismissSnackBar(
        context,
        message: res['message']?.toString() ?? 'Không thể cập nhật hồ sơ',
        backgroundColor: const Color(0xFFDC2626),
      );
    }
  }

  Future<void> _startEmailVerification() async {
    final user = _user;
    if (user == null) return;
    final emailText = _emailController.text.trim();
    if (emailText.isEmpty || !emailText.contains('@')) {
      showAutoDismissSnackBar(
        context,
        message: 'Vui lòng nhập và lưu Email hợp lệ trước khi xác thực',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (emailText != (user.email ?? '').trim()) {
      final saveRes = await _authRepo.updateProfile(
        fullName: _fullNameController.text,
        email: emailText,
        phoneNumber: _phoneController.text,
      );
      if (saveRes['success'] != true) {
        if (!mounted) return;
        showAutoDismissSnackBar(
          context,
          message: saveRes['message']?.toString() ?? 'Lỗi lưu email',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    if (!mounted) return;
    showAutoDismissSnackBar(
      context,
      message: 'Đang gửi mã OTP xác thực tới email của bạn...',
    );

    final reqRes = await _authRepo.requestEmailVerification(emailText);
    if (!mounted) return;
    if (reqRes['success'] != true) {
      showAutoDismissSnackBar(
        context,
        message: reqRes['message']?.toString() ?? 'Không gửi được OTP',
        backgroundColor: Colors.red,
      );
      return;
    }

    final otpCtrl = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSubmitting = false;
        String? errorMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(child: Text('Xác thực Email', style: TextStyle(fontSize: 17))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reqRes['message'] ?? 'Nhập mã OTP 6 chữ số đã gửi về email.', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mã OTP (6 chữ số)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final code = otpCtrl.text.trim();
                        if (code.length != 6) {
                          setDialogState(() => errorMsg = 'Vui lòng nhập đủ 6 chữ số OTP');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          errorMsg = null;
                        });
                        final vRes = await _authRepo.verifyEmail(identity: emailText, otp: code);
                        if (!ctx.mounted) return;
                        if (vRes['success'] == true) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMsg = vRes['message'] ?? 'Mã OTP không đúng';
                          });
                        }
                      },
                child: Text(isSubmitting ? 'Đang kiểm tra...' : 'Xác nhận'),
              ),
            ],
          ),
        );
      },
    );

    if (verified == true && mounted) {
      await _loadProfile();
      if (!mounted) return;
      showAutoDismissSnackBar(
        context,
        message: 'Xác thực Email thành công!',
        backgroundColor: const Color(0xFF059669),
      );
    }
  }

  Future<void> _logout() async {
    await SessionManager.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Hồ sơ cá nhân'),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0.5,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 72, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text(
                          'Bạn chưa đăng nhập tài khoản',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng nhập để quản lý thông tin cá nhân, tích điểm và đổi mật khẩu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            );
                            _loadProfile();
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Đăng nhập ngay'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: const Color(0xFFE0F2FE),
                                    child: Text(
                                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@${user.username} • ${user.roleName}',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: user.isEmailVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    user.isEmailVerified ? Icons.verified : Icons.warning_amber_rounded,
                                                    size: 14,
                                                    color: user.isEmailVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    user.isEmailVerified ? 'Email đã xác thực' : 'Chưa xác thực Email',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: user.isEmailVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (user.isMember)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0F2FE),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${user.loyaltyPoints} PTS',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Edit Profile Form
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Cập nhật thông tin',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _fullNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Họ và tên',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.email_outlined),
                                      ),
                                      validator: (v) {
                                        if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                                          return 'Email không đúng định dạng';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Số điện thoại',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.phone_outlined),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: _isSaving ? null : _saveProfile,
                                      icon: _isSaving
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.save_outlined),
                                      label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi'),
                                    ),
                                    if (!user.isEmailVerified) ...[
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: _startEmailVerification,
                                        icon: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF0284C7)),
                                        label: const Text('Gửi mã OTP xác thực Email'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // My Orders Section
                            _buildMyOrdersSection(),
                            const SizedBox(height: 16),

                            // Account Actions
                            Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.lock_reset, color: Color(0xFF0F172A)),
                                      title: const Text('Đổi mật khẩu'),
                                      subtitle: const Text('Cập nhật mật khẩu bảo mật cho tài khoản'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                                      title: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                                      subtitle: const Text('Kết thúc phiên đăng nhập trên thiết bị này'),
                                      onTap: _logout,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Color _orderStatusColor(int status) {
    switch (status) {
      case 0:
        return const Color(0xFF3B82F6);
      case 1:
        return const Color(0xFFD97706);
      case 2:
        return const Color(0xFF7C3AED);
      case 3:
        return const Color(0xFF059669);
      case 4:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildMyOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đơn hàng của tôi (${_myOrders.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF0284C7)),
                tooltip: 'Làm mới đơn hàng',
                onPressed: _isLoadingOrders ? null : _loadProfile,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingOrders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Bạn chưa có đơn hàng nào',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
              ),
            )
          else
            ..._myOrders.map((o) {
              final statusColor = _orderStatusColor(o.status);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.orderId)),
                  ).then((_) => _loadProfile()),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                o.orderCode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currencyFormat.format(o.finalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                o.statusText,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: o.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                o.paymentStatusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: o.isPaid ? const Color(0xFF166534) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormat('HH:mm dd/MM/yyyy').format(o.createdAt)} • ${o.totalItems} món',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Xem chi tiết',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                ),
                                Icon(Icons.chevron_right, size: 16, color: Color(0xFF0284C7)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

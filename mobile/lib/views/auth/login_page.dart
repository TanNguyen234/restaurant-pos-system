import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../services/session_manager.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepo.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as UserAccount?;
      if (user != null) {
        await SessionManager.instance.setSession(user);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đăng nhập thành công'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      setState(() {
        _errorMessage = result['message']?.toString() ?? 'Đăng nhập thất bại';
      });
    }
  }

  Future<void> _showOAuthModal(String provider, Color brandColor) async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final submitted = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        String? localErr;
        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: brandColor.withValues(alpha: 0.12),
                  child: Icon(Icons.verified_user, color: brandColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Đăng nhập với $provider', style: const TextStyle(fontSize: 17))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chế độ Sandbox OAuth ($provider): Nhập email & tên hiển thị tài khoản khách hàng để đăng nhập hoặc tạo hội viên mới. Không cho phép đăng nhập chéo vào tài khoản nhân sự/Admin.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email $provider *',
                      hintText: 'khachhang@example.com',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên hiển thị',
                      hintText: 'Nguyễn Văn A',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  if (localErr != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(localErr!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: brandColor),
                onPressed: () {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    setModalState(() => localErr = 'Vui lòng nhập email hợp lệ');
                    return;
                  }
                  final name = nameCtrl.text.trim().isEmpty
                      ? email.split('@').first
                      : nameCtrl.text.trim();
                  Navigator.pop(ctx, {'email': email, 'fullName': name});
                },
                child: Text('Tiếp tục với $provider'),
              ),
            ],
          ),
        );
      },
    );

    if (submitted == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepo.oauthLogin(
      provider: provider,
      email: submitted['email']!,
      fullName: submitted['fullName']!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as UserAccount?;
      if (user != null) {
        await SessionManager.instance.setSession(user);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đăng nhập $provider thành công'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  Future<void> _showForgotPasswordModal() async {
    final identityCtrl = TextEditingController(text: _usernameController.text.trim());
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    int step = 1;
    bool modalLoading = false;
    String? infoMsg;
    String? errMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step == 1 ? 'Quên mật khẩu' : 'Nhập mã OTP & Mật khẩu mới',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step == 1) ...[
                  const Text(
                    'Nhập tên đăng nhập hoặc email đã đăng ký để nhận mã OTP 6 chữ số qua Email.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: identityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập hoặc Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search_outlined),
                    ),
                  ),
                ] else ...[
                  if (infoMsg != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(infoMsg!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0369A1))),
                    ),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mã OTP 6 chữ số từ Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
                if (errMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(errMsg!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: modalLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            if (step == 1)
              FilledButton(
                onPressed: modalLoading
                    ? null
                    : () async {
                        if (identityCtrl.text.trim().isEmpty) {
                          setModalState(() => errMsg = 'Vui lòng nhập email hoặc tên đăng nhập');
                          return;
                        }
                        setModalState(() {
                          modalLoading = true;
                          errMsg = null;
                        });
                        final res = await _authRepo.requestOtp(identityCtrl.text.trim());
                        if (!ctx.mounted) return;
                        setModalState(() {
                          modalLoading = false;
                          if (res['success'] == true) {
                            infoMsg = res['message']?.toString();
                            step = 2;
                          } else {
                            errMsg = res['message']?.toString();
                          }
                        });
                      },
                child: Text(modalLoading ? 'Đang gửi...' : 'Gửi mã OTP'),
              )
            else
              FilledButton(
                onPressed: modalLoading
                    ? null
                    : () async {
                        if (otpCtrl.text.trim().length != 6 || newPassCtrl.text.length < 6) {
                          setModalState(() => errMsg = 'Vui lòng nhập đủ 6 số OTP và mật khẩu >= 6 ký tự');
                          return;
                        }
                        setModalState(() {
                          modalLoading = true;
                          errMsg = null;
                        });
                        final res = await _authRepo.resetPasswordOtp(
                          identity: identityCtrl.text.trim(),
                          otp: otpCtrl.text.trim(),
                          newPassword: newPassCtrl.text,
                        );
                        if (!ctx.mounted) return;
                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Đặt lại mật khẩu thành công'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        } else {
                          setModalState(() {
                            modalLoading = false;
                            errMsg = res['message']?.toString();
                          });
                        }
                      },
                child: Text(modalLoading ? 'Đang xác nhận...' : 'Đổi mật khẩu'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, size: 48, color: Color(0xFF0F172A)),
                      const SizedBox(height: 12),
                      const Text(
                        'Đăng nhập hệ thống',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bistro & Café POS Platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                          hintText: 'Nhập tên đăng nhập',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đăng nhập' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          hintText: 'Nhập mật khẩu',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _showForgotPasswordModal,
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('ĐĂNG NHẬP', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('Hoặc đăng nhập nhanh', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _showOAuthModal('Google', const Color(0xFFDB4437)),
                              child: const Text('Google', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _showOAuthModal('Facebook', const Color(0xFF1877F2)),
                              child: const Text('Facebook', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _showOAuthModal('Zalo', const Color(0xFF0068FF)),
                              child: const Text('Zalo', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Chưa có tài khoản hội viên?', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterPage()),
                            ),
                            child: const Text('Đăng ký ngay'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../repositories/auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthRepository _authRepo = AuthRepository();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showEmailOtpVerificationDialog(String email, String? notice) async {
    final otpCtrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSubmitting = false;
        String? errMsg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(child: Text('Xác thực Email đăng ký', style: TextStyle(fontSize: 17))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice?.isNotEmpty == true
                        ? notice!
                        : 'Nhập mã OTP 6 chữ số đã được gửi tới email $email để kích hoạt xác thực tài khoản.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mã OTP 6 chữ số',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  if (errMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(errMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Xác thực sau'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (otpCtrl.text.trim().length != 6) {
                          setDialogState(() => errMsg = 'Vui lòng nhập đủ 6 chữ số OTP');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          errMsg = null;
                        });
                        final res = await _authRepo.verifyEmail(
                          identity: email,
                          otp: otpCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Xác thực email thành công!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            errMsg = res['message']?.toString();
                          });
                        }
                      },
                child: Text(isSubmitting ? 'Đang kiểm tra...' : 'Xác thực ngay'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cleanEmail = _emailController.text.trim();
    final cleanPhone = _phoneController.text.trim();

    final result = await _authRepo.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      email: cleanEmail.isEmpty ? null : cleanEmail,
      phoneNumber: cleanPhone.isEmpty ? null : cleanPhone,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (result['requiresEmailVerification'] == true && cleanEmail.isNotEmpty) {
        await _showEmailOtpVerificationDialog(cleanEmail, result['emailNotice']?.toString());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đăng ký thành công! Vui lòng đăng nhập.'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        _errorMessage = result['message']?.toString() ?? 'Đăng ký thất bại';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Đăng ký hội viên'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Tạo tài khoản khách hàng',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tích điểm đổi ưu đãi và theo dõi đơn hàng dễ dàng.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                        ),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập *',
                          hintText: 'Tối thiểu 3 ký tự',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 3) {
                            return 'Tên đăng nhập phải có ít nhất 3 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ và tên' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (tuỳ chọn, dùng nhận OTP xác thực)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại (tuỳ chọn)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu *',
                          hintText: 'Tối thiểu 6 ký tự',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải từ 6 ký tự trở lên' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_clock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('ĐĂNG KÝ TÀI KHOẢN', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
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

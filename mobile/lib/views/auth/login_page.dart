import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../services/session_manager.dart';
import '../../utils/snackbar_helper.dart';
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
  Map<String, dynamic> _oauthProviders = {};

  @override
  void initState() {
    super.initState();
    _loadOAuthProviders();
  }

  Future<void> _loadOAuthProviders() async {
    final providers = await _authRepo.getOAuthProvidersStatus();
    if (!mounted) return;
    setState(() => _oauthProviders = providers);
  }

  Map<String, dynamic>? _findProviderConfig(String providerKey) {
    final direct = _oauthProviders[providerKey];
    if (direct is Map) return Map<String, dynamic>.from(direct);
    for (final entry in _oauthProviders.entries) {
      if (entry.key.toLowerCase() == providerKey.toLowerCase() && entry.value is Map) {
        return Map<String, dynamic>.from(entry.value as Map);
      }
    }
    return null;
  }

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
      showAutoDismissSnackBar(
        context,
        message: result['message']?.toString() ?? 'Đăng nhập thành công',
        backgroundColor: const Color(0xFF059669),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      setState(() {
        _errorMessage = result['message']?.toString() ?? 'Đăng nhập thất bại';
      });
    }
  }

  Future<void> _startRealOAuth(String providerKey, String displayName, Color brandColor) async {
    if (_oauthProviders.isEmpty) {
      await _loadOAuthProviders();
      if (!mounted) return;
    }

    final cfg = _findProviderConfig(providerKey);
    if (cfg != null && cfg['configured'] == false) {
      final missingKeys = (cfg['missingEnvKeys'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      final callbackUrl = cfg['callbackUrl']?.toString() ?? '';

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.settings_outlined, color: brandColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chưa cấu hình OAuth $displayName',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đăng nhập $displayName sử dụng OAuth 2.0 thật và cần cấu hình khóa ứng dụng trong backend/.env:',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
                if (missingKeys.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Biến môi trường còn thiếu trong backend/.env:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SelectableText(
                      missingKeys.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
                if (callbackUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Callback URL cần đăng ký trong $displayName Developer Console:',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: SelectableText(
                      callbackUrl,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    if (kIsWeb) {
      final origin = '${Uri.base.scheme}://${Uri.base.host}${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
      final startUri = _authRepo.buildOAuthStartUri(providerKey, clientRedirect: origin);
      final launched = await launchUrl(startUri, webOnlyWindowName: '_self');
      if (!launched && mounted) {
        showAutoDismissSnackBar(
          context,
          message: 'Không thể mở trang xác thực $displayName',
          backgroundColor: const Color(0xFFDC2626),
        );
      }
      return;
    }

    final pollKey = const Uuid().v4();
    final startUri = _authRepo.buildOAuthStartUri(providerKey, pollKey: pollKey);
    final launched = await launchUrl(startUri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      showAutoDismissSnackBar(
        context,
        message: 'Không thể mở trình duyệt ngoài để xác thực $displayName',
        backgroundColor: const Color(0xFFDC2626),
      );
      return;
    }

    final pollResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OAuthPollingDialog(
        displayName: displayName,
        brandColor: brandColor,
        pollKey: pollKey,
        authRepo: _authRepo,
      ),
    );

    if (!mounted || pollResult == null) return;
    final pollError = pollResult['error']?.toString();
    if (pollError != null && pollError.isNotEmpty) {
      setState(() => _errorMessage = pollError);
      return;
    }

    final ticket = pollResult['ticket']?.toString();
    if (ticket == null || ticket.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authRepo.exchangeOAuthTicket(ticket);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as UserAccount?;
      if (user != null) {
        await SessionManager.instance.setSession(user);
      }
      if (!mounted) return;
      showAutoDismissSnackBar(
        context,
        message: result['message']?.toString() ?? 'Đăng nhập $displayName thành công',
        backgroundColor: const Color(0xFF059669),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } else {
      setState(() => _errorMessage = result['message']?.toString() ?? 'Đăng nhập $displayName thất bại');
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
                            showAutoDismissSnackBar(
                              context,
                              message: res['message']?.toString() ?? 'Đặt lại mật khẩu thành công',
                              backgroundColor: const Color(0xFF059669),
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
                              onPressed: _isLoading ? null : () => _startRealOAuth('google', 'Google', const Color(0xFFDB4437)),
                              child: const Text('Google', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _startRealOAuth('facebook', 'Facebook', const Color(0xFF1877F2)),
                              child: const Text('Facebook', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _startRealOAuth('zalo', 'Zalo', const Color(0xFF0068FF)),
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

class _OAuthPollingDialog extends StatefulWidget {
  final String displayName;
  final Color brandColor;
  final String pollKey;
  final AuthRepository authRepo;

  const _OAuthPollingDialog({
    required this.displayName,
    required this.brandColor,
    required this.pollKey,
    required this.authRepo,
  });

  @override
  State<_OAuthPollingDialog> createState() => _OAuthPollingDialogState();
}

class _OAuthPollingDialogState extends State<_OAuthPollingDialog> {
  Timer? _timer;
  bool _isPollingRequest = false;
  bool _completed = false;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _pollOnce());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    if (!mounted || _completed || _isPollingRequest) return;
    if (DateTime.now().difference(_startedAt) >= const Duration(seconds: 120)) {
      _completed = true;
      _timer?.cancel();
      Navigator.of(context).pop({
        'error': 'Hết thời gian chờ xác thực từ ${widget.displayName} (120s). Vui lòng thử lại.',
      });
      return;
    }

    _isPollingRequest = true;
    final res = await widget.authRepo.pollOAuthTicket(widget.pollKey);
    _isPollingRequest = false;
    if (!mounted || _completed) return;

    final err = res['error']?.toString();
    if (err != null && err.isNotEmpty) {
      _completed = true;
      _timer?.cancel();
      Navigator.of(context).pop({'error': err});
      return;
    }

    final ticket = res['ticket']?.toString().trim();
    if (res['ready'] == true && ticket != null && ticket.isNotEmpty) {
      _completed = true;
      _timer?.cancel();
      Navigator.of(context).pop({'ticket': ticket});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: widget.brandColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang chờ xác thực từ ${widget.displayName}...',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Vui lòng hoàn tất đăng nhập trên trình duyệt vừa mở, sau đó quay lại ứng dụng.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _completed = true;
            _timer?.cancel();
            Navigator.of(context).pop(null);
          },
          child: const Text('Hủy'),
        ),
      ],
    );
  }
}

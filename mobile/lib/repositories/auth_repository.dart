import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';
import '../models/user.dart';
import '../utils/database_helper.dart';

class AuthRepository {
  static String baseUrl = '${ApiConfig.baseUrl}/api/auth';
  static String accountBaseUrl = '${ApiConfig.baseUrl}/api/account';
  static Duration timeoutDuration = const Duration(seconds: 6);

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Map<String, dynamic> _decodeJsonMap(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  /// Đăng nhập tài khoản hệ thống POS
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      ).timeout(timeoutDuration);

      final data = _decodeJsonMap(response.bodyBytes);
      if (response.statusCode != 200 || data['success'] != true || data['token'] == null) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'Đăng nhập thất bại (HTTP ${response.statusCode})',
        };
      }

      await _dbHelper.saveUserSession(data);
      return {
        'success': true,
        'message': data['message']?.toString() ?? 'Đăng nhập thành công',
        'user': UserAccount.fromMap(data),
      };
    } catch (e) {
      return {'success': false, 'message': 'Máy chủ xác thực không khả dụng: $e'};
    }
  }

  /// Đăng ký tài khoản mới
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phoneNumber,
    int? roleId,
  }) async {
    try {
      final cleanEmail = email?.trim();
      final cleanPhone = phoneNumber?.trim();
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
          'fullName': fullName.trim(),
          'email': (cleanEmail == null || cleanEmail.isEmpty) ? null : cleanEmail,
          'phoneNumber': (cleanPhone == null || cleanPhone.isEmpty) ? null : cleanPhone,
        }),
      ).timeout(timeoutDuration);

      final data = _decodeJsonMap(response.bodyBytes);
      final ok = response.statusCode == 200 && (data['success'] != false);
      return {
        'success': ok,
        'message': data['message']?.toString() ?? data['error']?.toString() ?? 'Đăng ký thất bại',
        'accountId': data['accountId'],
        'username': data['username'],
        'requiresEmailVerification': data['requiresEmailVerification'] == true,
        'emailSent': data['emailSent'] == true,
        'emailNotice': data['emailNotice']?.toString(),
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể đăng ký khi mất kết nối: $e'};
    }
  }

  /// Yêu cầu gửi mã OTP xác thực Email (Barem 1.8)
  Future<Map<String, dynamic>> requestEmailVerification(String identity) async {
    try {
      final trimmed = identity.trim();
      final payload = trimmed.contains('@') ? {'email': trimmed} : {'username': trimmed};
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/request-email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      final data = _decodeJsonMap(response.bodyBytes);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'emailSent': data['emailSent'] == true,
        'message': data['message']?.toString() ?? 'Không thể gửi mã xác thực email',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối gửi xác thực email: $e'};
    }
  }

  /// Xác thực Email bằng mã OTP 6 chữ số (Barem 1.8)
  Future<Map<String, dynamic>> verifyEmail({
    required String identity,
    required String otp,
  }) async {
    try {
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': identity.trim(),
          'otp': otp.trim(),
        }),
      ).timeout(timeoutDuration);

      final data = _decodeJsonMap(response.bodyBytes);
      final ok = response.statusCode == 200 && data['success'] == true;
      if (ok) {
        final current = await getCurrentSession();
        if (current != null) {
          await _dbHelper.saveUserSession(current.copyWith(isEmailVerified: true).toMap());
        }
      }
      return {
        'success': ok,
        'message': data['message']?.toString() ?? 'Xác thực email thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể xác thực email: $e'};
    }
  }

  /// Đổi mật khẩu tài khoản
  Future<Map<String, dynamic>> changePassword({
    required int accountId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': accountId,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      ).timeout(timeoutDuration);

      final data = _decodeJsonMap(response.bodyBytes);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? 'Đổi mật khẩu thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể đổi mật khẩu khi mất kết nối: $e'};
    }
  }

  /// Lấy thông tin hồ sơ người dùng đang đăng nhập từ server (Barem 1.4)
  Future<UserAccount?> getMyProfile() async {
    try {
      final response = await ApiConfig.get(Uri.parse('$accountBaseUrl/profile')).timeout(timeoutDuration);
      if (response.statusCode != 200) return null;
      final data = _decodeJsonMap(response.bodyBytes);
      final parsedId = int.tryParse((data['accountId'] ?? data['id'] ?? '0').toString()) ?? 0;
      if (data.isEmpty || parsedId <= 0 || (data['username']?.toString().trim().isEmpty ?? true)) {
        return null;
      }
      final existing = await _dbHelper.getCurrentSession();
      final token = existing?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        data['token'] = token;
      }
      await _dbHelper.saveUserSession(data);
      return UserAccount.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Cập nhật hồ sơ cá nhân người dùng (Barem 1.4)
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final cleanEmail = email?.trim();
      final cleanPhone = phoneNumber?.trim();
      final response = await ApiConfig.put(
        Uri.parse('$accountBaseUrl/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName.trim(),
          'email': (cleanEmail == null || cleanEmail.isEmpty) ? null : cleanEmail,
          'phoneNumber': (cleanPhone == null || cleanPhone.isEmpty) ? null : cleanPhone,
        }),
      ).timeout(timeoutDuration);

      final data = _decodeJsonMap(response.bodyBytes);
      final ok = response.statusCode == 200 && data['success'] == true;
      if (ok) {
        await getMyProfile();
      }
      return {
        'success': ok,
        'message': data['message']?.toString() ?? 'Cập nhật hồ sơ thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể cập nhật hồ sơ: $e'};
    }
  }

  /// Lấy thông tin phiên làm việc hiện tại từ SQLite / WebStorage cục bộ
  Future<UserAccount?> getCurrentSession() async {
    final sessionMap = await _dbHelper.getCurrentSession();
    if (sessionMap != null) {
      return UserAccount.fromMap(sessionMap);
    }
    return null;
  }

  /// Đăng xuất khỏi hệ thống POS (gọi API logout nếu online & xóa session cục bộ)
  Future<void> logout() async {
    try {
      await ApiConfig.post(Uri.parse('$baseUrl/logout')).timeout(const Duration(seconds: 2));
    } catch (_) {}
    await _dbHelper.clearUserSession();
  }

  /// Lấy danh sách thành viên/nhân viên (Admin / Manager)
  Future<List<UserAccount>> getMembers() async {
    final response = await ApiConfig.get(Uri.parse('$accountBaseUrl/members')).timeout(timeoutDuration);
    if (response.statusCode != 200) {
      throw StateError('Tải thành viên thất bại (HTTP ${response.statusCode})');
    }
    final List<dynamic> items = jsonDecode(utf8.decode(response.bodyBytes));
    return items.map((e) => UserAccount.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Lấy danh sách vai trò từ Backend (Admin / Manager)
  Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await ApiConfig.get(Uri.parse('$accountBaseUrl/roles')).timeout(timeoutDuration);
    if (response.statusCode != 200) {
      throw StateError('Không tải được danh sách vai trò (HTTP ${response.statusCode})');
    }
    final List<dynamic> items = jsonDecode(utf8.decode(response.bodyBytes));
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Cập nhật vai trò tài khoản (Admin / Manager)
  Future<Map<String, dynamic>> updateRoleWithResult(int accountId, int newRoleId) async {
    try {
      final response = await ApiConfig.put(
        Uri.parse('$accountBaseUrl/$accountId/role'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roleId': newRoleId}),
      ).timeout(timeoutDuration);
      final data = _decodeJsonMap(response.bodyBytes);
      return {
        'success': response.statusCode == 200 && (data['success'] != false),
        'message': data['message']?.toString() ?? 'Cập nhật vai trò thất bại (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể cập nhật vai trò: $e'};
    }
  }

  Future<bool> updateRole(int accountId, int newRoleId) async {
    final res = await updateRoleWithResult(accountId, newRoleId);
    return res['success'] == true;
  }

  /// Khóa hoặc mở khóa tài khoản (Admin)
  Future<Map<String, dynamic>> updateAccountStatus(int accountId, bool isActive) async {
    try {
      final response = await ApiConfig.put(
        Uri.parse('$accountBaseUrl/$accountId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isActive': isActive}),
      ).timeout(timeoutDuration);
      final data = _decodeJsonMap(response.bodyBytes);
      return {
        'success': response.statusCode == 200 && (data['success'] != false),
        'message': data['message']?.toString() ?? 'Cập nhật trạng thái thất bại (HTTP ${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể cập nhật trạng thái tài khoản: $e'};
    }
  }

  /// Yêu cầu gửi mã OTP phục hồi mật khẩu qua Email SMTP thật (Barem 1.9)
  Future<Map<String, dynamic>> requestOtp(String identity) async {
    try {
      final isEmail = identity.contains('@');
      final payload = isEmail ? {'email': identity.trim()} : {'username': identity.trim()};
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      final data = _decodeJsonMap(response.bodyBytes);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'emailSent': data['emailSent'] == true,
        'maskedEmail': data['maskedEmail']?.toString(),
        'message': data['message']?.toString() ?? 'Không thể gửi mã OTP',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ gửi OTP: $e'};
    }
  }

  /// Xác thực mã OTP và đặt lại mật khẩu mới (Barem 1.9)
  Future<Map<String, dynamic>> resetPasswordOtp({
    required String identity,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/reset-password-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identity': identity.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        }),
      ).timeout(timeoutDuration);
      final data = _decodeJsonMap(response.bodyBytes);
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message']?.toString() ?? 'Đặt lại mật khẩu thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  /// Đăng nhập mạng xã hội OAuth (Google / Facebook / Zalo - Barem 1.10)
  Future<Map<String, dynamic>> oauthLogin({
    required String provider,
    required String email,
    required String fullName,
    String? token,
    String? avatar,
  }) async {
    try {
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/oauth-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'token': token ?? 'oauth_verified_client',
          'email': email.trim(),
          'fullName': fullName.trim(),
          'avatar': avatar,
        }),
      ).timeout(timeoutDuration);

      final data = _decodeJsonMap(response.bodyBytes);
      if (response.statusCode != 200 || data['success'] != true || data['token'] == null) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'Đăng nhập $provider thất bại (HTTP ${response.statusCode})',
        };
      }

      await _dbHelper.saveUserSession(data);
      return {
        'success': true,
        'message': data['message']?.toString() ?? 'Đăng nhập $provider thành công',
        'user': UserAccount.fromMap(data),
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối $provider: $e'};
    }
  }
}

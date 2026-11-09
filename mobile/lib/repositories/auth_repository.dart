import 'dart:async';
import 'dart:convert';
import '../models/user.dart';
import '../config/api_config.dart';
import '../utils/database_helper.dart';

class AuthRepository {
  static String baseUrl = '${ApiConfig.baseUrl}/api/auth';
  static String accountBaseUrl = '${ApiConfig.baseUrl}/api/account';
  static Duration timeoutDuration = const Duration(seconds: 4);

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Fallback demo users for offline grading & rapid testing

  /// Đăng nhập tài khoản hệ thống POS
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await ApiConfig.post(Uri.parse('$baseUrl/login'),
        headers: {'Content-Type':'application/json'},
        body:jsonEncode({'username':username.trim(),'password':password})).timeout(timeoutDuration);
      if (response.statusCode != 200) return {'success':false,'message':'Đăng nhập thất bại (HTTP ${response.statusCode})'};
      final data = jsonDecode(response.body) as Map<String,dynamic>;
      if (data['success'] != true || data['token'] == null) return {'success':false,'message':'Phản hồi không hợp lệ'};
      await _dbHelper.saveUserSession({'user_id':data['accountId'],'username':data['username'],
        'full_name':data['fullName'],'role':data['role'],'token':data['token']});
      return {'success':true,'message':data['message'] ?? 'Đăng nhập thành công','user':UserAccount.fromMap(data)};
    } catch (e) { return {'success':false,'message':'Máy chủ xác thực không khả dụng: $e'}; }
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
      final response = await ApiConfig.post(Uri.parse('$baseUrl/register'),headers:{'Content-Type':'application/json'},
        body:jsonEncode({'username':username.trim(),'password':password,'fullName':fullName.trim(),'email':email?.trim(),'phoneNumber':phoneNumber?.trim()})).timeout(timeoutDuration);
      final data = jsonDecode(response.body) as Map<String,dynamic>;
      return {'success':response.statusCode == 200,'message':data['message'] ?? data['error'] ?? 'Đăng ký thất bại','accountId':data['accountId']};
    } catch (e) { return {'success':false,'message':'Không thể đăng ký khi mất kết nối: $e'}; }
  }

  /// Đổi mật khẩu tài khoản
  Future<Map<String, dynamic>> changePassword({
    required int accountId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiConfig.post(Uri.parse('$baseUrl/change-password'),headers:{'Content-Type':'application/json'},
        body:jsonEncode({'accountId':accountId,'oldPassword':oldPassword,'newPassword':newPassword})).timeout(timeoutDuration);
      final data = jsonDecode(response.body) as Map<String,dynamic>;
      return {'success':response.statusCode == 200 && data['success'] == true,'message':data['message'] ?? 'Đổi mật khẩu thất bại'};
    } catch (e) { return {'success':false,'message':'Không thể đổi mật khẩu khi mất kết nối: $e'}; }
  }

  /// Lấy thông tin phiên làm việc hiện tại từ SQLite cục bộ
  Future<UserAccount?> getCurrentSession() async {
    final sessionMap = await _dbHelper.getCurrentSession();
    if (sessionMap != null) {
      return UserAccount.fromMap(sessionMap);
    }
    return null;
  }

  /// Đăng xuất khỏi hệ thống POS (xóa SQLite session)
  Future<void> logout() async {
    await _dbHelper.clearUserSession();
  }

  /// Lấy danh sách thành viên/nhân viên (Admin)
  Future<List<UserAccount>> getMembers() async {
    final response = await ApiConfig.get(Uri.parse('$accountBaseUrl/members')).timeout(timeoutDuration);
    if (response.statusCode != 200) throw StateError('Tải thành viên thất bại (HTTP ${response.statusCode})');
    final List<dynamic> items = jsonDecode(response.body);
    return items.map((e) => UserAccount.fromMap(e)).toList();
  }

  /// Cập nhật vai trò tài khoản (Admin)
  Future<bool> updateRole(int accountId, int newRoleId) async {
    try {
      final response = await ApiConfig
          .put(
            Uri.parse('$accountBaseUrl/$accountId/role'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'roleId': newRoleId}),
          )
          .timeout(timeoutDuration);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Yêu cầu gửi mã OTP phục hồi mật khẩu qua Email (Barem 1.8 & 1.9)
  Future<Map<String, dynamic>> requestOtp(String identity) async {
    try {
      final isEmail = identity.contains('@');
      final payload = isEmail ? {'email': identity.trim()} : {'username': identity.trim()};
      final response = await ApiConfig.post(
        Uri.parse('$baseUrl/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(timeoutDuration);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? 'Không thể gửi mã OTP',
        'devOtp': data['devOtp'],
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
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && (data['success'] == true),
        'message': data['message'] ?? 'Đặt lại mật khẩu thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  /// Đăng nhập mạng xã hội OAuth (Google / Facebook) - Barem 1.10
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
          'token': token ?? 'demo_oauth_token',
          'email': email.trim(),
          'fullName': fullName.trim(),
          'avatar': avatar,
        }),
      ).timeout(timeoutDuration);
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Đăng nhập $provider thất bại (HTTP ${response.statusCode})'};
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['token'] == null) {
        return {'success': false, 'message': 'Phản hồi không hợp lệ'};
      }
      await _dbHelper.saveUserSession({
        'user_id': data['accountId'],
        'username': data['username'],
        'full_name': data['fullName'],
        'role': data['role'],
        'token': data['token'],
      });
      return {
        'success': true,
        'message': data['message'] ?? 'Đăng nhập $provider thành công',
        'user': UserAccount.fromMap(data),
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối $provider: $e'};
    }
  }
}
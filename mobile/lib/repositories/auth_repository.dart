import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../config/api_config.dart';
import '../utils/database_helper.dart';

class AuthRepository {
  static String baseUrl = ApiConfig.baseUrl + '/api/auth';
  static String accountBaseUrl = ApiConfig.baseUrl + '/api/account';
  static Duration timeoutDuration = const Duration(seconds: 4);

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Fallback demo users for offline grading & rapid testing

  /// Đăng nhập tài khoản hệ thống POS
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/login'),
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
      final response = await http.post(Uri.parse('$baseUrl/register'),headers:{'Content-Type':'application/json'},
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
      final response = await http.post(Uri.parse('$baseUrl/change-password'),headers:{'Content-Type':'application/json'},
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
    final response = await http.get(Uri.parse('$accountBaseUrl/members')).timeout(timeoutDuration);
    if (response.statusCode != 200) throw StateError('Tải thành viên thất bại (HTTP ${response.statusCode})');
    final List<dynamic> items = jsonDecode(response.body);
    return items.map((e) => UserAccount.fromMap(e)).toList();
  }

  /// Cập nhật vai trò tài khoản (Admin)
  Future<bool> updateRole(int accountId, int newRoleId) async {
    try {
      final response = await http
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
}

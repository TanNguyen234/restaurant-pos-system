import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import '../utils/database_helper.dart';

/// Run: flutter run --dart-define=POS_API_BASE_URL=http://YOUR_LAN_IP:5138
class ApiConfig {
  static const String _envUrl = String.fromEnvironment('POS_API_BASE_URL');
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5138';
    }
    return 'http://localhost:5138';
  }

  /// Thông báo lỗi dễ hiểu cho người dùng. Lỗi mất kết nối (backend chưa chạy / sai cổng) không hiện nguyên văn SocketException.
  static String describeError(Object error, String action) {
    final text = error.toString();
    final isNetwork = text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Connection refused') ||
        text.contains('Failed host lookup') ||
        text.contains('refused the network connection');
    if (isNetwork) {
      return '$action thất bại: không kết nối được máy chủ ($baseUrl). Kiểm tra backend đã chạy rồi thử lại.';
    }
    return '$action thất bại: $text';
  }

  static Future<Map<String, String>> authHeaders() async {
    try {
      final session = await DatabaseHelper().getCurrentSession();
      final token = session?['token']?.toString();
      return token == null || token.isEmpty ? {} : {'Authorization': 'Bearer $token'};
    } catch (_) {
      return {};
    }
  }

  static Future<http.Response> get(Uri uri, {Map<String, String>? headers}) async =>
      http.get(uri, headers: {...await authHeaders(), ...?headers});

  static Future<http.Response> post(Uri uri, {Map<String, String>? headers, Object? body}) async =>
      http.post(uri, headers: {...await authHeaders(), ...?headers}, body: body);

  static Future<http.Response> put(Uri uri, {Map<String, String>? headers, Object? body}) async =>
      http.put(uri, headers: {...await authHeaders(), ...?headers}, body: body);

  static Future<http.Response> delete(Uri uri, {Map<String, String>? headers, Object? body}) async =>
      http.delete(uri, headers: {...await authHeaders(), ...?headers}, body: body);
}

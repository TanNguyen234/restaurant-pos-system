import 'package:http/http.dart' as http;
import '../utils/database_helper.dart';

/// Run: flutter run --dart-define=POS_API_BASE_URL=http://YOUR_LAN_IP:5138
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'POS_API_BASE_URL', defaultValue: 'http://10.0.2.2:5138',
  );

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

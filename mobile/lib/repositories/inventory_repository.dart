import 'dart:convert';
import '../config/api_config.dart';

class InventoryRepository {
  static String get baseUrl => '${ApiConfig.baseUrl}/api/inventory';
  static const Duration timeoutDuration = Duration(seconds: 8);

  static Map<String, dynamic> _decodeMap(List<int> bodyBytes) {
    try {
      final d = jsonDecode(utf8.decode(bodyBytes));
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> getIngredients({String? search, bool lowStockOnly = false}) async {
    final q = <String, String>{};
    if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();
    if (lowStockOnly) q['lowStockOnly'] = 'true';
    final uri = Uri.parse('$baseUrl/ingredients').replace(queryParameters: q.isEmpty ? null : q);
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    final map = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(map['message']?.toString() ?? 'Không tải được tồn kho (HTTP ${res.statusCode})');
    }
    final raw = (map['data'] as List?) ?? [];
    return {
      'lowStockCount': (map['lowStockCount'] as num?)?.toInt() ?? 0,
      'data': raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
    };
  }

  static Future<Map<String, dynamic>> createIngredient(Map<String, dynamic> payload) async {
    final res = await ApiConfig.post(
      Uri.parse('$baseUrl/ingredients'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    return {'success': res.statusCode == 200 && d['success'] == true, ...d};
  }

  static Future<Map<String, dynamic>> updateIngredient(int id, Map<String, dynamic> payload) async {
    final res = await ApiConfig.put(
      Uri.parse('$baseUrl/ingredients/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    return {'success': res.statusCode == 200 && d['success'] == true, ...d};
  }

  static Future<Map<String, dynamic>> deleteIngredient(int id) async {
    final res = await ApiConfig.delete(
      Uri.parse('$baseUrl/ingredients/$id'),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    return {'success': res.statusCode == 200 && d['success'] == true, ...d};
  }

  static Future<Map<String, dynamic>> adjustStock({
    required int ingredientId,
    required double changeAmount,
    required String type,
    String? note,
  }) async {
    final res = await ApiConfig.post(
      Uri.parse('$baseUrl/ingredients/$ingredientId/adjust'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'changeAmount': changeAmount,
        'type': type,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    return {'success': res.statusCode == 200 && d['success'] == true, ...d};
  }

  static Future<List<Map<String, dynamic>>> getRecipes(int productId) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/recipes/$productId')).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'Không tải được định lượng (HTTP ${res.statusCode})');
    }
    final raw = (d['data'] as List?) ?? [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> getRecipeBundle(int productId) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/recipes/$productId')).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'Không tải được định lượng (HTTP ${res.statusCode})');
    }
    final recipes = ((d['data'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final attrRecipes = ((d['attributeRecipes'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return {'recipes': recipes, 'attributeRecipes': attrRecipes};
  }

  static Future<Map<String, dynamic>> saveRecipes(int productId, List<Map<String, dynamic>> items) async {
    final res = await ApiConfig.put(
      Uri.parse('$baseUrl/recipes/$productId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(items),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    return {'success': res.statusCode == 200 && d['success'] == true, ...d};
  }

  static Future<List<Map<String, dynamic>>> getAttributeRecipes(int attributeId) async {
    final res = await ApiConfig.get(Uri.parse('$baseUrl/attribute-recipes/$attributeId')).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'Không tải được định lượng tùy chọn');
    }
    final raw = (d['data'] as List?) ?? [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> saveAttributeRecipes(int attributeId, List<Map<String, dynamic>> items) async {
    final res = await ApiConfig.put(
      Uri.parse('$baseUrl/attribute-recipes/$attributeId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(items),
    ).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    return {'success': res.statusCode == 200 && d['success'] == true, ...d};
  }

  static Future<List<Map<String, dynamic>>> getTransactions({int? ingredientId, int limit = 100}) async {
    final q = <String, String>{'limit': '$limit'};
    if (ingredientId != null) q['ingredientId'] = '$ingredientId';
    final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: q);
    final res = await ApiConfig.get(uri).timeout(timeoutDuration);
    final d = _decodeMap(res.bodyBytes);
    if (res.statusCode != 200) {
      throw StateError(d['message']?.toString() ?? 'Không tải được lịch sử kho (HTTP ${res.statusCode})');
    }
    final raw = (d['data'] as List?) ?? [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

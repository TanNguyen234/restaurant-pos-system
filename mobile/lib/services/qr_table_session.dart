import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/table_repository.dart';

/// Quản lý ngữ cảnh bàn tự phục vụ khi khách quét mã QR (`/?tableId=X`) và mã xác thực đơn khách vãng lai (`guestToken`).
class QrTableSession {
  QrTableSession._internal();
  static final QrTableSession instance = QrTableSession._internal();

  static const String _kGuestTokensPrefKey = 'pos_guest_order_tokens_v1';

  final ValueNotifier<int?> activeTableIdNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<String?> activeTableNameNotifier = ValueNotifier<String?>(null);
  final Map<int, String> _guestTokens = <int, String>{};
  bool _loadedFromPrefs = false;

  int? get activeTableId => activeTableIdNotifier.value;
  String? get activeTableName => activeTableNameNotifier.value;
  bool get isQrOrderMode => activeTableIdNotifier.value != null && activeTableIdNotifier.value! > 0;

  /// Tách `tableId` từ query string (`/?tableId=3`) hoặc hash fragment (`/#/?tableId=3`).
  @visibleForTesting
  static int? parseTableIdFromUri(Uri uri) {
    final direct = uri.queryParameters['tableId'] ?? uri.queryParameters['table_id'];
    if (direct != null) {
      final parsed = int.tryParse(direct.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    if (uri.fragment.contains('?')) {
      final fragQuery = uri.fragment.split('?').last;
      final fragParams = Uri.splitQueryString(fragQuery);
      final raw = fragParams['tableId'] ?? fragParams['table_id'];
      if (raw != null) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  Future<void> _loadStoredTokens() async {
    if (_loadedFromPrefs) return;
    _loadedFromPrefs = true;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 250));
      final raw = prefs.getString(_kGuestTokensPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            final oid = int.tryParse(k.toString());
            final tok = v?.toString();
            if (oid != null && tok != null && tok.isNotEmpty) {
              _guestTokens[oid] = tok;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> saveGuestToken(int orderId, String? guestToken) async {
    if (orderId <= 0 || guestToken == null || guestToken.trim().isEmpty) return;
    _guestTokens[orderId] = guestToken.trim();
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 250));
      final map = _guestTokens.map((k, v) => MapEntry('$k', v));
      await prefs.setString(_kGuestTokensPrefKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<String?> getGuestToken(int orderId) async {
    if (_guestTokens.containsKey(orderId)) return _guestTokens[orderId];
    await _loadStoredTokens();
    return _guestTokens[orderId];
  }

  Future<void> initFromUri(Uri uri) async {
    await _loadStoredTokens();
    final tableId = parseTableIdFromUri(uri);
    if (tableId == null) return;
    activeTableIdNotifier.value = tableId;
    activeTableNameNotifier.value = 'Bàn #$tableId';
    try {
      final tables = await TableRepository.getAllTables();
      final match = tables.where((t) => t.id == tableId).toList();
      if (match.isNotEmpty) {
        activeTableNameNotifier.value = match.first.name;
      }
    } catch (_) {}
  }

  void setTable(int tableId, String tableName) {
    activeTableIdNotifier.value = tableId;
    activeTableNameNotifier.value = tableName;
  }

  void clear() {
    activeTableIdNotifier.value = null;
    activeTableNameNotifier.value = null;
  }
}

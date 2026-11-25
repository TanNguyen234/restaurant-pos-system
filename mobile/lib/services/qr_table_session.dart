import 'package:flutter/foundation.dart';
import '../repositories/table_repository.dart';

/// Quản lý ngữ cảnh bàn tự phục vụ khi khách quét mã QR (`/?tableId=X`).
class QrTableSession {
  QrTableSession._internal();
  static final QrTableSession instance = QrTableSession._internal();

  final ValueNotifier<int?> activeTableIdNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<String?> activeTableNameNotifier = ValueNotifier<String?>(null);

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

  Future<void> initFromUri(Uri uri) async {
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

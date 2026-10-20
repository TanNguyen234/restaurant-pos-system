import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';
import 'package:restaurant_pos_app/services/offline_sync_service.dart';

void main() {
  setUpAll(() {
    TableRepository.timeoutDuration = const Duration(milliseconds: 100);
  });

  group('TableRepository Offline Fallback Tests', () {
    test('getAreas returns default 4 F&B areas when offline', () async {
      final areas = await TableRepository.getAreas();
      expect(areas.length, 4);
      expect(areas.any((a) => a.name.contains('Tầng 1')), true);
      expect(areas.any((a) => a.name.contains('Tầng 2')), true);
      expect(areas.any((a) => a.name.contains('Sân vườn')), true);
      expect(areas.any((a) => a.name.contains('VIP')), true);
    });

    test('getTablesByArea returns correct tables for area 1', () async {
      final tables = await TableRepository.getTablesByArea(1);
      expect(tables.isNotEmpty, true);
      expect(tables.every((t) => t.areaId == 1), true);
    });

    test('getAllTables returns all restaurant tables', () async {
      final allTables = await TableRepository.getAllTables();
      expect(allTables.length, greaterThanOrEqualTo(10));
    });

    test('updateStatus updates local fallback table status', () async {
      // Update table 1 status to 1 (Occupied)
      final success = await TableRepository.updateStatus(1, 1);
      expect(success, true);

      final tables = await TableRepository.getAllTables();
      final table1 = tables.firstWhere((t) => t.id == 1);
      expect(table1.status, 1);

      // Reset back to 0 (Available)
      await TableRepository.updateStatus(1, 0);
      final resetTables = await TableRepository.getAllTables();
      expect(resetTables.firstWhere((t) => t.id == 1).status, 0);
    });

    test('transferTable swaps table state properly in fallback mode', () async {
      // Set table 1 to occupied (status 1)
      await TableRepository.updateStatus(1, 1);
      // Ensure table 3 is available (status 0)
      await TableRepository.updateStatus(3, 0);

      final transferSuccess = await TableRepository.transferTable(1, 3);
      expect(transferSuccess, true);

      final tables = await TableRepository.getAllTables();
      final source = tables.firstWhere((t) => t.id == 1);
      final target = tables.firstWhere((t) => t.id == 3);

      expect(source.status, 0); // Source becomes available
      expect(target.status, 1); // Target becomes occupied

      // Cleanup
      await TableRepository.updateStatus(3, 0);
    });
  });

  group('OfflineSyncService Tests', () {
    test('OfflineSyncService is a singleton', () {
      final s1 = OfflineSyncService();
      final s2 = OfflineSyncService();
      expect(identical(s1, s2), true);
    });

    test('SyncResult formatted string', () {
      final result = SyncResult(
        total: 5,
        synced: 5,
        failed: 0,
        message: 'Hoàn thành đồng bộ',
      );
      expect(result.total, 5);
      expect(result.synced, 5);
      expect(result.failed, 0);
      expect(result.toString(), contains('total: 5'));
    });
  });
}

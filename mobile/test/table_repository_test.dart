import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';
import 'package:restaurant_pos_app/services/offline_sync_service.dart';

void main() {
  setUpAll(() {
    TableRepository.timeoutDuration = const Duration(milliseconds: 100);
  });

  group('TableRepository Genuine Network Error Handling Tests (No Mock Fallbacks)', () {
    test('getAreas throws Exception on network failure when backend is unreachable', () async {
      expect(() => TableRepository.getAreas(), throwsA(isA<Exception>()));
    });

    test('getTablesByArea throws Exception on network failure when backend is unreachable', () async {
      expect(() => TableRepository.getTablesByArea(1), throwsA(isA<Exception>()));
    });

    test('getAllTables throws Exception on network failure when backend is unreachable', () async {
      expect(() => TableRepository.getAllTables(), throwsA(isA<Exception>()));
    });

    test('updateStatus returns false without fake in-memory mutation on network failure', () async {
      final success = await TableRepository.updateStatus(1, 1);
      expect(success, false);
    });

    test('transferTable returns false without fake in-memory mutation on network failure', () async {
      final transferSuccess = await TableRepository.transferTable(1, 3);
      expect(transferSuccess, false);
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

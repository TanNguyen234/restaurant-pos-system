import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/area.dart';
import 'package:restaurant_pos_app/models/dining_table.dart';

void main() {
  group('Area Model Tests', () {
    test('Area fromMap and toMap serialization', () {
      final map = {
        'areaId': 1,
        'areaName': 'Tầng 1 - Phòng lạnh',
        'description': 'Khu vực máy lạnh trong nhà',
        'sortOrder': 1,
        'isActive': true,
      };

      final area = Area.fromMap(map);
      expect(area.id, 1);
      expect(area.name, 'Tầng 1 - Phòng lạnh');
      expect(area.description, 'Khu vực máy lạnh trong nhà');
      expect(area.sortOrder, 1);
      expect(area.isActive, true);

      final toMap = area.toMap();
      expect(toMap['areaId'], 1);
      expect(toMap['areaName'], 'Tầng 1 - Phòng lạnh');
      expect(toMap['isActive'], true);
    });

    test('Area fromMap with fallback id and name keys', () {
      final map = {
        'id': 2,
        'name': 'Sân vườn',
      };

      final area = Area.fromMap(map);
      expect(area.id, 2);
      expect(area.name, 'Sân vườn');
      expect(area.sortOrder, 0);
      expect(area.isActive, true);
    });
  });

  group('DiningTable Model Tests', () {
    test('DiningTable fromMap and toMap serialization', () {
      final now = DateTime.now();
      final map = {
        'tableId': 10,
        'areaId': 2,
        'tableName': 'Bàn T2-04',
        'capacity': 6,
        'status': 0,
        'currentOrderId': null,
        'updatedAt': now.toIso8601String(),
      };

      final table = DiningTable.fromMap(map);
      expect(table.id, 10);
      expect(table.areaId, 2);
      expect(table.name, 'Bàn T2-04');
      expect(table.capacity, 6);
      expect(table.status, 0);
      expect(table.isAvailable, true);
      expect(table.isOccupied, false);
      expect(table.isReserved, false);
      expect(table.statusText, 'Trống');
      expect(table.statusColor, const Color(0xFF2E7D32));
      expect(table.statusBackgroundColor, const Color(0xFFE8F5E9));

      final toMap = table.toMap();
      expect(toMap['tableId'], 10);
      expect(toMap['tableName'], 'Bàn T2-04');
      expect(toMap['status'], 0);
    });

    test('DiningTable status helpers for Occupied (1) and Reserved (2)', () {
      final occupiedTable = DiningTable(
        id: 1,
        areaId: 1,
        name: 'Bàn T1-01',
        capacity: 4,
        status: 1,
        currentOrderId: 99,
      );

      expect(occupiedTable.isAvailable, false);
      expect(occupiedTable.isOccupied, true);
      expect(occupiedTable.isReserved, false);
      expect(occupiedTable.statusText, 'Có khách');
      expect(occupiedTable.statusColor, const Color(0xFFC62828));
      expect(occupiedTable.statusBackgroundColor, const Color(0xFFFFEBEE));

      final reservedTable = occupiedTable.copyWith(status: 2);
      expect(reservedTable.isAvailable, false);
      expect(reservedTable.isOccupied, false);
      expect(reservedTable.isReserved, true);
      expect(reservedTable.statusText, 'Đã đặt trước');
      expect(reservedTable.statusColor, const Color(0xFFEF6C00));
      expect(reservedTable.statusBackgroundColor, const Color(0xFFFFF3E0));
    });

    test('DiningTable copyWith preserves unprovided properties', () {
      final table = DiningTable(
        id: 5,
        areaId: 1,
        name: 'Bàn T1-05',
        capacity: 4,
        status: 0,
      );

      final updated = table.copyWith(status: 1, currentOrderId: 105);
      expect(updated.id, 5);
      expect(updated.name, 'Bàn T1-05');
      expect(updated.status, 1);
      expect(updated.currentOrderId, 105);
    });
  });
}

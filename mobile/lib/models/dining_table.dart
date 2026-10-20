import 'package:flutter/material.dart';

class DiningTable {
  final int id;
  final int areaId;
  final String name;
  final int capacity;
  int status; // 0: Trống, 1: Có khách, 2: Chờ phục vụ / Đã đặt trước
  final int? currentOrderId;
  final DateTime? updatedAt;

  DiningTable({
    required this.id,
    required this.areaId,
    required this.name,
    required this.capacity,
    required this.status,
    this.currentOrderId,
    this.updatedAt,
  });

  bool get isAvailable => status == 0;
  bool get isOccupied => status == 1;
  bool get isReserved => status == 2;

  String get statusText {
    switch (status) {
      case 0:
        return 'Trống';
      case 1:
        return 'Có khách';
      case 2:
        return 'Đã đặt trước';
      default:
        return 'Khác';
    }
  }

  Color get statusColor {
    switch (status) {
      case 0:
        return const Color(0xFF2E7D32); // Green #2E7D32
      case 1:
        return const Color(0xFFC62828); // Red #C62828
      case 2:
        return const Color(0xFFEF6C00); // Orange #EF6C00
      default:
        return Colors.grey;
    }
  }

  Color get statusBackgroundColor {
    switch (status) {
      case 0:
        return const Color(0xFFE8F5E9); // Light green #E8F5E9
      case 1:
        return const Color(0xFFFFEBEE); // Light red #FFEBEE
      case 2:
        return const Color(0xFFFFF3E0); // Light orange #FFF3E0
      default:
        return Colors.grey.shade100;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 0:
        return Icons.check_circle_outline;
      case 1:
        return Icons.restaurant;
      case 2:
        return Icons.bookmark_border;
      default:
        return Icons.info_outline;
    }
  }

  DiningTable copyWith({
    int? id,
    int? areaId,
    String? name,
    int? capacity,
    int? status,
    int? currentOrderId,
    DateTime? updatedAt,
  }) {
    return DiningTable(
      id: id ?? this.id,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DiningTable.fromMap(Map<String, dynamic> map) {
    return DiningTable(
      id: map['tableId'] ?? map['id'] ?? 0,
      areaId: map['areaId'] ?? 0,
      name: map['tableName'] ?? map['name'] ?? '',
      capacity: map['capacity'] ?? 4,
      status: map['status'] ?? 0,
      currentOrderId: map['currentOrderId'],
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tableId': id,
      'areaId': areaId,
      'tableName': name,
      'capacity': capacity,
      'status': status,
      'currentOrderId': currentOrderId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'DiningTable(id: $id, areaId: $areaId, name: $name, capacity: $capacity, status: $status)';
}

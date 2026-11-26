import 'package:flutter/material.dart';

class DiningTable {
  final int id;
  final int areaId;
  final String name;
  final int capacity;
  int status; // 0: Trống, 1: Có khách, 2: Chờ phục vụ, 3: Đặt trước
  final int? currentOrderId;
  final DateTime? updatedAt;
  final DateTime? orderCreatedAt;
  final double runningTotal;
  final int itemCount;
  final int? nextReservationId;
  final String? nextReservationCustomer;
  final DateTime? nextReservationTime;
  final DateTime? nextReservationExpiresAt;
  final double? nextReservationDeposit;

  DiningTable({
    required this.id,
    required this.areaId,
    required this.name,
    required this.capacity,
    required this.status,
    this.currentOrderId,
    this.updatedAt,
    this.orderCreatedAt,
    this.runningTotal = 0.0,
    this.itemCount = 0,
    this.nextReservationId,
    this.nextReservationCustomer,
    this.nextReservationTime,
    this.nextReservationExpiresAt,
    this.nextReservationDeposit,
  });

  bool get isAvailable => status == 0;
  bool get isOccupied => status == 1 || status == 2;
  bool get isWaiting => status == 2;
  bool get isReserved => status == 3;

  Duration? get seatingDuration =>
      (orderCreatedAt != null && isOccupied) ? DateTime.now().difference(orderCreatedAt!) : null;

  String get seatingDurationText {
    final dur = seatingDuration;
    if (dur == null || !isOccupied) return '';
    if (dur.isNegative || dur.inMinutes < 1) return '<1p';
    final totalMins = dur.inMinutes;
    if (totalMins < 60) {
      return '$totalMins phút';
    }
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    return '${hours}h ${mins}p';
  }

  String get statusText {
    switch (status) {
      case 0:
        return 'Trống';
      case 1:
        return 'Có khách';
      case 2:
        return 'Chờ phục vụ';
      case 3:
        return 'Đã đặt trước';
      default:
        return 'Khác';
    }
  }

  Color get statusColor {
    switch (status) {
      case 0:
        return const Color(0xFF059669);
      case 1:
        return const Color(0xFFDC2626);
      case 2:
        return const Color(0xFFD97706);
      case 3:
        return const Color(0xFF0284C7);
      default:
        return Colors.grey;
    }
  }

  Color get statusBackgroundColor {
    switch (status) {
      case 0:
        return const Color(0xFFECFDF5);
      case 1:
        return const Color(0xFFFEF2F2);
      case 2:
        return const Color(0xFFFFFBEB);
      case 3:
        return const Color(0xFFE0F2FE);
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
        return Icons.hourglass_top_rounded;
      case 3:
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
    DateTime? orderCreatedAt,
    double? runningTotal,
    int? itemCount,
  }) {
    return DiningTable(
      id: id ?? this.id,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      updatedAt: updatedAt ?? this.updatedAt,
      orderCreatedAt: orderCreatedAt ?? this.orderCreatedAt,
      runningTotal: runningTotal ?? this.runningTotal,
      itemCount: itemCount ?? this.itemCount,
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
      orderCreatedAt: map['orderCreatedAt'] != null
          ? DateTime.tryParse(map['orderCreatedAt'].toString())
          : null,
      runningTotal: (map['runningTotal'] as num?)?.toDouble() ?? 0.0,
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      nextReservationId: (map['nextReservationId'] as num?)?.toInt(),
      nextReservationCustomer: map['nextReservationCustomer']?.toString(),
      nextReservationTime: map['nextReservationTime'] != null
          ? DateTime.tryParse(map['nextReservationTime'].toString())
          : null,
      nextReservationExpiresAt: map['nextReservationExpiresAt'] != null
          ? DateTime.tryParse(map['nextReservationExpiresAt'].toString())
          : null,
      nextReservationDeposit: (map['nextReservationDeposit'] as num?)?.toDouble(),
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
      'orderCreatedAt': orderCreatedAt?.toIso8601String(),
      'runningTotal': runningTotal,
      'itemCount': itemCount,
      'nextReservationId': nextReservationId,
      'nextReservationCustomer': nextReservationCustomer,
      'nextReservationTime': nextReservationTime?.toIso8601String(),
      'nextReservationExpiresAt': nextReservationExpiresAt?.toIso8601String(),
      'nextReservationDeposit': nextReservationDeposit,
    };
  }

  @override
  String toString() =>
      'DiningTable(id: $id, areaId: $areaId, name: $name, capacity: $capacity, status: $status)';
}

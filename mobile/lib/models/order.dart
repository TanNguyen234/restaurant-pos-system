class OrderModel {
  final int orderId;
  final String orderCode;
  final int? tableId;
  final String tableName;
  final int? accountId;
  final String customerName;
  final String? phoneNumber;
  final int orderType; // 1: Tại bàn, 2: Mang về, 3: Giao hàng
  final String? note;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final int status; // 0: Mới, 1: Đang chế biến, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy
  final String statusText;
  final int paymentStatus; // 0: Chưa thanh toán, 1: Đã thanh toán
  final String paymentStatusText;
  final String? paymentMethod;
  final int totalItems;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.orderId,
    required this.orderCode,
    this.tableId,
    required this.tableName,
    this.accountId,
    required this.customerName,
    this.phoneNumber,
    this.orderType = 1,
    this.note,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    required this.status,
    required this.statusText,
    required this.paymentStatus,
    required this.paymentStatusText,
    this.paymentMethod,
    this.totalItems = 0,
    required this.createdAt,
    this.completedAt,
    this.items = const [],
  });

  bool get isPaid => paymentStatus == 1;
  bool get isCompleted => status == 3;
  bool get isCancelled => status == 4;

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    List<OrderItemModel> parsedItems = [];
    if (map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((i) => OrderItemModel.fromMap(i as Map<String, dynamic>))
          .toList();
    }

    return OrderModel(
      orderId: map['orderId'] ?? map['id'] ?? 0,
      orderCode: map['orderCode'] ?? 'ORD-${map['orderId'] ?? 0}',
      tableId: map['tableId'],
      tableName: map['tableName'] ?? (map['tableId'] != null ? 'Bàn #${map['tableId']}' : 'Mang về'),
      accountId: map['accountId'],
      customerName: map['customerName'] ?? 'Khách vãng lai',
      phoneNumber: map['phoneNumber'],
      orderType: map['orderType'] ?? 1,
      note: map['note'],
      totalAmount: (map['totalAmount'] as num? ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] as num? ?? 0).toDouble(),
      finalAmount: (map['finalAmount'] as num? ?? map['totalAmount'] as num? ?? 0).toDouble(),
      status: map['status'] ?? 0,
      statusText: map['statusText'] ?? resolveStatusText(map['status'] ?? 0),
      paymentStatus: map['paymentStatus'] ?? 0,
      paymentStatusText: map['paymentStatusText'] ?? ((map['paymentStatus'] ?? 0) == 1 ? 'Đã thanh toán' : 'Chưa thanh toán'),
      paymentMethod: map['paymentMethod'],
      totalItems: map['totalItems'] ?? parsedItems.length,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderCode': orderCode,
      'tableId': tableId,
      'tableName': tableName,
      'accountId': accountId,
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'orderType': orderType,
      'note': note,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'status': status,
      'statusText': statusText,
      'paymentStatus': paymentStatus,
      'paymentStatusText': paymentStatusText,
      'paymentMethod': paymentMethod,
      'totalItems': totalItems,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  static String resolveStatusText(int status) {
    switch (status) {
      case 0:
        return 'Mới tạo';
      case 1:
        return 'Đang chế biến';
      case 2:
        return 'Đã phục vụ';
      case 3:
        return 'Hoàn thành';
      case 4:
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }
}

class OrderItemModel {
  final int orderDetailId;
  final int productId;
  final String productName;
  final String productImage;
  final int quantity;
  final double unitPrice;
  final double subTotal;
  final String? itemNote;
  final int cookingStatus; // 0: Chờ nấu, 1: Đang làm, 2: Đã nấu xong
  final String cookingStatusText;
  final DateTime? startedCookingAt;
  final DateTime? finishedCookingAt;

  OrderItemModel({
    required this.orderDetailId,
    required this.productId,
    required this.productName,
    this.productImage = 'default.png',
    required this.quantity,
    required this.unitPrice,
    required this.subTotal,
    this.itemNote,
    this.cookingStatus = 0,
    required this.cookingStatusText,
    this.startedCookingAt,
    this.finishedCookingAt,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      orderDetailId: map['orderDetailId'] ?? map['id'] ?? 0,
      productId: map['productId'] ?? 0,
      productName: map['productName'] ?? 'Món #${map['productId'] ?? 0}',
      productImage: map['productImage'] ?? 'default.png',
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unitPrice'] as num? ?? 0).toDouble(),
      subTotal: (map['subTotal'] as num? ?? 0).toDouble(),
      itemNote: map['itemNote'],
      cookingStatus: map['cookingStatus'] ?? 0,
      cookingStatusText: map['cookingStatusText'] ?? resolveCookingStatusText(map['cookingStatus'] ?? 0),
      startedCookingAt: map['startedCookingAt'] != null
          ? DateTime.tryParse(map['startedCookingAt'].toString())
          : null,
      finishedCookingAt: map['finishedCookingAt'] != null
          ? DateTime.tryParse(map['finishedCookingAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderDetailId': orderDetailId,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subTotal': subTotal,
      'itemNote': itemNote,
      'cookingStatus': cookingStatus,
      'cookingStatusText': cookingStatusText,
      'startedCookingAt': startedCookingAt?.toIso8601String(),
      'finishedCookingAt': finishedCookingAt?.toIso8601String(),
    };
  }

  static String resolveCookingStatusText(int status) {
    switch (status) {
      case 0:
        return 'Chờ nấu';
      case 1:
        return 'Đang làm';
      case 2:
        return 'Đã nấu xong';
      case 3:
        return 'Đã ra món';
      default:
        return 'Chờ nấu';
    }
  }
}

class KdsItemModel {
  final int orderDetailId;
  final int orderId;
  final String orderCode;
  final int? tableId;
  final String tableName;
  final String customerName;
  final int productId;
  final String productName;
  final String productImage;
  final int quantity;
  final String? itemNote;
  final int cookingStatus; // 0: Chờ nấu, 1: Đang làm, 2: Đã nấu xong
  final String cookingStatusText;
  final DateTime createdAt;
  final DateTime? startedCookingAt;
  final DateTime? finishedCookingAt;

  KdsItemModel({
    required this.orderDetailId,
    required this.orderId,
    required this.orderCode,
    this.tableId,
    required this.tableName,
    required this.customerName,
    required this.productId,
    required this.productName,
    this.productImage = 'default.png',
    required this.quantity,
    this.itemNote,
    required this.cookingStatus,
    required this.cookingStatusText,
    required this.createdAt,
    this.startedCookingAt,
    this.finishedCookingAt,
  });

  factory KdsItemModel.fromMap(Map<String, dynamic> map) {
    return KdsItemModel(
      orderDetailId: map['orderDetailId'] ?? map['id'] ?? 0,
      orderId: map['orderId'] ?? 0,
      orderCode: map['orderCode'] ?? 'ORD-#${map['orderId'] ?? 0}',
      tableId: map['tableId'],
      tableName: map['tableName'] ?? (map['tableId'] != null ? 'Bàn #${map['tableId']}' : 'Mang về'),
      customerName: map['customerName'] ?? 'Khách vãng lai',
      productId: map['productId'] ?? 0,
      productName: map['productName'] ?? 'Món #${map['productId'] ?? 0}',
      productImage: map['productImage'] ?? 'default.png',
      quantity: map['quantity'] ?? 1,
      itemNote: map['itemNote'],
      cookingStatus: map['cookingStatus'] ?? 0,
      cookingStatusText: map['cookingStatusText'] ?? OrderItemModel.resolveCookingStatusText(map['cookingStatus'] ?? 0),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startedCookingAt: map['startedCookingAt'] != null
          ? DateTime.tryParse(map['startedCookingAt'].toString())
          : null,
      finishedCookingAt: map['finishedCookingAt'] != null
          ? DateTime.tryParse(map['finishedCookingAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderDetailId': orderDetailId,
      'orderId': orderId,
      'orderCode': orderCode,
      'tableId': tableId,
      'tableName': tableName,
      'customerName': customerName,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'quantity': quantity,
      'itemNote': itemNote,
      'cookingStatus': cookingStatus,
      'cookingStatusText': cookingStatusText,
      'createdAt': createdAt.toIso8601String(),
      'startedCookingAt': startedCookingAt?.toIso8601String(),
      'finishedCookingAt': finishedCookingAt?.toIso8601String(),
    };
  }
}

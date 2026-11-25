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
  final String? discountCode;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double paidAmount;
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
    this.discountCode,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    this.paidAmount = 0,
    required this.status,
    String? statusText,
    required this.paymentStatus,
    String? paymentStatusText,
    this.paymentMethod,
    this.totalItems = 0,
    required this.createdAt,
    this.completedAt,
    this.items = const [],
  })  : statusText = statusText ?? resolveStatusText(status),
        paymentStatusText = paymentStatusText ?? ((paymentStatus == 1) ? 'Đã thanh toán' : 'Chưa thanh toán');

  bool get isPaid => paymentStatus == 1;
  bool get isCompleted => status == 3;
  bool get isCancelled => status == 4;
  double get remainingAmount => (finalAmount - paidAmount) > 0 ? (finalAmount - paidAmount) : 0;

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] ?? map['details'];
    List<OrderItemModel> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((i) => OrderItemModel.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    }

    return OrderModel(
      orderId: (map['orderId'] ?? map['id'] ?? 0) as int,
      orderCode: (map['orderCode'] ?? 'ORD-${map['orderId'] ?? 0}').toString(),
      tableId: map['tableId'] as int?,
      tableName: (map['tableName'] ?? (map['tableId'] != null ? 'Bàn #${map['tableId']}' : 'Mang về')).toString(),
      accountId: map['accountId'] as int?,
      customerName: (map['customerName'] ?? 'Khách vãng lai').toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      orderType: (map['orderType'] as num? ?? 1).toInt(),
      note: map['note']?.toString(),
      discountCode: map['discountCode']?.toString(),
      totalAmount: (map['totalAmount'] as num? ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] as num? ?? 0).toDouble(),
      finalAmount: (map['finalAmount'] as num? ?? map['totalAmount'] as num? ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] as num? ?? 0).toDouble(),
      status: (map['status'] as num? ?? 0).toInt(),
      statusText: map['statusText']?.toString() ?? resolveStatusText((map['status'] as num? ?? 0).toInt()),
      paymentStatus: (map['paymentStatus'] as num? ?? 0).toInt(),
      paymentStatusText: map['paymentStatusText']?.toString() ??
          (((map['paymentStatus'] as num? ?? 0) == 1) ? 'Đã thanh toán' : 'Chưa thanh toán'),
      paymentMethod: map['paymentMethod']?.toString(),
      totalItems: (map['totalItems'] as num?)?.toInt() ?? parsedItems.length,
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
      'discountCode': discountCode,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'paidAmount': paidAmount,
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
        return 'Đang nấu';
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
  final int cookingStatus; // 0: Chờ nấu, 1: Đang làm, 2: Đã nấu xong, 3: Đã giao, 4: Đã hủy
  final String cookingStatusText;
  final DateTime? startedCookingAt;
  final DateTime? finishedCookingAt;
  final List<Map<String, dynamic>> modifiers;

  OrderItemModel({
    required this.orderDetailId,
    required this.productId,
    required this.productName,
    this.productImage = 'default_product.png',
    required this.quantity,
    required this.unitPrice,
    required this.subTotal,
    this.itemNote,
    this.cookingStatus = 0,
    String? cookingStatusText,
    this.startedCookingAt,
    this.finishedCookingAt,
    this.modifiers = const [],
  }) : cookingStatusText = cookingStatusText ?? resolveCookingStatusText(cookingStatus);

  bool get isVoided => cookingStatus == 4;

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final modsRaw = map['modifiers'];
    final parsedMods = modsRaw is List
        ? modsRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];

    return OrderItemModel(
      orderDetailId: (map['orderDetailId'] ?? map['id'] ?? 0) as int,
      productId: (map['productId'] ?? 0) as int,
      productName: (map['productName'] ?? 'Món #${map['productId'] ?? 0}').toString(),
      productImage: (map['productImage'] ?? map['imageUrl'] ?? 'default_product.png').toString(),
      quantity: (map['quantity'] as num? ?? 1).toInt(),
      unitPrice: (map['unitPrice'] as num? ?? map['price'] as num? ?? 0).toDouble(),
      subTotal: (map['subTotal'] as num? ?? 0).toDouble(),
      itemNote: map['itemNote']?.toString(),
      cookingStatus: (map['cookingStatus'] as num? ?? 0).toInt(),
      cookingStatusText: map['cookingStatusText']?.toString() ??
          resolveCookingStatusText((map['cookingStatus'] as num? ?? 0).toInt()),
      startedCookingAt: map['startedCookingAt'] != null
          ? DateTime.tryParse(map['startedCookingAt'].toString())
          : null,
      finishedCookingAt: map['finishedCookingAt'] != null
          ? DateTime.tryParse(map['finishedCookingAt'].toString())
          : null,
      modifiers: parsedMods,
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
      'modifiers': modifiers,
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
        return 'Đã giao món';
      case 4:
        return 'Đã hủy món';
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
  final int categoryId;
  final String productName;
  final String productImage;
  final int quantity;
  final String? itemNote;
  final int cookingStatus; // 0: Chờ nấu, 1: Đang làm, 2: Đã nấu xong
  final String cookingStatusText;
  final DateTime createdAt;
  final DateTime? startedCookingAt;
  final DateTime? finishedCookingAt;
  final List<Map<String, dynamic>> modifiers;

  DateTime get orderCreatedAt => createdAt;

  KdsItemModel({
    required this.orderDetailId,
    required this.orderId,
    required this.orderCode,
    this.tableId,
    this.tableName = '',
    this.customerName = 'Khách vãng lai',
    this.productId = 0,
    this.categoryId = 0,
    required this.productName,
    this.productImage = 'default_product.png',
    required this.quantity,
    this.itemNote,
    this.cookingStatus = 0,
    String? cookingStatusText,
    DateTime? createdAt,
    DateTime? orderCreatedAt,
    this.startedCookingAt,
    this.finishedCookingAt,
    this.modifiers = const [],
  })  : cookingStatusText = cookingStatusText ?? OrderItemModel.resolveCookingStatusText(cookingStatus),
        createdAt = createdAt ?? orderCreatedAt ?? DateTime.now();

  factory KdsItemModel.fromMap(Map<String, dynamic> map) {
    final rawCreated = map['orderCreatedAt'] ?? map['createdAt'];
    final modsRaw = map['modifiers'];
    final parsedMods = modsRaw is List
        ? modsRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];

    return KdsItemModel(
      orderDetailId: (map['orderDetailId'] ?? map['id'] ?? 0) as int,
      orderId: (map['orderId'] ?? 0) as int,
      orderCode: (map['orderCode'] ?? 'ORD-#${map['orderId'] ?? 0}').toString(),
      tableId: map['tableId'] as int?,
      tableName: (map['tableName'] ?? (map['tableId'] != null ? 'Bàn #${map['tableId']}' : 'Mang về')).toString(),
      customerName: (map['customerName'] ?? 'Khách vãng lai').toString(),
      productId: (map['productId'] ?? 0) as int,
      categoryId: (map['categoryId'] as num? ?? 0).toInt(),
      productName: (map['productName'] ?? 'Món #${map['productId'] ?? 0}').toString(),
      productImage: (map['productImage'] ?? map['imageUrl'] ?? 'default_product.png').toString(),
      quantity: (map['quantity'] as num? ?? 1).toInt(),
      itemNote: map['itemNote']?.toString(),
      cookingStatus: (map['cookingStatus'] as num? ?? 0).toInt(),
      cookingStatusText: map['cookingStatusText']?.toString() ??
          OrderItemModel.resolveCookingStatusText((map['cookingStatus'] as num? ?? 0).toInt()),
      createdAt: rawCreated != null ? DateTime.tryParse(rawCreated.toString()) ?? DateTime.now() : DateTime.now(),
      startedCookingAt: map['startedCookingAt'] != null
          ? DateTime.tryParse(map['startedCookingAt'].toString())
          : null,
      finishedCookingAt: map['finishedCookingAt'] != null
          ? DateTime.tryParse(map['finishedCookingAt'].toString())
          : null,
      modifiers: parsedMods,
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
      'categoryId': categoryId,
      'productName': productName,
      'productImage': productImage,
      'quantity': quantity,
      'itemNote': itemNote,
      'cookingStatus': cookingStatus,
      'cookingStatusText': cookingStatusText,
      'createdAt': createdAt.toIso8601String(),
      'startedCookingAt': startedCookingAt?.toIso8601String(),
      'finishedCookingAt': finishedCookingAt?.toIso8601String(),
      'modifiers': modifiers,
    };
  }
}

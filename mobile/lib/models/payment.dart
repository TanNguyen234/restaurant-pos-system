class PaymentModel {
  final int paymentId;
  final int orderId;
  final String paymentMethod; // 'Cash', 'VietQR', 'VNPay'
  final double amount;
  final String? transactionRef;
  final int status; // 0: Pending, 1: Success, 2: Failed
  final String? note;
  final DateTime paymentTime;

  PaymentModel({
    required this.paymentId,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
    this.transactionRef,
    required this.status,
    this.note,
    required this.paymentTime,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      paymentId: map['paymentId'] ?? map['id'] ?? 0,
      orderId: map['orderId'] ?? 0,
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      amount: (map['amount'] as num? ?? 0).toDouble(),
      transactionRef: map['transactionRef'],
      status: map['status'] ?? 1,
      note: map['note'],
      paymentTime: map['paymentTime'] != null
          ? DateTime.tryParse(map['paymentTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'orderId': orderId,
      'paymentMethod': paymentMethod,
      'amount': amount,
      'transactionRef': transactionRef,
      'status': status,
      'note': note,
      'paymentTime': paymentTime.toIso8601String(),
    };
  }
}

class VietQrModel {
  final int orderId;
  final String orderCode;
  final String bankId;
  final String bankName;
  final String accountNo;
  final String accountName;
  final double amount;
  final String description;
  final String qrImageUrl;

  VietQrModel({
    required this.orderId,
    required this.orderCode,
    required this.bankId,
    required this.bankName,
    required this.accountNo,
    required this.accountName,
    required this.amount,
    required this.description,
    required this.qrImageUrl,
  });

  factory VietQrModel.fromMap(Map<String, dynamic> map) {
    return VietQrModel(
      orderId: map['orderId'] ?? 0,
      orderCode: map['orderCode'] ?? '',
      bankId: map['bankId'] ?? 'MB',
      bankName: map['bankName'] ?? 'MB Bank',
      accountNo: map['accountNo'] ?? '',
      accountName: map['accountName'] ?? '',
      amount: (map['amount'] as num? ?? 0).toDouble(),
      description: map['description'] ?? '',
      qrImageUrl: map['qrImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderCode': orderCode,
      'bankId': bankId,
      'bankName': bankName,
      'accountNo': accountNo,
      'accountName': accountName,
      'amount': amount,
      'description': description,
      'qrImageUrl': qrImageUrl,
    };
  }
}

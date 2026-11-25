class UserAccount {
  final int accountId;
  final int roleId;
  final String username;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? avatar;
  final String role;
  final String roleName;
  final String? token;
  final bool isActive;
  final bool isEmailVerified;
  final int loyaltyPoints;
  final DateTime? createdAt;

  UserAccount({
    required this.accountId,
    required this.roleId,
    required this.username,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.avatar,
    required this.role,
    required this.roleName,
    this.token,
    this.isActive = true,
    this.isEmailVerified = false,
    this.loyaltyPoints = 0,
    this.createdAt,
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isManager => role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'MANAGER';
  bool get isCashier => role.toUpperCase() == 'CASHIER' || isAdmin;
  bool get isWaiter => role.toUpperCase() == 'WAITER' || isAdmin || isManager;
  bool get isChef =>
      role.toUpperCase().contains('CHEF') ||
      role.toUpperCase().contains('BARISTA') ||
      role.toUpperCase().contains('KITCHEN') ||
      role.toUpperCase().contains('COOK');
  bool get isKitchen => isChef || isAdmin || role.toUpperCase() == 'MANAGER';
  bool get isStaff => isAdmin || isManager || isWaiter || isCashier || isChef;
  bool get isMember => role.toUpperCase() == 'MEMBER' || role.toUpperCase() == 'VIP_MEMBER';

  UserAccount copyWith({
    int? roleId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    String? roleName,
    bool? isActive,
    bool? isEmailVerified,
    int? loyaltyPoints,
  }) {
    return UserAccount(
      accountId: accountId,
      roleId: roleId ?? this.roleId,
      username: username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatar: avatar,
      role: role ?? this.role,
      roleName: roleName ?? this.roleName,
      token: token,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt,
    );
  }

  static String sanitizeText(dynamic input) {
    if (input == null) return '';
    String text = input.toString();
    if (text.contains('Báº¿p') || text.contains('TrÆ°á»Ÿng')) {
      text = text.replaceAll('Báº¿p TrÆ°á»Ÿng KDS', 'Bếp Trưởng KDS');
    }
    if (text.contains('Bá»™') || text.contains('pháº') || text.contains('cháº¿')) {
      text = text
          .replaceAll('Bá»™ pháº­n báº¿p & pha cháº¿ (KDS)', 'Bộ phận bếp & pha chế (KDS)')
          .replaceAll('Bá»™ pháºn báº¿p & pha cháº¿ (KDS)', 'Bộ phận bếp & pha chế (KDS)')
          .replaceAll('Bá»™ pháº­n báº¿p \u0026 pha cháº¿ (KDS)', 'Bộ phận bếp & pha chế (KDS)');
    }
    if (text.contains('MÃ\u00A0n') || text.contains('nháº­n')) {
      text = text.replaceAll('MÃ\u00A0n hÃ¬nh KDS nháº­n order vÃ\u00A0 cháº¿ biáº¿n mÃ³n Äƒn', 'Màn hình KDS nhận order và chế biến món ăn');
    }
    return text;
  }

  static bool _parseBool(dynamic val, {bool defaultValue = false}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val == 1;
    return val.toString().toLowerCase() == 'true' || val.toString() == '1';
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      accountId: (map['accountId'] ?? map['user_id'] ?? map['id'] ?? 0) as int,
      roleId: (map['roleId'] ?? map['role_id'] ?? 0) as int,
      username: (map['username'] ?? '').toString(),
      fullName: sanitizeText(map['fullName'] ?? map['full_name'] ?? ''),
      email: map['email']?.toString(),
      phoneNumber: (map['phoneNumber'] ?? map['phone_number'])?.toString(),
      avatar: map['avatar']?.toString(),
      role: (map['role'] ?? map['roleCode'] ?? 'MEMBER').toString(),
      roleName: sanitizeText(map['roleName'] ?? map['role_name'] ?? 'Thành viên'),
      token: map['token']?.toString(),
      isActive: _parseBool(map['isActive'] ?? map['is_active'], defaultValue: true),
      isEmailVerified: _parseBool(map['isEmailVerified'] ?? map['is_email_verified'], defaultValue: false),
      loyaltyPoints: (map['loyaltyPoints'] ?? map['loyalty_points'] as num? ?? 0).toInt(),
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'user_id': accountId,
      'roleId': roleId,
      'role_id': roleId,
      'username': username,
      'fullName': fullName,
      'full_name': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'phone_number': phoneNumber,
      'avatar': avatar,
      'role': role,
      'roleName': roleName,
      'role_name': roleName,
      'token': token,
      'isActive': isActive ? 1 : 0,
      'isEmailVerified': isEmailVerified ? 1 : 0,
      'loyaltyPoints': loyaltyPoints,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

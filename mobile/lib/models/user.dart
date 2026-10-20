class UserAccount {
  final int accountId;
  final int roleId;
  final String username;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? avatar;
  final String role; // 'ADMIN', 'WAITER', 'CASHIER', 'CHEF', 'MEMBER'
  final String roleName;
  final String? token;
  final bool isActive;
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
    this.createdAt,
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isCashier => role.toUpperCase() == 'CASHIER';
  bool get isWaiter => role.toUpperCase() == 'WAITER';
  bool get isChef => role.toUpperCase().contains('CHEF') || role.toUpperCase().contains('BARISTA');

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      accountId: map['accountId'] ?? map['user_id'] ?? map['id'] ?? 0,
      roleId: map['roleId'] ?? map['role_id'] ?? 0,
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? map['full_name'] ?? '',
      email: map['email'],
      phoneNumber: map['phoneNumber'] ?? map['phone_number'],
      avatar: map['avatar'],
      role: (map['role'] ?? map['roleCode'] ?? 'USER').toString(),
      roleName: (map['roleName'] ?? map['role_name'] ?? 'Người dùng').toString(),
      token: map['token'],
      isActive: map['isActive'] == null ? true : (map['isActive'] == 1 || map['isActive'] == true),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
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
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../services/session_manager.dart';

class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key});

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  final AuthRepository _authRepo = AuthRepository();
  List<UserAccount> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _authRepo.getMembers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách tài khoản: $e';
      });
    }
  }

  Color _getRoleColor(String role) {
    final r = role.toUpperCase();
    if (r == 'ADMIN') return const Color(0xFFDC2626); // Đỏ
    if (r == 'MANAGER') return const Color(0xFFD97706); // Cam
    if (r == 'CASHIER') return const Color(0xFF059669); // Xanh lá
    if (r == 'WAITER') return const Color(0xFF0284C7); // Xanh dương
    if (r == 'KITCHEN' || r.contains('CHEF') || r.contains('BARISTA')) return const Color(0xFF7C3AED); // Tím
    return const Color(0xFF64748B); // Xám cho Member
  }

  void _showRoleDialog(UserAccount user) {
    if (!SessionManager.instance.isAdmin && !SessionManager.instance.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ Quản trị viên hoặc Quản lý mới có quyền đổi vai trò')),
      );
      return;
    }

    final roles = [
      {'id': 1, 'name': 'Quản trị viên (ADMIN)'},
      {'id': 2, 'name': 'Quản lý chi nhánh (MANAGER)'},
      {'id': 3, 'name': 'Thu ngân (CASHIER)'},
      {'id': 4, 'name': 'Nhân viên phục vụ (WAITER)'},
      {'id': 6, 'name': 'Đầu bếp chính (HEAD_CHEF)'},
      {'id': 8, 'name': 'Khách hàng thân thiết (MEMBER)'},
      {'id': 11, 'name': 'Bộ phận bếp KDS (KITCHEN)'},
    ];

    int selectedRoleId = user.roleId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Phân quyền tài khoản @${user.username}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Họ tên: ${user.fullName}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              const Text('Chọn vai trò mới:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: selectedRoleId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: roles.map((r) {
                  return DropdownMenuItem<int>(
                    value: r['id'] as int,
                    child: Text(r['name'] as String, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedRoleId = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final success = await _authRepo.updateRole(user.accountId, selectedRoleId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Cập nhật vai trò thành công!' : 'Không thể cập nhật vai trò'),
                    backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
                if (success) _loadUsers();
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quản trị Người dùng & Vai trò', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Danh sách nhân sự & Phân quyền RBAC', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadUsers,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
                  ? const Center(child: Text('Chưa có người dùng nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final roleColor = _getRoleColor(user.role);
                        final initial = user.fullName.isNotEmpty
                            ? user.fullName.trim().substring(0, 1).toUpperCase()
                            : (user.username.isNotEmpty ? user.username.substring(0, 1).toUpperCase() : '?');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: roleColor.withValues(alpha: 0.12),
                                    child: Text(
                                      initial,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Username: @${user.username} (ID: ${user.accountId})',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF0F172A), size: 22),
                                    tooltip: 'Đổi vai trò',
                                    onPressed: () => _showRoleDialog(user),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      user.roleName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: roleColor,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
                                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          user.phoneNumber!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      if (user.email != null && user.email!.isNotEmpty) ...[
                                        const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 160),
                                          child: Text(
                                            user.email!,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

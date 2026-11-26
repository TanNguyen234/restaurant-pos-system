import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../../services/session_manager.dart';

class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key});

  @visibleForTesting
  static List<Map<String, dynamic>> get debugFallbackRoles => _AdminUserPageState._fallbackRoles;

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  final AuthRepository _authRepo = AuthRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserAccount> _users = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const _fallbackRoles = [
    {'roleId': 1, 'roleCode': 'ADMIN', 'roleName': 'Quản trị viên hệ thống'},
    {'roleId': 2, 'roleCode': 'MANAGER', 'roleName': 'Quản lý chi nhánh'},
    {'roleId': 3, 'roleCode': 'CASHIER', 'roleName': 'Thu ngân'},
    {'roleId': 4, 'roleCode': 'WAITER', 'roleName': 'Nhân viên phục vụ'},
    {'roleId': 5, 'roleCode': 'BARISTA_LEAD', 'roleName': 'Trưởng quầy pha chế'},
    {'roleId': 6, 'roleCode': 'HEAD_CHEF', 'roleName': 'Đầu bếp chính'},
    {'roleId': 7, 'roleCode': 'COOK_ASSISTANT', 'roleName': 'Phụ bếp'},
    {'roleId': 8, 'roleCode': 'MEMBER', 'roleName': 'Khách hàng thân thiết'},
    {'roleId': 9, 'roleCode': 'VIP_MEMBER', 'roleName': 'Khách hàng VIP'},
    {'roleId': 10, 'roleCode': 'DELIVERY_PARTNER', 'roleName': 'Tài khoản đối tác / Giao hàng'},
    {'roleId': 11, 'roleCode': 'KITCHEN', 'roleName': 'Bộ phận bếp & pha chế (KDS)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _authRepo.getMembers();
      List<Map<String, dynamic>> roles = List<Map<String, dynamic>>.from(_fallbackRoles);
      try {
        final serverRoles = await _authRepo.getRoles();
        if (serverRoles.isNotEmpty) roles = serverRoles;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _users = users;
        _roles = roles;
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
    if (r == 'ADMIN') return const Color(0xFFDC2626);
    if (r == 'MANAGER') return const Color(0xFFD97706);
    if (r == 'CASHIER') return const Color(0xFF059669);
    if (r == 'WAITER') return const Color(0xFF0284C7);
    if (r == 'KITCHEN' || r.contains('CHEF') || r.contains('BARISTA') || r.contains('COOK')) return const Color(0xFF7C3AED);
    return const Color(0xFF64748B);
  }

  Future<void> _toggleAccountLock(UserAccount user) async {
    final currentActor = SessionManager.instance.currentUser;
    if (currentActor == null || !currentActor.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ Quản trị viên tối cao (ADMIN) mới có quyền khóa/mở khóa tài khoản')),
      );
      return;
    }
    if (user.accountId == currentActor.accountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tự khóa tài khoản của chính mình'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final nextActive = !user.isActive;
    final res = await _authRepo.updateAccountStatus(user.accountId, nextActive);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? (nextActive ? 'Đã mở khóa tài khoản' : 'Đã khóa tài khoản')),
        backgroundColor: res['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
      ),
    );
    if (res['success'] == true) _loadUsers();
  }

  void _showRoleDialog(UserAccount user) {
    final actor = SessionManager.instance.currentUser;
    if (actor == null || (!actor.isAdmin && !actor.isManager)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ Quản trị viên hoặc Quản lý mới có quyền đổi vai trò')),
      );
      return;
    }
    if (user.accountId == actor.accountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tự thay đổi vai trò của chính bạn!'), backgroundColor: Color(0xFFD97706)),
      );
      return;
    }
    if (!actor.isAdmin && user.role.toUpperCase() == 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quản lý không được chỉnh sửa tài khoản ADMIN'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final assignableRoles = _roles.where((r) {
      final code = (r['roleCode'] ?? '').toString().toUpperCase();
      return actor.isAdmin || code != 'ADMIN';
    }).toList();
    if (assignableRoles.isEmpty) return;

    int selectedRoleId = assignableRoles.any((r) => (r['roleId'] as num?)?.toInt() == user.roleId)
        ? user.roleId
        : (assignableRoles.first['roleId'] as num).toInt();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Phân quyền @${user.username}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Họ tên: ${user.fullName}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                items: assignableRoles.map((r) {
                  final id = (r['roleId'] as num).toInt();
                  final label = '${r['roleName']} (${r['roleCode']})';
                  return DropdownMenuItem<int>(value: id, child: Text(label, style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRoleId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final res = await _authRepo.updateRoleWithResult(user.accountId, selectedRoleId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? 'Đã cập nhật'),
                    backgroundColor: res['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
                if (res['success'] == true) _loadUsers();
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
    final actorIsAdmin = SessionManager.instance.isAdmin;
    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredUsers = _users.where((u) {
      if (query.isEmpty) return true;
      return u.username.toLowerCase().contains(query) ||
          u.fullName.toLowerCase().contains(query) ||
          u.role.toLowerCase().contains(query) ||
          (u.email?.toLowerCase().contains(query) ?? false) ||
          (u.phoneNumber?.toLowerCase().contains(query) ?? false);
    }).toList();

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
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới', onPressed: _loadUsers),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, @username, vai trò, SĐT...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F172A)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
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
                    : filteredUsers.isEmpty
                        ? const Center(child: Text('Không tìm thấy tài khoản nào'))
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                final roleColor = _getRoleColor(user.role);
                                final initial = user.fullName.isNotEmpty
                                    ? user.fullName.trim().substring(0, 1).toUpperCase()
                                    : (user.username.isNotEmpty ? user.username.substring(0, 1).toUpperCase() : '?');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: user.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5)),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: roleColor.withValues(alpha: 0.12),
                                            child: Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.fullName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: user.isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '@${user.username} (ID: ${user.accountId})',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (actorIsAdmin)
                                            IconButton(
                                              icon: Icon(
                                                user.isActive ? Icons.lock_open_rounded : Icons.lock_rounded,
                                                color: user.isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                size: 20,
                                              ),
                                              tooltip: user.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản',
                                              onPressed: () => _toggleAccountLock(user),
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
                                        spacing: 10,
                                        runSpacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                            child: Text(user.roleName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor)),
                                          ),
                                          if (!user.isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                                              child: const Text('ĐÃ KHÓA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                            ),
                                          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                                            Text('SĐT: ${user.phoneNumber!}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          if (user.email != null && user.email!.isNotEmpty)
                                            Text(user.email!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

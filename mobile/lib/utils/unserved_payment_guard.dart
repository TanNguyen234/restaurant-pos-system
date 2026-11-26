import 'package:flutter/material.dart';
import '../services/session_manager.dart';

/// Mã lỗi backend trả về khi đơn tại bàn còn món chưa giao ra bàn.
const String kUnservedItemsErrorCode = 'UNSERVED_ITEMS';

/// Thực hiện một lệnh thu tiền. Nếu backend chặn vì còn món chưa giao:
/// - Quản lý / admin được hỏi có muốn thu ngoại lệ không, đồng ý thì gọi lại với `allowUnserved = true`.
/// - Thu ngân / vai trò khác nhận lại thông báo lỗi để hiển thị (phải chờ phục vụ giao món).
Future<Map<String, dynamic>> payWithUnservedGuard(
  BuildContext context,
  Future<Map<String, dynamic>> Function(bool allowUnserved) pay,
) async {
  final res = await pay(false);
  if (res['errorCode'] != kUnservedItemsErrorCode || !SessionManager.instance.isManager || !context.mounted) {
    return res;
  }
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Còn món chưa giao'),
      content: Text('${res['message'] ?? ''}\n\nBạn là quản lý: vẫn thu tiền ngoại lệ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không thu')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn thu tiền')),
      ],
    ),
  );
  if (proceed != true) return res;
  return pay(true);
}

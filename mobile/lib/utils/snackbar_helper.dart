import 'dart:async';
import 'package:flutter/material.dart';

/// Hiển thị SnackBar nổi, đảm bảo luôn tự động ẩn sau [duration]
/// kể cả khi `accessibleNavigation` / Web Semantics được bật (nơi
/// `ScaffoldMessenger` mặc định giữ SnackBar vô thời hạn), đồng thời
/// tự hủy timer an toàn khi widget dispose để không rò rỉ timer.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAutoDismissSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
  Color backgroundColor = const Color(0xFF0F172A),
  String? actionLabel,
  Color actionTextColor = const Color(0xFFF59E0B),
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;

  messenger.clearSnackBars();

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  controller = messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: backgroundColor,
      content: _AutoDismissContent(
        duration: duration,
        onTimeout: () {
          try {
            controller?.close();
          } catch (_) {}
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: actionTextColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  try {
                    controller?.close();
                  } catch (_) {}
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return controller;
}

class _AutoDismissContent extends StatefulWidget {
  final Duration duration;
  final VoidCallback onTimeout;
  final Widget child;

  const _AutoDismissContent({
    required this.duration,
    required this.onTimeout,
    required this.child,
  });

  @override
  State<_AutoDismissContent> createState() => _AutoDismissContentState();
}

class _AutoDismissContentState extends State<_AutoDismissContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) widget.onTimeout();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

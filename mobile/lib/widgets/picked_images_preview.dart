import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Xem trước các ảnh vừa chọn trong hộp thoại thêm/sửa món.
/// Dùng `Wrap` thay vì `ListView` ngang: `AlertDialog` cần đo kích thước nội dung (intrinsic) mà viewport cuộn không hỗ trợ,
/// nếu dùng `ListView` thì cả hộp thoại bị trắng và không thao tác được.
class PickedImagesPreview extends StatelessWidget {
  final List<Uint8List> images;
  final double size;

  const PickedImagesPreview({super.key, required this.images, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final bytes in images)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: size,
                height: size,
                color: const Color(0xFFE2E8F0),
                child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
      ],
    );
  }
}

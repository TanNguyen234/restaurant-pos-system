import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/widgets/picked_images_preview.dart';

void main() {
  // PNG 1x1 hợp lệ
  final png = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

  testWidgets('hộp thoại hiển thị xem trước ảnh đã chọn mà không bị trắng/lỗi layout', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Thêm món ăn mới'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TextField(decoration: InputDecoration(labelText: 'Tên món')),
                      PickedImagesPreview(images: [png, png, png]),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Thêm món ăn mới'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
  });
}

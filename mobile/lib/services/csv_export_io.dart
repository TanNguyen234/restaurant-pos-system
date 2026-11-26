import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'csv_export_service.dart';

Future<Directory?> _resolveDesktopTargetDir(String? customDirectoryPath) async {
  if (customDirectoryPath != null && customDirectoryPath.trim().isNotEmpty) {
    final customDir = Directory(customDirectoryPath.trim());
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    return customDir;
  }

  try {
    final dl = await getDownloadsDirectory();
    if (dl != null) return dl;
  } catch (_) {}

  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final dl = Directory(p.join(home, 'Downloads'));
    if (await dl.exists()) return dl;
  }

  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {}

  return Directory.systemTemp;
}

Future<CsvExportResult> saveOrShareCsvImpl({
  required String fileName,
  required Uint8List bytes,
  String? customDirectoryPath,
}) async {
  final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  if (isDesktop) {
    final dir = await _resolveDesktopTargetDir(customDirectoryPath);
    if (dir == null) {
      return const CsvExportResult(
        savedAsFile: false,
        message: 'Không tìm thấy thư mục lưu file trên thiết bị.',
      );
    }
    final filePath = p.join(dir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return CsvExportResult(
      savedAsFile: true,
      savedPath: filePath,
      message: 'Đã lưu file CSV tại: $filePath',
    );
  }

  // Mobile (Android / iOS): lưu vào thư mục tạm/tài liệu và mở Share sheet để lưu/gửi file .csv
  Directory targetDir;
  try {
    targetDir = await getTemporaryDirectory();
  } catch (_) {
    targetDir = Directory.systemTemp;
  }
  final filePath = p.join(targetDir.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(filePath, mimeType: 'text/csv', name: fileName)],
      subject: 'Báo cáo đơn hàng POS ($fileName)',
    ),
  );

  return CsvExportResult(
    savedAsFile: true,
    savedPath: filePath,
    message: 'Đã xuất file "$fileName".',
  );
}

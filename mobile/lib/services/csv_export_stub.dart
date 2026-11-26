import 'dart:typed_data';
import 'csv_export_service.dart';

Future<CsvExportResult> saveOrShareCsvImpl({
  required String fileName,
  required Uint8List bytes,
  String? customDirectoryPath,
}) async {
  return const CsvExportResult(
    savedAsFile: false,
    message: 'Nền tảng hiện tại không hỗ trợ lưu file trực tiếp.',
  );
}

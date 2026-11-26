import 'dart:typed_data';
import 'csv_export_stub.dart'
    if (dart.library.js_interop) 'csv_export_web.dart'
    if (dart.library.io) 'csv_export_io.dart' as impl;

class CsvExportResult {
  final bool savedAsFile;
  final String? savedPath;
  final String message;

  const CsvExportResult({
    required this.savedAsFile,
    this.savedPath,
    required this.message,
  });
}

class CsvExportService {
  static Future<CsvExportResult> saveOrShareCsv({
    required String fileName,
    required Uint8List bytes,
    String? customDirectoryPath,
  }) {
    return impl.saveOrShareCsvImpl(
      fileName: fileName,
      bytes: bytes,
      customDirectoryPath: customDirectoryPath,
    );
  }
}

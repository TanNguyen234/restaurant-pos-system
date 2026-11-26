import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'csv_export_service.dart';

Future<CsvExportResult> saveOrShareCsvImpl({
  required String fileName,
  required Uint8List bytes,
  String? customDirectoryPath,
}) async {
  final blobParts = <JSUint8Array>[bytes.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return CsvExportResult(
    savedAsFile: true,
    savedPath: fileName,
    message: 'Đã tải xuống file "$fileName" qua trình duyệt.',
  );
}

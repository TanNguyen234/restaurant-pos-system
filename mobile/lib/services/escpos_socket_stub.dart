Future<Map<String, dynamic>> sendRawTcpBytes({
  required String host,
  required int port,
  required List<int> bytes,
}) async {
  return {
    'success': false,
    'isWebFallback': true,
    'message': 'Trình duyệt Web không hỗ trợ mở Raw TCP Socket ($host:$port). Đã xuất ${bytes.length} byte ESC/POS sẵn sàng để in qua App Windows/Android.',
  };
}

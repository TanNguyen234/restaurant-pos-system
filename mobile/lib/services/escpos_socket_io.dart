import 'dart:io';

Future<Map<String, dynamic>> sendRawTcpBytes({
  required String host,
  required int port,
  required List<int> bytes,
}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
    socket.add(bytes);
    await socket.flush();
    return {
      'success': true,
      'isWebFallback': false,
      'message': 'Đã gửi ${bytes.length} byte ESC/POS tới máy in LAN $host:$port',
    };
  } catch (e) {
    return {
      'success': false,
      'isWebFallback': false,
      'message': 'Không thể kết nối máy in LAN ($host:$port): $e',
    };
  } finally {
    try {
      await socket?.close();
    } catch (_) {}
  }
}

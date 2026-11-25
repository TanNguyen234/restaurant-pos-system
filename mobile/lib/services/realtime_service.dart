import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class PosRealtimeEvent {
  final String target;
  final dynamic payload;
  final DateTime receivedAt;

  PosRealtimeEvent({
    required this.target,
    this.payload,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

/// SignalR JSON Hub Protocol v1 WebSocket client kết nối `/hubs/pos`.
class PosRealtimeService {
  PosRealtimeService._internal();
  static final PosRealtimeService instance = PosRealtimeService._internal();

  static const String _recordSep = '\u001e';
  static bool isTestingMode = false;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final StreamController<PosRealtimeEvent> _eventController =
      StreamController<PosRealtimeEvent>.broadcast();

  Stream<PosRealtimeEvent> get events => _eventController.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _shouldRun = false;
  String _buffer = '';
  int _retrySeconds = 2;

  static Uri buildHubUri([String? httpBase]) {
    final parsed = Uri.parse(httpBase ?? ApiConfig.baseUrl);
    final wsScheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    return parsed.replace(
      scheme: wsScheme,
      path: '${parsed.path.replaceAll(RegExp(r'/+$'), '')}/hubs/pos',
      query: null,
    );
  }

  /// Giải mã các khung tin nhắn SignalR phân cách bằng ký tự ASCII `0x1E`.
  @visibleForTesting
  static List<PosRealtimeEvent> parseFrames(String raw) {
    final results = <PosRealtimeEvent>[];
    if (raw.isEmpty) return results;
    final parts = raw.split(_recordSep);
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final type = (decoded['type'] as num?)?.toInt();
          if (type == 1) {
            final target = decoded['target']?.toString() ?? 'Unknown';
            final args = decoded['arguments'];
            final payload = (args is List && args.isNotEmpty) ? args.first : null;
            results.add(PosRealtimeEvent(target: target, payload: payload));
          }
        }
      } catch (_) {}
    }
    return results;
  }

  void ensureStarted() {
    if (isTestingMode || _shouldRun) return;
    _shouldRun = true;
    _connect();
  }

  void _connect() {
    if (!_shouldRun || isTestingMode) return;
    _sub?.cancel();
    _pingTimer?.cancel();
    _buffer = '';

    try {
      final uri = buildHubUri();
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // SignalR JSON Hub Protocol v1 handshake
      channel.sink.add('{"protocol":"json","version":1}$_recordSep');
      isConnectedNotifier.value = true;
      _retrySeconds = 2;

      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          _channel?.sink.add('{"type":6}$_recordSep');
        } catch (_) {}
      });

      _sub = channel.stream.listen(
        (chunk) {
          _buffer += chunk.toString();
          final lastSep = _buffer.lastIndexOf(_recordSep);
          if (lastSep == -1) return;
          final complete = _buffer.substring(0, lastSep + 1);
          _buffer = _buffer.substring(lastSep + 1);

          for (final rawFrame in complete.split(_recordSep)) {
            final trimmed = rawFrame.trim();
            if (trimmed.isEmpty) continue;
            try {
              final decoded = jsonDecode(trimmed);
              if (decoded is Map && (decoded['type'] as num?)?.toInt() == 6) {
                continue; // keepalive ping
              }
            } catch (_) {}
            for (final ev in parseFrames('$trimmed$_recordSep')) {
              if (!_eventController.isClosed) {
                _eventController.add(ev);
              }
            }
          }
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    isConnectedNotifier.value = false;
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel = null;
    if (!_shouldRun || isTestingMode) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), _connect);
    _retrySeconds = (_retrySeconds * 2).clamp(2, 20);
  }

  void dispose() {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    isConnectedNotifier.value = false;
  }
}

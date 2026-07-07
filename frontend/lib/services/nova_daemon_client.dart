import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NovaDaemonEvent {
  const NovaDaemonEvent({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;
}

class NovaDaemonClient {
  final StreamController<NovaDaemonEvent> _events =
      StreamController<NovaDaemonEvent>.broadcast();

  WebSocket? _socket;
  bool get isConnected => _socket != null;
  Stream<NovaDaemonEvent> get events => _events.stream;

  Future<void> connect() async {
    if (_socket != null) return;

    try {
      _socket = await WebSocket.connect('ws://127.0.0.1:8765/ws');
      _socket!.listen(
        _handleMessage,
        onDone: _disconnect,
        onError: (_) => _disconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _disconnect();
    }
  }

  void sendPrompt(String text) {
    _send({'type': 'user_prompt', 'text': text});
  }

  void setPreference(String key, String value) {
    _send({'type': 'set_preference', 'key': key, 'value': value});
  }

  void _send(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    socket.add(jsonEncode(payload));
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) return;

    final data = decoded['data'];
    _events.add(
      NovaDaemonEvent(
        type: decoded['type']?.toString() ?? 'unknown',
        data: data is Map<String, dynamic> ? data : <String, dynamic>{},
      ),
    );
  }

  void _disconnect() {
    _socket = null;
  }

  Future<void> dispose() async {
    await _socket?.close();
    await _events.close();
  }
}

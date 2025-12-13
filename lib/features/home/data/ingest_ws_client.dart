import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class IngestWsClient {
  final Uri ingestUri; // ws://IP:8000/ws/ingest
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  bool _connected = false;

  IngestWsClient({required this.ingestUri});

  Future<void> connect() async {
    if (_connected) return;
    _ch = WebSocketChannel.connect(ingestUri);
    _connected = true;

    _sub = _ch!.stream.listen(
      (_) {},
      onError: (_) => _connected = false,
      onDone: () => _connected = false,
    );
  }

  Future<void> send(Map<String, dynamic> payload) async {
    if (!_connected) await connect();
    _ch?.sink.add(jsonEncode(payload));
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _ch?.sink.close();
    _connected = false;
  }
}

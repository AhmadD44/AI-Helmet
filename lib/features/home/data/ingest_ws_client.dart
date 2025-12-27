import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class IngestWsClient {
  IngestWsClient({required this.ingestUri});

  final Uri ingestUri;
  WebSocketChannel? _ch;

  Future<void> connect() async {
    _ch ??= WebSocketChannel.connect(ingestUri);
  }

  Future<void> send(Map<String, dynamic> payload) async {
    if (_ch == null) {
      await connect();
    }
    _ch!.sink.add(jsonEncode(payload));
  }

  Future<void> close() async {
    await _ch?.sink.close();
    _ch = null;
  }
}

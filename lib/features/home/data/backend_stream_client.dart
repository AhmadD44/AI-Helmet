import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class BackendStreamClient {
  WebSocketChannel connect({required String token}) {
    final uri = Uri(
      scheme: 'ws',
      host: '3.14.15.242',
      port: 8000,
      path: '/ws/stream',
      queryParameters: {'token': token},
    );
    return WebSocketChannel.connect(uri);
  }

  static Map<String, dynamic> decode(dynamic msg) {
    // msg is usually String from web_socket_channel
    final raw = msg.toString().trim();

    // If the backend ever sends logs like: "[12:59:06 PM] {...}"
    final i = raw.indexOf('{');
    final jsonStr = (i >= 0) ? raw.substring(i) : raw;

    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}

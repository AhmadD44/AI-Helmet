import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart';

class MsgpackLenFrameDecoder {
  final BytesBuilder _buf = BytesBuilder(copy: false);

  void add(Uint8List chunk) {
    if (chunk.isNotEmpty) _buf.add(chunk);
  }

  List<Map<String, dynamic>> drain() {
    final out = <Map<String, dynamic>>[];

    while (true) {
      final bytes = _buf.toBytes();
      if (bytes.length < 4) return out;

      final len = (bytes[0] << 24) |
          (bytes[1] << 16) |
          (bytes[2] << 8) |
          (bytes[3]);

      if (len <= 0) {
        _buf.clear();
        return out;
      }

      if (bytes.length < 4 + len) return out;

      final payload = bytes.sublist(4, 4 + len);
      final remaining = bytes.sublist(4 + len);

      _buf.clear();
      if (remaining.isNotEmpty) _buf.add(Uint8List.fromList(remaining));

      final obj = deserialize(Uint8List.fromList(payload));
      if (obj is Map) out.add(Map<String, dynamic>.from(obj));
    }
  }
}

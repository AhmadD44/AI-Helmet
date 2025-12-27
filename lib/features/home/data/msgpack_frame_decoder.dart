import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart';

class MsgpackFrameDecoder {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    _buffer.add(Uint8List.fromList(chunk));
  }

  /// Tries to decode exactly ONE msgpack object from the current buffer.
  /// Returns decoded object if successful, otherwise null (wait for more bytes).
  dynamic tryDecodeOne() {
    final bytes = _buffer.toBytes();
    if (bytes.isEmpty) return null;

    try {
      final obj = deserialize(Uint8List.fromList(bytes));
      _buffer.clear(); // ✅ decoded full object
      return obj;
    } catch (_) {
      // incomplete packet → wait for more
      if (bytes.length > 64 * 1024) {
        // safety: avoid unbounded growth
        _buffer.clear();
      }
      return null;
    }
  }

  void clear() => _buffer.clear();
}

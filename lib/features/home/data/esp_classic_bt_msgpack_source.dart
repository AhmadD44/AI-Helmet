import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as mp;

/// Uses bluetooth_classic official API:
/// - initPermissions()
/// - startScan / stopScan
/// - onDeviceDiscovered()
/// - connect(mac, uuid)
/// - onDeviceDataReceived()
///
/// Decodes MessagePack best-effort.
/// Never throws to UI (errors are pushed to stream as addError).
class EspBtClassicSource {
  final bool debugLog;
  EspBtClassicSource({this.debugLog = false});

  final BluetoothClassic _bt = BluetoothClassic();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  StreamSubscription<List<int>>? _rxSub;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  bool _connected = false;
  bool _connecting = false;
  String? _mac;

  // ===== SCAN =====

  Future<void> initPermissions() async {
    await _bt.initPermissions(); // official method
  }

  Stream<Device> onDeviceDiscovered() => _bt.onDeviceDiscovered();

  Future<void> startScan() async {
    await initPermissions();
    await _bt.startScan();
  }

  Future<void> stopScan() async {
    try {
      await _bt.stopScan();
    } catch (_) {}
  }

  // ===== CONNECT / RX =====

  Future<void> connect(String mac) async {
    if (_connected && _mac == mac) return;
    if (_connecting) return;
    _connecting = true;

    try {
      await disconnect();

      if (debugLog) {
        // ignore: avoid_print
        print("Connecting to $mac ...");
      }

      // SPP UUID (most ESP32 classic serial)
      const sppUuid = "00001101-0000-1000-8000-00805F9B34FB";

      final ok = await _bt.connect(mac, sppUuid);
      if (!ok) {
        throw Exception("connect() returned false");
      }

      _connected = true;
      _mac = mac;

      if (debugLog) {
        // ignore: avoid_print
        print("Connected ✅");
      }


      // RX stream (official)
      await _rxSub?.cancel();

      _rxSub = _bt.onDeviceDataReceived().listen(
        (bytes) => _onBytes(Uint8List.fromList(bytes)),
        onError: (e) => _controller.addError(e),
        cancelOnError: false,
      );

    } finally {
      _connecting = false;
    }
  }

  void _onBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;

    if (debugLog) {
      // ignore: avoid_print
      print("RX bytes: ${bytes.length}");
    }

    _buffer.add(bytes);

    // Best-effort: try decode full buffer.
    // If incomplete => wait for more.
    // If decode success => clear buffer and emit map.
    // If buffer grows too large => clear to avoid memory blow.
    while (true) {
      final data = _buffer.toBytes();
      if (data.isEmpty) return;

      try {
        final obj = mp.deserialize(data);

        _buffer.clear();

        final map = _normalizeToMap(obj);
        if (map != null) {
          if (debugLog) {
            // ignore: avoid_print
            print("Decoded keys: ${map.keys.toList()}");
          }
          _controller.add(map);
        } else {
          if (debugLog) {
            // ignore: avoid_print
            print("Decoded but not Map: ${obj.runtimeType}");
          }
        }

        // If ESP sent multiple objects back-to-back in one buffer,
        // msgpack_dart usually doesn't give leftover bytes.
        // So we stop here.
        return;
      } catch (e) {
        if (data.length > 1024 * 1024) {
          _buffer.clear();
          _controller.addError("Buffer overflow: cleared");
        }
        // Incomplete or decode error -> wait for more bytes
        return;
      }
    }
  }

  Map<String, dynamic>? _normalizeToMap(dynamic obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> disconnect() async {
    try {
      await _rxSub?.cancel();
    } catch (_) {}
    _rxSub = null;

    try {
      await _bt.disconnect();
    } catch (_) {}

    _connected = false;
    _mac = null;
    _buffer.clear();
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}

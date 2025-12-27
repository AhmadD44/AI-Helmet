import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

import 'msgpack_len_frame_decoder.dart';

class EspBtClassicSource {
  EspBtClassicSource({this.debugLog = false});

  final bool debugLog;
  final BluetoothClassic _bt = BluetoothClassic();

  // SPP UUID (Serial Port Profile)
  static const String sppUuid = "00001101-0000-1000-8000-00805f9b34fb";

  StreamSubscription<Uint8List>? _rxSub;

  final _out = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _out.stream;

  final MsgpackLenFrameDecoder _decoder = MsgpackLenFrameDecoder();

  // ✅ Required by ConnectEspPage
  Future<void> initPermissions() async => _bt.initPermissions();
  Stream<Device> onDeviceDiscovered() => _bt.onDeviceDiscovered();
  Future<void> startScan() => _bt.startScan();
  Future<void> stopScan() => _bt.stopScan();

  // ✅ Connect + read bytes
  Future<void> connect(String mac) async {
    if (debugLog) print("[BT] Connecting to $mac");
    await _bt.connect(mac, sppUuid);

    await _rxSub?.cancel();
    _rxSub = _bt.onDeviceDataReceived().listen((bytes) {
      _decoder.add(bytes);
      final packets = _decoder.drain();
      for (final p in packets) {
        if (debugLog) print("[BT] decoded keys=${p.keys.toList()}");
        _out.add(p);
      }
    });
  }

  Future<void> disconnect() async {
    await _rxSub?.cancel();
    _rxSub = null;
    await _bt.disconnect();
  }

  Future<void> dispose() async {
    await disconnect();
    await _out.close();
  }
}

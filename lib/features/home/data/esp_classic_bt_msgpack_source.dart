import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

class EspBtClassicSource {
  final bool debugLog;
  EspBtClassicSource({this.debugLog = true});

  final BluetoothClassic _bt = BluetoothClassic();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  StreamSubscription<List<int>>? _rxSub;
  
  final List<int> _buffer = []; 
  
  bool _connected = false;
  bool _connecting = false;
  String? _mac;

  Future<void> initPermissions() async {
    try {
      await _bt.initPermissions();
    } catch (e) {
      print("❌ Permission error: $e");
    }
  }

  Stream<Device> onDeviceDiscovered() => _bt.onDeviceDiscovered();

  Future<void> startScan() async {
    await initPermissions();
    try {
      await _bt.startScan();
    } catch (e) {
      print("❌ Scan error: $e");
    }
  }

  Future<void> stopScan() async {
    try {
      await _bt.stopScan();
    } catch (_) {}
  }

  Future<void> connect(String mac) async {
    print("🔄 CONNECT called for MAC: $mac");
    
    if (_connected && _mac == mac) {
      print("ℹ️ Already connected to this device");
      return;
    }
    
    if (_connecting) {
      print("ℹ️ Already connecting");
      return;
    }
    
    _connecting = true;
    _mac = mac;

    try {
      await _cleanupConnection();
      print("🔗 Step 1: Initiating connection to $mac");

      const sppUuid = "00001101-0000-1000-8000-00805F9B34FB";
      print("🔗 Step 2: Using SPP UUID: $sppUuid");

      final ok = await _bt.connect(mac, sppUuid).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print("⏰ Connection timeout after 15 seconds");
          return false;
        },
      );
      
      if (!ok) {
        throw Exception("connect() returned false");
      }

      print("✅ Step 3: Bluetooth connected successfully");
      await Future.delayed(const Duration(milliseconds: 500));
      _connected = true;

      print("📡 Step 4: Setting up data stream listener");

      await _rxSub?.cancel();
      _rxSub = _bt.onDeviceDataReceived().listen(
        (bytes) {
          _onBytes(Uint8List.fromList(bytes));
        },
        onError: (e) {
          print("❌ Bluetooth stream error: $e");
          print("⚠️ Stream error type: ${e.runtimeType}");
          if (e is! TimeoutException) {
            _handleDisconnection("Stream error: $e");
          }
        },
        onDone: () {
          print("🔌 Bluetooth stream closed (onDone callback)");
          _handleDisconnection("Stream closed");
        },
        cancelOnError: false,
      );

      print("🎯 Step 5: Connection setup complete - Ready for data");
      
    } on TimeoutException catch (e) {
      print("⏰ Connection timeout: $e");
      _handleDisconnection("Connection timeout");
      rethrow;
    } catch (e) {
      print("❌ Connection failed with error: $e");
      print("❌ Error type: ${e.runtimeType}");
      _handleDisconnection("Connection error: $e");
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  void _onBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;
    
    _processData(bytes.toList());
  }

   void _processData(List<int> bytes) {
  if (bytes.isEmpty) return;
  
  _buffer.addAll(bytes);
  
  while (true) {
    if (_buffer.isEmpty) break;
    
    String bufferStr = utf8.decode(_buffer, allowMalformed: true);
    int jsonStart = bufferStr.indexOf('{');
    
    if (jsonStart == -1) {
      _buffer.clear();
      break;
    }
    
    int braceCount = 0;
    int jsonEnd = -1;
    
    for (int i = jsonStart; i < bufferStr.length; i++) {
      if (bufferStr[i] == '{') {
        braceCount++;
      } else if (bufferStr[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          jsonEnd = i;
          break;
        }
      }
    }
    
    if (jsonEnd == -1) {
      break;
    }
    
    String jsonString = bufferStr.substring(jsonStart, jsonEnd + 1);
    
    if (debugLog) {
      print("✅ Processing JSON (${jsonString.length} chars)");
    }
    
    _processSingleJson(jsonString);
    
    int removeUpTo = jsonEnd + 1;
    
    if (removeUpTo < bufferStr.length && 
        (bufferStr[removeUpTo] == '\r' || bufferStr[removeUpTo] == '\n')) {
      removeUpTo++;
      if (removeUpTo < bufferStr.length && 
          bufferStr[removeUpTo] == '\n' && bufferStr[removeUpTo - 1] == '\r') {
        removeUpTo++;
      }
    }
    
    if (removeUpTo <= _buffer.length) {
      _buffer.removeRange(0, removeUpTo);
    } else {
      _buffer.clear();
    }
  }
}


  void _processSingleJson(String jsonString) {
  try {
    jsonString = jsonString.trim();
    
    if (debugLog) {
      print("🎯 Parsing JSON (${jsonString.length} chars)");
    }
    
    final decoded = jsonDecode(jsonString);
    
    _controller.add(decoded);
    
  } catch (e) {
    if (debugLog) {
      print("❌ JSON parse error: $e");
    }
  }
}


  void _handleDisconnection(String reason) {
    print("🔌 Handling disconnection: $reason");
    
    if (!_connected && !_connecting) return;
    
    _connected = false;
    print("🚫 Connection lost: $reason");
    
    _controller.addError(reason);
    _cleanupConnection();
  }

  Future<void> _cleanupConnection() async {
    await _rxSub?.cancel();
    _rxSub = null;
    _buffer.clear();
  }

  Future<void> disconnect() async {
    print("👋 Manual disconnect requested");
    
    await _cleanupConnection();
    
    try {
      await _bt.disconnect();
      print("✅ Bluetooth disconnected");
    } catch (e) {
      print("⚠️ Error during disconnect: $e");
    }

    _connected = false;
    _mac = null;
    _connecting = false;
  }

  Future<void> dispose() async {
    print("♻️ Disposing Bluetooth source");
    await disconnect();
    await _controller.close();
    print("♻️ Bluetooth source disposed");
  }
  
  bool get isConnected => _connected;
  String? get currentMac => _mac;
  bool get isConnecting => _connecting;
}
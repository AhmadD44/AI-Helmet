import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

class EspBtClassicSource {
  final bool debugLog;
  EspBtClassicSource({this.debugLog = true}); // Set to true for debugging

  final BluetoothClassic _bt = BluetoothClassic();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  StreamSubscription<List<int>>? _rxSub;
  
  // Buffer for incoming string data
  String _messageBuffer = '';

  bool _connected = false;
  bool _connecting = false;
  String? _mac;

  // ===== SCAN =====

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

  // ===== CONNECT / RX =====

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
      // Clean up any existing connection first
      await _cleanupConnection();

      print("🔗 Step 1: Initiating connection to $mac");

      // ESP32 SPP UUID - THIS IS CRITICAL
      const sppUuid = "00001101-0000-1000-8000-00805F9B34FB";
      
      print("🔗 Step 2: Using SPP UUID: $sppUuid");

      // Try connection with timeout
      final ok = await _bt.connect(mac, sppUuid).timeout(
        const Duration(seconds: 15), // Increased timeout to 15s
        onTimeout: () {
          print("⏰ Connection timeout after 15 seconds");
          return false;
        },
      );
      
      if (!ok) {
        throw Exception("connect() returned false");
      }

      print("✅ Step 3: Bluetooth connected successfully");
      
      // Wait a moment for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      
      _connected = true;

      print("📡 Step 4: Setting up data stream listener");

      // Setup RX stream
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
      print("❌ Stack trace: ${e.toString()}");
      _handleDisconnection("Connection error: $e");
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  void _onBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;

    try {
      // 1. Decode bytes to string
      final incomingStr = utf8.decode(bytes, allowMalformed: true);
      
      if (debugLog) {
        print("📥 RX: $incomingStr");
      }

      // 2. Add to buffer
      _messageBuffer += incomingStr;

      // 3. Process buffer for complete JSON objects
      _processBuffer();

    } catch (e) {
      print("❌ Error processing bytes: $e");
    }
  }

  void _processBuffer() {
    // Simple JSON extraction logic: look for matching braces
    // This handles cases where multiple JSONs arrive at once, or one JSON arrives in pieces
    
    while (true) {
      final start = _messageBuffer.indexOf('{');
      if (start == -1) {
        // No start brace, clear garbage if buffer gets too big
        if (_messageBuffer.length > 1000) _messageBuffer = '';
        return;
      }

      // We have a start brace. Now try to find the matching end brace.
      // This is a naive implementation that assumes no nested braces inside strings.
      // For robust parsing, we'd need a proper parser, but this works for standard telemetry.
      
      int braceCount = 0;
      int end = -1;
      
      for (int i = start; i < _messageBuffer.length; i++) {
        if (_messageBuffer[i] == '{') braceCount++;
        if (_messageBuffer[i] == '}') braceCount--;
        
        if (braceCount == 0) {
          end = i;
          break;
        }
      }

      if (end != -1) {
        // We found a complete JSON object string
        final jsonStr = _messageBuffer.substring(start, end + 1);
        
        // Remove processed part from buffer
        _messageBuffer = _messageBuffer.substring(end + 1);
        
        try {
          final dynamic decoded = jsonDecode(jsonStr);
          final map = _normalizeToMap(decoded);
          
          if (map != null) {
            if (debugLog) print("✅ Decoded JSON: $map");
            _controller.add(map);
          }
        } catch (e) {
          print("⚠️ JSON parse error for substring: $e");
          // Just continue, maybe the next one is good
        }
      } else {
        // Incomplete JSON, wait for more data
        // Safety check: if buffer is huge and we still don't have a valid JSON, clear it
        if (_messageBuffer.length > 5000) {
          print("⚠️ Buffer too large with no valid JSON, clearing");
          _messageBuffer = '';
        }
        return;
      }
    }
  }

  void _handleDisconnection(String reason) {
    print("🔌 Handling disconnection: $reason");
    
    if (!_connected && !_connecting) {
      return;
    }
    
    _connected = false;
    
    print("🚫 Connection lost: $reason");
    
    // Notify listeners
    _controller.addError(reason);
    
    // Clean up
    _cleanupConnection();
  }

  Future<void> _cleanupConnection() async {
    await _rxSub?.cancel();
    _rxSub = null;
    _messageBuffer = '';
  }

  Map<String, dynamic>? _normalizeToMap(dynamic obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
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
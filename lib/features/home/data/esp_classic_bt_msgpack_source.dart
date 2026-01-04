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
  
  // =============== ADD THIS LINE ===============
  final List<int> _buffer = []; // Buffer to accumulate data fragments
  
  bool _connected = false;
  bool _connecting = false;
  String? _mac;

  // ===== SCAN ===== (keep as is)

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

  // =============== REPLACE _onBytes WITH THIS ===============
  void _onBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;
    
    // Process the bytes using the working logic
    _processData(bytes.toList());
  }

  // =============== COPY EXACTLY FROM YOUR WORKING CODE ===============
   void _processData(List<int> bytes) {
    if (bytes.isEmpty) return;
    
    // Add to buffer
    _buffer.addAll(bytes);
    
    // Process ONE complete JSON at a time
    while (true) {
      if (_buffer.isEmpty) break;
      
      // Convert buffer to string
      String bufferStr = utf8.decode(_buffer, allowMalformed: true);
      
      // Find FIRST "{" (start of JSON)
      int jsonStart = bufferStr.indexOf('{');
      if (jsonStart == -1) {
        // No JSON start, clear buffer
        _buffer.clear();
        break;
      }
      
      // Find ":0}}" after the start (end of JSON)
      int jsonEnd = bufferStr.indexOf(':0}}', jsonStart);
      if (jsonEnd == -1) {
        // No complete JSON yet
        break;
      }
      
      // Extract ONLY ONE JSON
      String jsonString = bufferStr.substring(jsonStart, jsonEnd + 4); // +4 for :0}}
      
      if (debugLog) {
        print("✅ Processing JSON (${jsonString.length} chars)");
      }
      
      // Process this single JSON
      _processSingleJson(jsonString);
      
      // Remove processed data (including newlines)
      int removeUpTo = jsonEnd + 4; // Remove up to :0}}
      
      // Check for newlines
      if (jsonEnd + 9 <= bufferStr.length && 
          bufferStr.substring(jsonEnd, jsonEnd + 9) == ':0}}\r\n\r\n') {
        removeUpTo = jsonEnd + 9;
      } else if (jsonEnd + 7 <= bufferStr.length && 
                 bufferStr.substring(jsonEnd, jsonEnd + 7) == ':0}}\n\n') {
        removeUpTo = jsonEnd + 7;
      }
      
      // Remove from buffer
      if (removeUpTo <= _buffer.length) {
        _buffer.removeRange(0, removeUpTo);
      } else {
        _buffer.clear();
      }
      
      // Loop to process next JSON if available
    }
  }


  void _processSingleJson(String jsonString) {
  try {
    jsonString = jsonString.trim();
    
    if (debugLog) {
      print("🎯 Parsing JSON (${jsonString.length} chars)");
    }
    
    // Parse JSON - keep it exactly as received
    final decoded = jsonDecode(jsonString);
    
    // Send to stream as-is
    _controller.add(decoded);
    
  } catch (e) {
    if (debugLog) {
      print("❌ JSON parse error: $e");
    }
  }
}

  // =============== KEEP REST OF THE CODE AS IS ===============

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
    _buffer.clear(); // Clear buffer on disconnect
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
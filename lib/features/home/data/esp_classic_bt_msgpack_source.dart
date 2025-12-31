import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as mp;

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

  // Auto-reconnection variables
  Timer? _reconnectTimer;
  Timer? _connectionMonitorTimer;
  bool _autoReconnect = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration connectionCheckInterval = Duration(seconds: 5);
  
  // Last data received time
  DateTime? _lastDataReceived;

  // ===== SCAN =====

  Future<void> initPermissions() async {
    await _bt.initPermissions();
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
    _autoReconnect = true; // Enable auto-reconnect
    _mac = mac;

    try {
      await _cleanupConnection();

      if (debugLog) {
        print("Connecting to $mac ...");
      }

      const sppUuid = "00001101-0000-1000-8000-00805F9B34FB";

      final ok = await _bt.connect(mac, sppUuid);
      if (!ok) {
        throw Exception("connect() returned false");
      }

      _connected = true;
      _reconnectAttempts = 0; // Reset on successful connection
      _lastDataReceived = DateTime.now();

      if (debugLog) {
        print("Connected ✅");
      }

      // Start connection monitoring
      _startConnectionMonitoring();

      // RX stream
      await _rxSub?.cancel();

      _rxSub = _bt.onDeviceDataReceived().listen(
        (bytes) {
          _lastDataReceived = DateTime.now(); // Update last data time
          _onBytes(Uint8List.fromList(bytes));
        },
        onError: (e) {
          if (debugLog) {
            print("❌ Bluetooth stream error: $e");
          }
          _handleDisconnection();
        },
        onDone: () {
          if (debugLog) {
            print("🔌 Bluetooth stream closed");
          }
          _handleDisconnection();
        },
        cancelOnError: true,
      );

    } catch (e) {
      if (debugLog) {
        print("❌ Connection failed: $e");
      }
      _handleDisconnection();
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(connectionCheckInterval, (timer) {
      // Check if we haven't received data for a while (connection might be dead)
      if (_lastDataReceived != null && 
          DateTime.now().difference(_lastDataReceived!) > Duration(seconds: 10) &&
          _connected) {
        
        if (debugLog) {
          print("⚠️ No data received for 10 seconds, connection may be dead");
        }
        _handleDisconnection();
      }
    });
  }

  void _onBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;

    if (debugLog) {
      print("RX bytes: ${bytes.length}");
    }

    _buffer.add(bytes);

    while (true) {
      final data = _buffer.toBytes();
      if (data.isEmpty) return;

      try {
        final obj = mp.deserialize(data);

        _buffer.clear();

        final map = _normalizeToMap(obj);
        if (map != null) {
          if (debugLog) {
            print("Decoded keys: ${map.keys.toList()}");
          }
          _controller.add(map);
        } else {
          if (debugLog) {
            print("Decoded but not Map: ${obj.runtimeType}");
          }
        }

        return;
      } catch (e) {
        if (data.length > 1024 * 1024) {
          _buffer.clear();
          if (debugLog) {
            print("Buffer overflow: cleared");
          }
        }
        return;
      }
    }
  }

  void _handleDisconnection() {
    if (!_connected && !_connecting) return;
    
    _connected = false;
    
    if (debugLog) {
      print("🔌 Connection lost or device disconnected");
    }
    
    // Stop connection monitoring
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
    
    // Notify listeners
    _controller.addError("Device disconnected");
    
    // Clean up current connection
    _cleanupConnection();
    
    // Attempt auto-reconnect if enabled
    if (_autoReconnect && _mac != null && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    
    _reconnectAttempts++;
    if (debugLog) {
      print("🔄 Scheduling reconnect attempt $_reconnectAttempts/$maxReconnectAttempts in ${reconnectDelay.inSeconds}s");
    }
    
    _reconnectTimer = Timer(reconnectDelay, () async {
      if (_autoReconnect && !_connected && _mac != null && _reconnectAttempts <= maxReconnectAttempts) {
        try {
          if (debugLog) {
            print("🔄 Attempting reconnect...");
          }
          await connect(_mac!);
        } catch (e) {
          if (debugLog) {
            print("❌ Reconnect failed: $e");
          }
          // Will automatically schedule another attempt if under limit
          if (_reconnectAttempts < maxReconnectAttempts) {
            _scheduleReconnect();
          }
        }
      } else if (_reconnectAttempts >= maxReconnectAttempts) {
        if (debugLog) {
          print("❌ Max reconnect attempts reached ($maxReconnectAttempts)");
        }
      }
    });
  }

  Future<void> _cleanupConnection() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
    
    await _rxSub?.cancel();
    _rxSub = null;
    
    _buffer.clear();
  }

  Map<String, dynamic>? _normalizeToMap(dynamic obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> disconnect() async {
    _autoReconnect = false; // Disable auto-reconnect when manually disconnecting
    await _cleanupConnection();
    
    try {
      await _bt.disconnect();
    } catch (_) {}

    _connected = false;
    _mac = null;
    _reconnectAttempts = 0;
    _lastDataReceived = null;
  }

  Future<void> dispose() async {
    _autoReconnect = false;
    await disconnect();
    await _controller.close();
  }
  
  bool get isConnected => _connected;
  String? get currentMac => _mac;
  int get reconnectAttempts => _reconnectAttempts;
}
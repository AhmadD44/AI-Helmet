import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

  try {
    // Decode bytes to string
    String incomingStr;
    try {
      incomingStr = utf8.decode(bytes, allowMalformed: false);
    } catch (e) {
      incomingStr = utf8.decode(bytes, allowMalformed: true);
    }
    
    if (debugLog) {
      print("📥 RX (${incomingStr.length} chars): ${_formatIncomingData(incomingStr)}");
    }

    // Add to buffer
    _messageBuffer += incomingStr;
    
    // Check if this looks like it might complete a JSON
    // If incoming data contains closing braces, process immediately
    if (incomingStr.contains('}') && _messageBuffer.contains('{')) {
      _processBuffer();
    } else if (_messageBuffer.length > 500) {
      // If buffer is getting large, process it anyway
      _processBuffer();
    }
    
  } catch (e) {
    print("❌ Error processing bytes: $e");
  }
}

String _formatIncomingData(String data) {
  if (data.length <= 100) return data;
  
  // Show first 50 and last 50 chars for long data
  String start = data.substring(0, 50);
  String end = data.substring(data.length - 50);
  
  // Check if it starts with JSON
  if (data.trim().startsWith('{')) {
    return "$start...";
  } else if (data.contains('}')) {
    // Show end if it contains closing braces
    return "...$end";
  }
  
  return "$start...";
}

  void _processBuffer() {
  // Keep processing while we have data
  while (_messageBuffer.isNotEmpty) {
    if (debugLog) {
      print("🔄 PROCESSING BUFFER (${_messageBuffer.length} chars)");
    }
    
    // FIRST: Check if buffer starts with garbage (not '{')
    if (!_messageBuffer.startsWith('{')) {
      if (debugLog) {
        print("⚠️ Buffer doesn't start with { - looking for JSON start");
      }
      
      // Find the next '{' which might be a valid JSON start
      int nextBrace = _messageBuffer.indexOf('{');
      if (nextBrace != -1) {
        if (debugLog) {
          print("⚠️ Found { at position $nextBrace, removing ${nextBrace} chars of garbage");
          print("⚠️ Removing: ${_messageBuffer.substring(0, math.min(nextBrace, 100))}");
        }
        
        // Remove garbage and start processing from the '{'
        _messageBuffer = _messageBuffer.substring(nextBrace);
        
        if (debugLog) {
          print("✅ Buffer cleaned, new start: ${_messageBuffer.substring(0, math.min(50, _messageBuffer.length))}");
        }
      } else {
        // No '{' found at all - clear everything
        if (debugLog) {
          print("⚠️ No { found in buffer, clearing everything");
        }
        _messageBuffer = '';
        return;
      }
    }
    
    // NOW: Try to find a complete JSON starting from the '{'
    int jsonEnd = _findCompleteJsonEnd(_messageBuffer);
    
    if (jsonEnd != -1) {
      // Found a complete JSON
      String jsonStr = _messageBuffer.substring(0, jsonEnd + 1);
      
      if (debugLog) {
        print("✅ FOUND COMPLETE JSON (${jsonStr.length} chars)");
      }
      
      // Parse and emit
      _parseAndEmitJson(jsonStr);
      
      // Remove processed JSON
      _messageBuffer = _messageBuffer.substring(jsonEnd + 1);
      
      // Trim whitespace
      _messageBuffer = _messageBuffer.trimLeft();
      
      // Reset and continue processing
      continue;
    } else {
      // No complete JSON found
      if (debugLog) {
        print("⏳ No complete JSON found yet");
        
        // Check if we have a partial JSON
        if (_messageBuffer.contains('{')) {
          // We have a start but no end
          // Check buffer size - if too large, something is wrong
          if (_messageBuffer.length > 5000) {
            print("⚠️⚠️⚠️ BUFFER TOO LARGE (${_messageBuffer.length} chars)!");
            print("⚠️ This suggests corrupted data or missing JSON end");
            
            // Try emergency recovery: find next telemetry marker
            int nextTelemetry = _messageBuffer.indexOf('"type":"telemetry"');
            if (nextTelemetry != -1) {
              // Go back to find the '{' before telemetry
              int braceBeforeTelemetry = _messageBuffer.lastIndexOf('{', nextTelemetry);
              if (braceBeforeTelemetry != -1) {
                print("⚠️ Attempting emergency recovery at position $braceBeforeTelemetry");
                _messageBuffer = _messageBuffer.substring(braceBeforeTelemetry);
                continue; // Try again with cleaned buffer
              }
            }
            
            // Last resort: clear buffer
            print("⚠️ Clearing corrupted buffer");
            _messageBuffer = '';
          }
        }
      }
      
      // Wait for more data
      break;
    }
  }
}

int _findCompleteJsonEnd(String text) {
  int braceCount = 0;
  bool inString = false;
  bool escaped = false;
  bool foundStart = false;
  
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    
    if (escaped) {
      escaped = false;
      continue;
    }
    
    if (char == '\\') {
      escaped = true;
      continue;
    }
    
    if (char == '"' && !escaped) {
      inString = !inString;
      continue;
    }
    
    if (!inString) {
      if (char == '{') {
        if (!foundStart) {
          foundStart = true;
        }
        braceCount++;
      } else if (char == '}') {
        braceCount--;
        
        if (braceCount == 0 && foundStart) {
          // Found the end of a complete JSON object
          // Check if next characters are valid (end of JSON or whitespace)
          if (i == text.length - 1) {
            return i; // End of buffer
          }
          
          // Check next character
          final nextChar = i < text.length - 1 ? text[i + 1] : '';
          
          // Valid endings: end of string, whitespace, or another JSON start
          if (nextChar == '' || 
              nextChar == '\n' || 
              nextChar == '\r' || 
              nextChar == ' ' ||
              nextChar == '{') {
            return i;
          }
          
          // For ESP32 telemetry, we might have extra closing braces
          // Check if we're at a valid telemetry JSON end
          final jsonSubstring = text.substring(0, i + 1);
          if (jsonSubstring.contains('"type":"telemetry"') &&
              jsonSubstring.contains('"device_id":"HELMET_001"')) {
            
            // Count how many closing braces we have at the end
            int extraBraces = 0;
            for (int j = i + 1; j < text.length; j++) {
              if (text[j] == '}') {
                extraBraces++;
              } else {
                break;
              }
            }
            
            // Return position including valid extra braces
            // ESP32 telemetry should end with either }} or }}}
            if (extraBraces == 1 || extraBraces == 2) {
              return i + extraBraces;
            }
            
            return i;
          }
        } else if (braceCount < 0) {
          // Malformed - more closing than opening
          return -1;
        }
      }
    }
  }
  
  return -1; // No complete JSON found
}

void _parseAndEmitJson(String jsonStr) {
  try {
    // Clean the JSON string
    jsonStr = jsonStr.trim();
    
    // Fix common ESP32 issues
    jsonStr = _fixEsp32Json(jsonStr);
    
    if (!jsonStr.startsWith('{') || !jsonStr.endsWith('}')) {
      if (debugLog) print("⚠️ JSON doesn't start/end with braces");
      return;
    }
    
    // Parse with auto-conversion for numbers
    final Map<String, dynamic> parsed = _parseJsonWithAutoConversion(jsonStr);
    
    if (parsed.isNotEmpty) {
      if (debugLog) {
        print("✅ JSON parsed successfully");
        print("   Device: ${parsed['device_id']}");
        print("   Type: ${parsed['type']}");
        print("   Timestamp: ${parsed['ts']}");
        print("   Helmet: ${parsed['helmet_on']}");
        
        // Show ALL heart rate data
        if (parsed['heart_rate'] is Map) {
          final heartRate = parsed['heart_rate'] as Map<String, dynamic>;
          print("   ❤️ Heart Rate:");
          print("      ok: ${heartRate['ok']}");
          print("      ir: ${heartRate['ir']}");
          print("      red: ${heartRate['red']}");
          print("      finger: ${heartRate['finger']}");
          print("      hr: ${heartRate['hr']}");
          print("      spo2: ${heartRate['spo2']}");
        }
        
        // Show ALL IMU data
        if (parsed['imu'] is Map) {
          final imu = parsed['imu'] as Map<String, dynamic>;
          print("   📊 IMU:");
          print("      ok: ${imu['ok']}");
          print("      sleep: ${imu['sleep']}");
          print("      ax: ${imu['ax']}");
          print("      ay: ${imu['ay']}");
          print("      az: ${imu['az']}");
          print("      gx: ${imu['gx']}");
          print("      gy: ${imu['gy']}");
          print("      gz: ${imu['gz']}");
        }
        
        // Show ALL GPS data
        if (parsed['gps'] is Map) {
          final gps = parsed['gps'] as Map<String, dynamic>;
          print("   📍 GPS:");
          print("      ok: ${gps['ok']}");
          print("      lat: ${gps['lat']}");
          print("      lng: ${gps['lng']}");
          print("      alt: ${gps['alt']}");
          print("      sats: ${gps['sats']}");
          print("      lock: ${gps['lock']}");
        }
        
        // Show velocity
        if (parsed['velocity'] is Map) {
          final velocity = parsed['velocity'] as Map<String, dynamic>;
          print("   🚀 Velocity: ${velocity['kmh']} km/h");
        }
        
        // Show FULL JSON for debugging
        print("📊 FULL JSON DATA:");
        print(jsonStr);
        print("📊 END OF JSON");
      }
      _controller.add(parsed);
    }
  } catch (e) {
    if (debugLog) {
      print("❌ JSON parse failed: $e");
      print("❌ JSON length: ${jsonStr.length}");
      print("❌ FULL JSON (for debugging):");
      print(jsonStr);
    }
  }
}

String _fixEsp32Json(String jsonStr) {
  String fixed = jsonStr;
  
  // Make sure velocity field is complete
  if (fixed.contains('"velocity":{"kmh"') && !fixed.contains('"velocity":{"kmh":')) {
    // Add missing colon and value
    fixed = fixed.replaceAll('"velocity":{"kmh"', '"velocity":{"kmh":0');
  }
  
  if (fixed.contains('"velocity":{"kmh":') && !fixed.contains('"velocity":{"kmh":0}')) {
    // Add missing closing brace
    if (fixed.endsWith('}')) {
      // Already has one closing brace, need one more
      fixed += '}';
    } else {
      fixed += '}}';
    }
  }
  
  return fixed;
}

bool _isValidJson(String jsonStr) {
  try {
    jsonDecode(jsonStr);
    return true;
  } catch (_) {
    return false;
  }
}

Map<String, dynamic> _parseJsonWithAutoConversion(String jsonStr) {
  try {
    // First parse normally
    final dynamic raw = jsonDecode(jsonStr);
    
    // Recursively convert all string numbers to actual numbers
    return _convertNumbers(raw);
  } catch (e) {
    // Try to fix common ESP32 issues
    String fixed = jsonStr;
    
    // Fix: Ensure it ends with proper number of braces
    int openBraces = '${fixed.split('{').length - 1}' as int;
    int closeBraces = '${fixed.split('}').length - 1}' as int;
    
    // ESP32 telemetry typically has nested objects, so we expect at least 2 closing braces
    if (closeBraces < 2) {
      fixed += '}' * (2 - closeBraces);
    }
    
    // Parse the fixed version
    final dynamic raw = jsonDecode(fixed);
    return _convertNumbers(raw);
  }
}

  dynamic _convertNumbers(dynamic value) {
    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((key, val) {
        result[key.toString()] = _convertNumbers(val);
      });
      return result;
    } else if (value is List) {
      return value.map(_convertNumbers).toList();
    } else if (value is String) {
      // Try to convert string to number if it looks like a number
      if (_isNumeric(value)) {
        // Check if it's an integer or double
        if (value.contains('.') || value.contains('e') || value.contains('E')) {
          try {
            return double.parse(value);
          } catch (_) {
            return value;
          }
        } else {
          try {
            return int.parse(value);
          } catch (_) {
            return value;
          }
        }
      }
      return value;
    }
    return value;
  }

  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    
    // Check for scientific notation
    final numericRegex = RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$');
    return numericRegex.hasMatch(str);
  }

  void _trySalvageJson(String jsonStr) {
    // Try to extract valid JSON from the string
    int firstBrace = jsonStr.indexOf('{');
    int lastBrace = jsonStr.lastIndexOf('}');
    
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      String potentialJson = jsonStr.substring(firstBrace, lastBrace + 1);
      
      // Quick check if it looks like ESP32 telemetry
      if (potentialJson.contains('"type":"telemetry"') && 
          potentialJson.contains('"device_id":')) {
        
        try {
          final Map<String, dynamic> parsed = _parseJsonWithAutoConversion(potentialJson);
          
          if (parsed.isNotEmpty) {
            if (debugLog) print("🛠️ Salvaged JSON from broken data");
            _controller.add(parsed);
          }
        } catch (e) {
          // Couldn't salvage it
        }
      }
    }
  }

  Map<String, dynamic>? _normalizeToMap(dynamic obj) {
    if (obj is Map<String, dynamic>) return obj;
    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), _convertNumbers(v)));
    }
    return null;
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
    _messageBuffer = '';
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
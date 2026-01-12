import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isd/core/errors/flutter_bl_handler.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

final _jsonBufferHelper = JsonBufferHelper();

Telemetry? parseTelemetry(String rawData) {
  try {
    String cleanedData = rawData
        .replaceAll('\x00', '')
        .replaceAll('\r', '')
        .trim();
    
    print('📥 Raw data received: ${cleanedData.length} chars');
    
    if (!cleanedData.startsWith('{')) {
      int jsonStart = cleanedData.indexOf('{');
      if (jsonStart != -1) {
        cleanedData = cleanedData.substring(jsonStart);
      } else {
        return null;
      }
    }
    
    _jsonBufferHelper.addChunk(cleanedData);
    final completeJsons = _jsonBufferHelper.extractCompleteJsons();
    
    if (completeJsons.isNotEmpty) {
      Telemetry? latestTelemetry;
      for (final jsonData in completeJsons) {
        latestTelemetry = _parseTelemetryFromJson(jsonData);
      }
      return latestTelemetry;
    } else {
      if (_jsonBufferHelper.bufferLength > 0) {
        print('⏳ Buffer: ${_jsonBufferHelper.bufferLength} chars');
      }
      return null;
    }
  } catch (e, s) {
    print('❌ Telemetry parse error: $e');
    print(s);
    return null;
  }
}

Telemetry? _parseTelemetryFromJson(Map<String, dynamic> jsonData) {
  try {
    if (jsonData['type'] == 'RISK_STATUS') {
      print('⚠️ RISK_STATUS message detected in telemetry parser');
      print('   Level: ${jsonData['payload']?['level']}');
      print('   Score: ${jsonData['payload']?['score']}');
      return null;
    }
    
    if (jsonData['type'] != 'telemetry' && !jsonData.containsKey('ts')) {
      print('⚠️ Unknown message type: ${jsonData['type']}');
      return null;
    }
    
    final convertedData = _convertNumbers(jsonData);
    
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final uid = user?.uid;

    final deviceIdFromJson = convertedData['device_id'] as String? ?? 'HELMET_001';
    
    final enhancedPayload = Map<String, dynamic>.from(convertedData);
    enhancedPayload['device_id'] = deviceIdFromJson;
    enhancedPayload['user_id'] = uid ?? 'unknown_user';
    enhancedPayload['parsed_at'] = DateTime.now().millisecondsSinceEpoch;

    print('🎯 TELEMETRY DATA RECEIVED:');
    print(jsonEncode(enhancedPayload));
    print('🎯 END OF TELEMETRY DATA');

    final telemetry = Telemetry.fromJson(enhancedPayload);

    print('✅ TELEMETRY PARSED SUCCESSFULLY:');
    print('  Device: ${telemetry.deviceId}');
    print('  Helmet: ${telemetry.helmetOn ? "✅ ON" : "❌ OFF"}');
    print('  Timestamp: ${telemetry.ts}');
    
    if (telemetry.heartRate != null && telemetry.heartRate!.ok) {
      print('  ❤️  HEART RATE: ${telemetry.heart} BPM, SpO2: ${telemetry.spo2}%');
      print('     Finger: ${telemetry.fingerDetected ? "✅ Detected" : "❌ Not detected"}');
    } else {
      print('  ❤️  HEART RATE: No data');
    }
    
    if (telemetry.imu != null && telemetry.imu!.ok) {
      print('  📊 IMU:');
      print('     Accel: X=${telemetry.ax?.toStringAsFixed(2)}, Y=${telemetry.ay?.toStringAsFixed(2)}, Z=${telemetry.az?.toStringAsFixed(2)}');
      print('     Gyro: X=${telemetry.gx?.toStringAsFixed(2)}, Y=${telemetry.gy?.toStringAsFixed(2)}, Z=${telemetry.gz?.toStringAsFixed(2)}');
    }
    
    if (telemetry.gps != null && telemetry.gps!.ok) {
      print('  📍 GPS: ${telemetry.lat.toStringAsFixed(6)}, ${telemetry.lon.toStringAsFixed(6)}');
      print('     Lock: ${telemetry.gpsLock ? "✅" : "❌"}, Sats: ${telemetry.satellites}');
    } else {
      print('  📍 GPS: No lock');
    }
    
    print('  🚀 Speed: ${telemetry.speed?.toStringAsFixed(1) ?? "0"} km/h');

    return telemetry;
  } catch (e, s) {
    print('❌ Error parsing telemetry from JSON: $e');
    print('❌ FULL JSON data that failed:');
    print(jsonEncode(jsonData));
    print(s);
    return null;
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
    if (_isNumeric(value)) {
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
  final numericRegex = RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$');
  return numericRegex.hasMatch(str);
}

void clearJsonBuffer() {
  _jsonBufferHelper.clear();
}

String getBufferStatus() {
  return 'Buffer: ${_jsonBufferHelper.bufferLength} chars';
}
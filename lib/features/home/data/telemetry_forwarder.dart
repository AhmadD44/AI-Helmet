import 'dart:convert';
import 'dart:math' as math;
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
    // Ensure all numbers are properly typed
    final convertedData = _convertNumbers(jsonData);
    
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final uid = user?.uid;

    final deviceIdFromJson = convertedData['device_id'] as String? ?? 'HELMET_001';
    
    final enhancedPayload = Map<String, dynamic>.from(convertedData);
    enhancedPayload['device_id'] = deviceIdFromJson;
    enhancedPayload['user_id'] = uid ?? 'unknown_user';
    enhancedPayload['parsed_at'] = DateTime.now().millisecondsSinceEpoch;

    // Show FULL data before creating Telemetry object
    print('🎯 FULL TELEMETRY DATA RECEIVED:');
    print(jsonEncode(enhancedPayload));
    print('🎯 END OF TELEMETRY DATA');

    final telemetry = Telemetry.fromJson(enhancedPayload);

    print('✅ TELEMETRY PARSED SUCCESSFULLY:');
    print('  Device: ${telemetry.deviceId}');
    print('  Helmet: ${telemetry.helmetOn ? "✅ ON" : "❌ OFF"}');
    
    if (telemetry.heartRate != null) {
      print('  ❤️  HEART RATE SENSOR:');
      print('     OK: ${telemetry.heartRate!.ok}');
      print('     IR: ${telemetry.heartRate!.ir}');
      print('     Red: ${telemetry.heartRate!.red}');
      print('     Finger: ${telemetry.heartRate!.finger}');
      print('     HR: ${telemetry.heartRate!.hr} BPM');
      print('     SpO2: ${telemetry.heartRate!.spo2}%');
    }
    
    if (telemetry.imu != null) {
      print('  📊 IMU SENSOR:');
      print('     OK: ${telemetry.imu!.ok}');
      print('     Sleep: ${telemetry.imu!.sleep}');
      print('     Accel X: ${telemetry.ax}');
      print('     Accel Y: ${telemetry.ay}');
      print('     Accel Z: ${telemetry.az}');
      print('     Gyro X: ${telemetry.gx}');
      print('     Gyro Y: ${telemetry.gy}');
      print('     Gyro Z: ${telemetry.gz}');
    }
    
    if (telemetry.gps != null) {
      print('  📍 GPS:');
      print('     OK: ${telemetry.gps!.ok}');
      print('     Lat: ${telemetry.lat}');
      print('     Lon: ${telemetry.lon}');
      print('     Alt: ${telemetry.altitude}');
      print('     Sats: ${telemetry.satellites}');
      print('     Lock: ${telemetry.gpsLock}');
    }
    
    print('  🚀 Speed: ${telemetry.speed ?? 0} km/h');

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
    // Try to convert numeric strings
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
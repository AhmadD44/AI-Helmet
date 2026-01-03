import 'package:firebase_auth/firebase_auth.dart';
import 'package:isd/core/errors/flutter_bl_handler.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

// Global JSON buffer instance
final _jsonBufferHelper = JsonBufferHelper();

Telemetry? parseTelemetry(String rawData) {
  try {
    print('📥 Raw data received: ${rawData.length} chars');
    print('📥 Preview: ${rawData.substring(0, min(rawData.length, 50))}');
    
    // Add chunk to buffer
    _jsonBufferHelper.addChunk(rawData);
    
    // Try to extract complete JSONs
    final completeJsons = _jsonBufferHelper.extractCompleteJsons();
    
    if (completeJsons.isNotEmpty) {
      // Process the first complete JSON
      final jsonData = completeJsons.first;
      return _parseTelemetryFromJson(jsonData);
    } else {
      print('⏳ No complete JSON yet, buffer: ${_jsonBufferHelper.bufferLength} chars');
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
    // Get Firebase UID
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final uid = user?.uid;

    // Use actual device_id from ESP32
    final deviceIdFromJson = jsonData['device_id'] as String? ?? 'HELMET_001';
    
    // Create enhanced payload
    final enhancedPayload = Map<String, dynamic>.from(jsonData);
    enhancedPayload['device_id'] = deviceIdFromJson;
    enhancedPayload['user_id'] = uid ?? 'unknown_user';
    enhancedPayload['parsed_at'] = DateTime.now().millisecondsSinceEpoch;

    // Create Telemetry object
    final telemetry = Telemetry.fromJson(enhancedPayload);

    // Debug log
    print('🎯 TELEMETRY PARSED SUCCESSFULLY:');
    print('  Device: ${telemetry.deviceId}');
    print('  Helmet: ${telemetry.helmetOn ? "✅ ON" : "❌ OFF"}');
    
    if (telemetry.heartRate?.ok == true) {
      print('  ❤️  HR: ${telemetry.heart} BPM, SpO2: ${telemetry.spo2}%');
      print('  👆 Finger: ${telemetry.fingerDetected ? "Detected" : "Not detected"}');
    } else {
      print('  ❗ Heart rate sensor: ${telemetry.heartRate?.ok == false ? "ERROR" : "No data"}');
    }
    
    print('  📍 GPS: ${telemetry.lat}, ${telemetry.lon} (${telemetry.gpsLock ? "🔒 LOCKED" : "🔓 No lock"})');
    print('  🚀 Speed: ${telemetry.speed ?? 0} km/h');
    
    if (telemetry.imu?.ok == true) {
      print('  📊 IMU: X=${telemetry.ax?.toStringAsFixed(2)}, Y=${telemetry.ay?.toStringAsFixed(2)}, Z=${telemetry.az?.toStringAsFixed(2)}');
    }

    return telemetry;
  } catch (e, s) {
    print('❌ Error parsing telemetry from JSON: $e');
    print('❌ JSON data: $jsonData');
    print(s);
    return null;
  }
}

// Helper to clear buffer when disconnecting
void clearJsonBuffer() {
  _jsonBufferHelper.clear();
}

String getBufferStatus() {
  return 'Buffer: ${_jsonBufferHelper.bufferLength} chars';
}

int min(int a, int b) => a < b ? a : b;
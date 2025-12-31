import 'package:isd/features/home/presentation/widgets/telemetry.dart';

Telemetry? parseTelemetry(Map<String, dynamic> payload) {
  try {
    print('=== DEBUG PAYLOAD ===');
    payload.forEach((key, value) {
      print('$key: $value (type: ${value.runtimeType})');
    });
    
    // Extract nested data
    final heartMap = payload['heart'] as Map?;
    final imu = payload['imu'] as Map?;
    final gps = payload['gps'] as Map?;
    final velocityMap = payload['velocity'] as Map?;
    
    if (gps != null) {
      print('=== GPS DATA ===');
      gps.forEach((key, value) {
        print('  gps.$key: $value (type: ${value.runtimeType})');
      });
    }
    
    if (imu != null) {
      print('=== IMU DATA ===');
      imu.forEach((key, value) {
        print('  imu.$key: $value (type: ${value.runtimeType})');
      });
    }

    // Safe parsing function
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        print('⚠️ Converting string to double: "$value"');
        return double.tryParse(value);
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) {
        print('⚠️ Converting string to int: "$value"');
        return int.tryParse(value);
      }
      return null;
    }

    // Get heart rate from nested map
    final heartRate = heartMap?['hr'];
    final velocityValue = velocityMap?['kmh'];
    
    // GPS uses 'lng' not 'lon' based on your debug output
    final gpsLon = gps?['lng'] ?? gps?['lon'];

    final telemetry = Telemetry(
      // t is "telemetry" string, so use ts or generate packet number
      t: parseInt(payload['ts']) ?? 0, // Use timestamp as packet number
      ts: parseInt(payload['ts']) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      helmetOn: payload['helmet_on'] == true,
      heart: parseInt(heartRate), // Get from nested heart.hr
      lat: parseDouble(gps?['lat']) ?? 0.0,
      lon: parseDouble(gpsLon) ?? 0.0, // Use 'lng' field
      ax: parseDouble(imu?['ax']), // IMU uses 'ax', 'ay', 'az' (not 'x', 'y', 'z')
      ay: parseDouble(imu?['ay']),
      az: parseDouble(imu?['az']),
      velocity: parseDouble(velocityValue), // Get from velocity.kmh
    );

    print('✅ Telemetry parsed successfully');
    print('  Packet #: ${telemetry.t}');
    print('  Timestamp: ${telemetry.ts}');
    print('  Heart: ${telemetry.heart} bpm');
    print('  GPS: ${telemetry.lat}, ${telemetry.lon}');
    print('  Velocity: ${telemetry.velocity} km/h');
    print('  IMU: ax=${telemetry.ax}, ay=${telemetry.ay}, az=${telemetry.az}');
    
    return telemetry;
  } catch (e, s) {
    print('❌ Telemetry parse crash: $e');
    print('Stack trace: $s');
    return null;
  }
}
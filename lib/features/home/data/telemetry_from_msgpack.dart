import 'package:isd/features/home/presentation/widgets/telemetry.dart';

Telemetry? telemetryFromMsgpack(Map<String, dynamic> payload) {
  if (payload['type'] != 'telemetry') return null;

  final gps = payload['gps'];
  if (gps is! Map) return null;

  final lat = gps['lat'];
  final lng = gps['lng'];
  if (lat == null || lng == null) return null;

  final hr = payload['heart_rate'];
  final imu = payload['imu'];

  return Telemetry(
    latitude: (lat as num).toDouble(),
    longitude: (lng as num).toDouble(),
    heartRate: (hr is Map) ? (hr['hr'] as num?)?.toInt() : null,
    crashFlag: (payload['crash_flag'] as bool?) ?? false,
    ax: (imu is Map) ? (imu['ax'] as num?)?.toDouble() : null,
    ay: (imu is Map) ? (imu['ay'] as num?)?.toDouble() : null,
    az: (imu is Map) ? (imu['az'] as num?)?.toDouble() : null,
  );
}

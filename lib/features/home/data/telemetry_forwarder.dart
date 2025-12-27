import 'dart:convert';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'ingest_ws_client.dart';

class TelemetryForwarder {
  final IngestWsClient ingest;

  TelemetryForwarder({required this.ingest});

  /// Returns Telemetry if payload is telemetry, otherwise null.
  /// Always forwards payload to backend ingest.
  Future<Telemetry?> handleIncomingJsonString(String jsonStr) async {
    // Some logs might include prefixes like: "[12:59:06 PM] {...}"
    final raw = jsonStr.trim();
    final start = raw.indexOf('{');
    final cleaned = (start >= 0) ? raw.substring(start) : raw;

    final payload = jsonDecode(cleaned) as Map<String, dynamic>;

    // ✅ forward to backend ingest (ws://.../ws/ingest)
    // If you don't want duplicates (because mock_sender already ingests),
    // you can remove this line.
    await ingest.send(payload);

    if (payload['type'] != 'telemetry') return null;

    final gps = payload['gps'] as Map<String, dynamic>? ?? {};
    final hr = payload['heart_rate'] as Map<String, dynamic>? ?? {};
    final imu = payload['imu'] as Map<String, dynamic>? ?? {};

    return Telemetry(
      latitude: ((gps['lat'] as num?)?.toDouble()) ?? 33.8938,
      longitude: ((gps['lng'] as num?)?.toDouble()) ?? 35.5018,
      heartRate: (hr['hr'] as num?)?.toInt(),
      crashFlag: payload['crash_flag'],
      ax: (imu['ax'] as num?)?.toDouble(),
      ay: (imu['ay'] as num?)?.toDouble(),
      az: (imu['az'] as num?)?.toDouble(),
      // ts: payload['ts'] as String?,
    );
  }
}

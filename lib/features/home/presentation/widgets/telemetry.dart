class Telemetry {
  final double latitude;
  final double longitude;

  final int? heartRate;     // BPM
  final bool? crashFlag;    // true/false

  // acceleration from IMU (your mock shows az around 9.7 => m/s^2)
  final double? ax;
  final double? ay;
  final double? az;

  final String? ts;

  const Telemetry({
    required this.latitude,
    required this.longitude,
    this.heartRate,
    this.crashFlag,
    this.ax,
    this.ay,
    this.az,
    this.ts,
  });
}

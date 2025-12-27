class Telemetry {
  final double latitude;
  final double longitude;

  final int? heartRate;
  final bool crashFlag;

  // Accel (G-force components)
  final double? ax;
  final double? ay;
  final double? az;

  const Telemetry({
    required this.latitude,
    required this.longitude,
    this.heartRate,
    this.crashFlag = false,
    this.ax,
    this.ay,
    this.az,
  });
}

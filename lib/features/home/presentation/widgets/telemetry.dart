class Telemetry {
  final int t;
  final int ts;
  final bool helmetOn;
  final int? heart;
  final double lat;
  final double lon;
  final double? ax;
  final double? ay;
  final double? az;
  final double? velocity;

  const Telemetry({
    required this.t,
    required this.ts,
    required this.helmetOn,
    this.heart,
    required this.lat,
    required this.lon,
    this.ax,
    this.ay,
    this.az,
    this.velocity,
  });
}

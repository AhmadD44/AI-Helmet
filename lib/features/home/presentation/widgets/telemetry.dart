import 'package:equatable/equatable.dart';

class Telemetry extends Equatable {
  final double latitude;
  final double longitude;
  final double? speedMps;   // m/s
  final double? bearing;    // degrees
  final double? altitude;   // meters
  final double? accuracy;   // meters
  final int? heartRate;     // bpm

  const Telemetry({
    required this.latitude,
    required this.longitude,
    this.speedMps,
    this.bearing,
    this.altitude,
    this.accuracy,
    this.heartRate,
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    // Accept both snake_case / camelCase keys as a convenience
    double _d(dynamic v) => (v == null) ? 0.0 : (v as num).toDouble();
    int? _i(dynamic v) => (v == null) ? null : (v as num).toInt();

    return Telemetry(
      latitude: _d(json['latitude'] ?? json['lat']),
      longitude: _d(json['longitude'] ?? json['lng'] ?? json['lon']),
      speedMps: json['speed_mps'] != null ? _d(json['speed_mps']) : (json['speed'] != null ? _d(json['speed']) : null),
      bearing: json['bearing'] != null ? _d(json['bearing']) : json['heading'] != null ? _d(json['heading']) : null,
      altitude: json['altitude'] != null ? _d(json['altitude']) : null,
      accuracy: json['accuracy'] != null ? _d(json['accuracy']) : null,
      heartRate: _i(json['heart_rate']),
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, speedMps, bearing, altitude, accuracy, heartRate];
}

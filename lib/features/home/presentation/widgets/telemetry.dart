import 'package:equatable/equatable.dart';

class Telemetry extends Equatable {
  final double latitude;
  final double longitude;
  final double? speedMps;
  final double? bearing;
  final double? altitude;
  final double? accuracy;
  final int? heartRate;

  const Telemetry({
    required this.latitude,
    required this.longitude,
    this.speedMps,
    this.bearing,
    this.altitude,
    this.accuracy,
    this.heartRate,
  });

  @override
  List<Object?> get props =>
      [latitude, longitude, speedMps, bearing, altitude, accuracy, heartRate];
}

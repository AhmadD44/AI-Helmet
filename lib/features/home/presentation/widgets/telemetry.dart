// lib/features/home/presentation/widgets/telemetry.dart
import 'package:equatable/equatable.dart';

class Telemetry extends Equatable {
  final int ts;  // timestamp
  final String deviceId;
  final bool helmetOn;
  
  final HeartRateData? heartRate;
  final ImuData? imu;
  final GpsData? gps;
  final VelocityData? velocity;

  const Telemetry({
    required this.ts,
    required this.deviceId,
    required this.helmetOn,
    this.heartRate,
    this.imu,
    this.gps,
    this.velocity,
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      deviceId: (json['device_id'] as String?) ?? 'unknown',
      helmetOn: (json['helmet_on'] as bool?) ?? false,
      heartRate: json['heart_rate'] != null 
          ? HeartRateData.fromJson(Map<String, dynamic>.from(json['heart_rate']))
          : null,
      imu: json['imu'] != null 
          ? ImuData.fromJson(Map<String, dynamic>.from(json['imu']))
          : null,
      gps: json['gps'] != null 
          ? GpsData.fromJson(Map<String, dynamic>.from(json['gps']))
          : null,
      velocity: json['velocity'] != null 
          ? VelocityData.fromJson(Map<String, dynamic>.from(json['velocity']))
          : null,
    );
  }

  // Helper getters for convenience
  int? get heart => heartRate?.hr;
  int? get spo2 => heartRate?.spo2;
  bool get fingerDetected => heartRate?.finger ?? false;
  
  double get lat => gps?.lat ?? 0.0;
  double get lon => gps?.lng ?? 0.0;
  double? get altitude => gps?.alt;
  int? get satellites => gps?.sats;
  bool get gpsLock => gps?.lock ?? false;
  
  double? get ax => imu?.ax;
  double? get ay => imu?.ay;
  double? get az => imu?.az;
  double? get gx => imu?.gx;
  double? get gy => imu?.gy;
  double? get gz => imu?.gz;
  
  double? get speed => velocity?.kmh;

  @override
  List<Object?> get props => [
    ts,
    deviceId,
    helmetOn,
    heartRate,
    imu,
    gps,
    velocity,
  ];
}

class HeartRateData extends Equatable {
  final bool ok;
  final int? ir;
  final int? red;
  final bool finger;
  final int? hr;
  final int? spo2;

  const HeartRateData({
    required this.ok,
    this.ir,
    this.red,
    required this.finger,
    this.hr,
    this.spo2,
  });

  factory HeartRateData.fromJson(Map<String, dynamic> json) {
    return HeartRateData(
      ok: json['ok'] as bool? ?? false,
      ir: (json['ir'] as num?)?.toInt(),
      red: (json['red'] as num?)?.toInt(),
      finger: json['finger'] as bool? ?? false,
      hr: (json['hr'] as num?)?.toInt(),
      spo2: (json['spo2'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [ok, ir, red, finger, hr, spo2];
}

class ImuData extends Equatable {
  final bool ok;
  final bool sleep;
  final double? ax;
  final double? ay;
  final double? az;
  final double? gx;
  final double? gy;
  final double? gz;

  const ImuData({
    required this.ok,
    required this.sleep,
    this.ax,
    this.ay,
    this.az,
    this.gx,
    this.gy,
    this.gz,
  });

  factory ImuData.fromJson(Map<String, dynamic> json) {
    return ImuData(
      ok: json['ok'] as bool? ?? false,
      sleep: json['sleep'] as bool? ?? false,
      ax: (json['ax'] as num?)?.toDouble(),
      ay: (json['ay'] as num?)?.toDouble(),
      az: (json['az'] as num?)?.toDouble(),
      gx: (json['gx'] as num?)?.toDouble(),
      gy: (json['gy'] as num?)?.toDouble(),
      gz: (json['gz'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [ok, sleep, ax, ay, az, gx, gy, gz];
}

class GpsData extends Equatable {
  final bool ok;
  final double lat;
  final double lng;
  final double? alt;
  final int? sats;
  final bool lock;

  const GpsData({
    required this.ok,
    required this.lat,
    required this.lng,
    this.alt,
    this.sats,
    required this.lock,
  });

  factory GpsData.fromJson(Map<String, dynamic> json) {
    return GpsData(
      ok: json['ok'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      alt: (json['alt'] as num?)?.toDouble(),
      sats: (json['sats'] as num?)?.toInt(),
      lock: json['lock'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [ok, lat, lng, alt, sats, lock];
}

class VelocityData extends Equatable {
  final double? kmh;

  const VelocityData({this.kmh});

  factory VelocityData.fromJson(Map<String, dynamic> json) {
    return VelocityData(
      kmh: (json['kmh'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [kmh];
}
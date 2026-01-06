import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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
      ir: (json['ir'] as num?)?.toInt() ?? 0,
      red: (json['red'] as num?)?.toInt() ?? 0,
      finger: json['finger'] as bool? ?? false,
      hr: (json['hr'] as num?)?.toInt() ?? 0,
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

// RiskData class for RISK_STATUS messages from WebSocket
class RiskData extends Equatable {
  final String level; // NORMAL, MEDIUM, HIGH
  final int score;
  final List<String> reasons;
  final double speedKmh;

  const RiskData({
    required this.level,
    required this.score,
    required this.reasons,
    required this.speedKmh,
  });

  // In telemetry.dart, update the RiskData.fromJson factory:

factory RiskData.fromJson(Map<String, dynamic> json) {
  print('🔍 RiskData.fromJson called with: $json');
  
  try {
    // Extract level
    String level = 'NORMAL';
    if (json['level'] != null) {
      level = json['level'].toString().toUpperCase();
    }
    
    // Extract score
    int score = 0;
    if (json['score'] != null) {
      if (json['score'] is int) {
        score = json['score'] as int;
      } else if (json['score'] is double) {
        score = (json['score'] as double).round();
      } else if (json['score'] is String) {
        score = int.tryParse(json['score'] as String) ?? 0;
      }
    }
    
    // Extract reasons
    List<String> reasons = [];
    if (json['reasons'] != null) {
      if (json['reasons'] is List) {
        for (var item in json['reasons']) {
          if (item != null) {
            reasons.add(item.toString());
          }
        }
      } else if (json['reasons'] is String) {
        reasons = [json['reasons'] as String];
      }
    }
    
    // Extract speed_kmh (note: underscore in JSON)
    double speedKmh = 0.0;
    if (json['speed_kmh'] != null) {
      if (json['speed_kmh'] is int) {
        speedKmh = (json['speed_kmh'] as int).toDouble();
      } else if (json['speed_kmh'] is double) {
        speedKmh = json['speed_kmh'] as double;
      } else if (json['speed_kmh'] is String) {
        speedKmh = double.tryParse(json['speed_kmh'] as String) ?? 0.0;
      }
    }
    
    final riskData = RiskData(
      level: level,
      score: score,
      reasons: reasons,
      speedKmh: speedKmh,
    );
    
    print('✅ RiskData created: ${riskData.level} (${riskData.score})');
    return riskData;
    
  } catch (e) {
    print('❌ ERROR creating RiskData: $e');
    // Return a default NORMAL risk if parsing fails
    return RiskData(
      level: 'NORMAL',
      score: 0,
      reasons: [],
      speedKmh: 0.0,
    );
  }
}
  Color get color {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'NORMAL':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool get isCrash => level.toUpperCase() == 'HIGH';
  
  String get formattedReasons {
    return reasons.map((r) => r.toUpperCase()).join(', ');
  }

  @override
  List<Object?> get props => [level, score, reasons, speedKmh];
}
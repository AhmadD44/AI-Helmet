class MyTripsModel {
  String? tripId;
  String? deviceId;
  DateTime? startTime;
  DateTime? endTime;
  int? totalDistance;
  int? averageSpeed;
  String? status;

  MyTripsModel({
    this.tripId,
    this.deviceId,
    this.startTime,
    this.endTime,
    this.totalDistance,
    this.averageSpeed,
    this.status,
  });

  factory MyTripsModel.fromJson(Map<String, dynamic> json) => MyTripsModel(
    tripId: json['trip_id'] as String?,
    deviceId: json['device_id'] as String?,
    startTime: json['start_time'] == null
        ? null
        : DateTime.parse(json['start_time'] as String),
    endTime: json['end_time'] == null
        ? null
        : DateTime.parse(json['end_time'] as String),
    totalDistance: json['total_distance'] as int?,
    averageSpeed: json['average_speed'] as int?,
    status: json['status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'device_id': deviceId,
    'start_time': startTime?.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'total_distance': totalDistance,
    'average_speed': averageSpeed,
    'status': status,
  };
}

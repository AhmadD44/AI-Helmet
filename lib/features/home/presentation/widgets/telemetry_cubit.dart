import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:location/location.dart';

class TelemetryState extends Equatable {
  final bool loading;
  final String? error;
  final Telemetry? data;

  const TelemetryState({this.loading = true, this.error, this.data});

  TelemetryState copyWith({bool? loading, String? error, Telemetry? data}) {
    return TelemetryState(
      loading: loading ?? this.loading,
      error: error,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [loading, error, data];
}

class TelemetryCubit extends Cubit<TelemetryState> {
  TelemetryCubit() : super(const TelemetryState(loading: true));

  final Location _location = Location();
  StreamSubscription<LocationData>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1) Check service
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        emit(
          const TelemetryState(
            loading: false,
            error: 'Location service is disabled',
          ),
        );
        return;
      }
    }

    // 2) Check permission
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        emit(
          const TelemetryState(
            loading: false,
            error: 'Location permission denied',
          ),
        );
        return;
      }
    }

    // 3) Configure updates
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 200, // ms
      distanceFilter: 0,
    );

    // 4) Try initial fix (non-fatal)
    try {
      final first = await _location.getLocation();
      _emitFrom(first);
    } catch (_) {
      // ignore; rely on onLocationChanged
    }

    // 5) Subscribe
    _sub = _location.onLocationChanged.listen(
      (data) => _emitFrom(data),
      onError: (e) {
        emit(
          TelemetryState(loading: false, error: e.toString(), data: state.data),
        );
      },
    );
  }

  void _emitFrom(LocationData d) {
    if (d.latitude == null || d.longitude == null) return;

    final telemetry = Telemetry(
      latitude: d.latitude!,
      longitude: d.longitude!,
      speedMps: d.speed,
      bearing: d.heading,
      altitude: d.altitude,
      accuracy: d.accuracy,
      heartRate: null,
    );

    emit(TelemetryState(loading: false, data: telemetry, error: null));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

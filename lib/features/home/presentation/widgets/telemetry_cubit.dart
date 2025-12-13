import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:isd/features/home/data/backend_stream_client.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class TelemetryState extends Equatable {
  final bool loading;
  final String? error;
  final Telemetry? data;

  const TelemetryState({this.loading = true, this.error, this.data});

  @override
  List<Object?> get props => [loading, error, data];
}

class TelemetryCubit extends Cubit<TelemetryState> {
  final BackendStreamClient streamClient;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  bool _started = false;

  TelemetryCubit({required this.streamClient})
      : super(const TelemetryState(loading: true));

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      emit(const TelemetryState(loading: false, error: 'Not logged in'));
      return;
    }

    final String? token = await user.getIdToken();
    print('.');
    print('.');
    print('.');
    print('token: $token');
    print('.');
    print('.');
    print('.');

    try {
      _ch = streamClient.connect(token: token!);

      _sub = _ch!.stream.listen(
        (msg) {
          try {
            final payload = BackendStreamClient.decode(msg);

            if (payload['type'] != 'telemetry') return;

            final gps = payload['gps'] as Map<String, dynamic>? ?? {};
            final hr = payload['heart_rate'] as Map<String, dynamic>? ?? {};
            final imu = payload['imu'] as Map<String, dynamic>? ?? {};

            final t = Telemetry(
              latitude: ((gps['lat'] as num?)?.toDouble()) ?? 33.8938,
              longitude: ((gps['lng'] as num?)?.toDouble()) ?? 35.5018,
              heartRate: (hr['hr'] as num?)?.toInt(),
              crashFlag: payload['crash_flag'] as bool?,
              ax: (imu['ax'] as num?)?.toDouble(),
              ay: (imu['ay'] as num?)?.toDouble(),
              az: (imu['az'] as num?)?.toDouble(),
              ts: payload['ts'] as String?,
            );

            emit(TelemetryState(loading: false, data: t));
          } catch (e) {
            emit(TelemetryState(loading: false, error: e.toString(), data: state.data));
          }
        },
        onError: (e) {
          emit(TelemetryState(loading: false, error: e.toString(), data: state.data));
        },
        onDone: () {
          // don't crash; show disconnected state
          emit(TelemetryState(loading: false, error: 'Stream disconnected', data: state.data));
        },
      );
    } catch (e) {
      emit(TelemetryState(loading: false, error: e.toString(), data: state.data));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _ch?.sink.close();
    return super.close();
  }
}
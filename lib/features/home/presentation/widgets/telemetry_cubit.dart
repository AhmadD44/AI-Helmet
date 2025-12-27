import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';
import 'package:isd/features/home/data/ingest_ws_client.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:isd/features/home/data/telemetry_from_msgpack.dart';

class TelemetryState extends Equatable {
  final bool loading;
  final String? error;
  final Telemetry? data;

  const TelemetryState({this.loading = true, this.error, this.data});

  @override
  List<Object?> get props => [loading, error, data];
}

class TelemetryCubit extends Cubit<TelemetryState> {
  final EspBtClassicSource source;
  final IngestWsClient ingest;

  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _started = false;

  TelemetryCubit({required this.source, required this.ingest})
      : super(const TelemetryState(loading: true));

  Future<void> startWithMac(String mac) async {
    if (_started) return;
    _started = true;

    emit(const TelemetryState(loading: true));

    try {
      await ingest.connect();
    } catch (_) {}

    try {
      await source.initPermissions();
      await source.connect(mac);
    } catch (e) {
      emit(TelemetryState(loading: false, error: 'BT connect failed: $e'));
      return;
    }

    _sub = source.stream.listen((payload) async {
      // forward to backend ingest (best effort)
      try {
        await ingest.send(payload);
      } catch (_) {}

      // update UI telemetry
      final t = telemetryFromMsgpack(payload);
      if (t != null) emit(TelemetryState(loading: false, data: t));
    }, onError: (e) {
      emit(TelemetryState(loading: false, error: e.toString(), data: state.data));
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await source.dispose();
    await ingest.close();
    return super.close();
  }
}

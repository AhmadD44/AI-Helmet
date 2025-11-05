import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:isd/features/home/data/location_repository.dart';

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
  final LocationRepository repo;
  StreamSubscription<Telemetry>? _sub;

  TelemetryCubit(this.repo) : super(const TelemetryState(loading: true));

  void start() {
    repo.start();
    _sub ??= repo.stream.listen(
      (t) => emit(TelemetryState(loading: false, data: t)),
      onError: (e) => emit(TelemetryState(loading: false, error: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    repo.dispose();
    return super.close();
  }
}

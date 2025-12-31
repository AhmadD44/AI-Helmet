import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';
import 'package:isd/features/home/data/ingest_ws_client.dart';
import 'package:isd/features/home/data/telemetry_forwarder.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class TelemetryState extends Equatable {
  final bool loading;
  final String? error;
  final Telemetry? data;
  final bool connected;
  final bool wsConnected; // Track WebSocket connection status
  final int packetsSent; // Track how many packets sent to WebSocket

  const TelemetryState({
    this.loading = false,
    this.error,
    this.data,
    this.connected = false,
    this.wsConnected = false,
    this.packetsSent = 0,
  });

  TelemetryState copyWith({
    bool? loading,
    String? error,
    Telemetry? data,
    bool? connected,
    bool? wsConnected,
    int? packetsSent,
  }) {
    return TelemetryState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      data: data ?? this.data,
      connected: connected ?? this.connected,
      wsConnected: wsConnected ?? this.wsConnected,
      packetsSent: packetsSent ?? this.packetsSent,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        data,
        connected,
        wsConnected,
        packetsSent,
      ];
}

class TelemetryCubit extends Cubit<TelemetryState> {
  final EspBtClassicSource source;
  final IngestWsClient ingest;

  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _starting = false;
  String? _mac;
  int _packetsSent = 0;

  TelemetryCubit({required this.source, required this.ingest})
      : super(const TelemetryState());

  Future<void> startWithMac(String mac) async {
    if (_starting) return;
    _starting = true;
    _mac = mac;

    emit(TelemetryState(loading: true, data: state.data, error: null, connected: false));

    // Connect WebSocket in background without blocking
    _connectWebSocketInBackground();

    try {
      // IMPORTANT: timeout so UI never gets stuck forever
      await source.connect(mac).timeout(const Duration(seconds: 15));
    } catch (e) {
      _starting = false;
      emit(TelemetryState(
        loading: false,
        error: "BT connect failed: $e",
        data: state.data,
        connected: false,
      ));
      return;
    }

    // Bluetooth Connected ✅
    emit(TelemetryState(loading: false, error: null, data: state.data, connected: true));

    await _sub?.cancel();
    _sub = source.stream.listen((payload) async {
      // Parse telemetry first (for UI)
      final t = parseTelemetry(payload);

      // Send to WebSocket in background (non-blocking)
      _sendToWebSocket(payload);

      // Update UI with parsed telemetry
      if (t != null) {
        emit(state.copyWith(data: t, error: null));
      }
    }, onError: (e) {
      emit(TelemetryState(
        loading: false,
        error: e.toString(),
        data: state.data,
        connected: state.connected,
      ));
    });

    _starting = false;
  }

  /// Connect WebSocket in background without blocking main flow
  Future<void> _connectWebSocketInBackground() async {
    unawaited(Future(() async {
      try {
        await ingest.connect();
        if (state.wsConnected == false) {
          emit(state.copyWith(wsConnected: true));
        }
      } catch (e) {
        print('⚠️ WebSocket connect failed: $e');
        // Don't emit error - WebSocket is optional
      }
    }));
  }

  /// Send data to WebSocket in background (fire-and-forget)
  Future<void> _sendToWebSocket(Map<String, dynamic> payload) async {
    try {
      // Optional: Add metadata to payload
      final enhancedPayload = Map<String, dynamic>.from(payload);
      enhancedPayload['_meta'] = {
        'device_id': _mac ?? 'unknown',
        'received_at': DateTime.now().millisecondsSinceEpoch,
        'packet_number': _packetsSent + 1,
      };

      await ingest.send(enhancedPayload);
      _packetsSent++;

      // Update state occasionally (not every packet)
      if (_packetsSent % 10 == 0) {
        emit(state.copyWith(packetsSent: _packetsSent));
      }
    } catch (e) {
      // Silent fail - WebSocket is optional
      print('⚠️ WebSocket send failed: $e');
      
      // Try to reconnect if not connected
      if (state.wsConnected) {
        emit(state.copyWith(wsConnected: false));
        _connectWebSocketInBackground();
      }
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await source.disconnect();
    } catch (_) {}
    emit(TelemetryState(loading: false, error: null, data: state.data, connected: false));
  }

  // Optional: Manual WebSocket reconnect
  Future<void> reconnectWebSocket() async {
    try {
      await ingest.close();
      await _connectWebSocketInBackground();
    } catch (e) {
      print('⚠️ WebSocket reconnect failed: $e');
    }
  }

  String? get currentMac => _mac;

  int get packetsSent => _packetsSent;
  bool get isWsConnected => state.wsConnected;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await source.dispose();
    await ingest.close();
    return super.close();
  }
}
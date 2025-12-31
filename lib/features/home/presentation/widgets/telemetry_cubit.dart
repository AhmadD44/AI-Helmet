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
  final bool wsConnected;
  final int packetsSent;
  final String? connectionStatus;

  const TelemetryState({
    this.loading = false,
    this.error,
    this.data,
    this.connected = false,
    this.wsConnected = false,
    this.packetsSent = 0,
    this.connectionStatus,
  });

  TelemetryState copyWith({
    bool? loading,
    String? error,
    Telemetry? data,
    bool? connected,
    bool? wsConnected,
    int? packetsSent,
    String? connectionStatus,
  }) {
    return TelemetryState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      data: data ?? this.data,
      connected: connected ?? this.connected,
      wsConnected: wsConnected ?? this.wsConnected,
      packetsSent: packetsSent ?? this.packetsSent,
      connectionStatus: connectionStatus ?? this.connectionStatus,
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
        connectionStatus,
      ];
}

class TelemetryCubit extends Cubit<TelemetryState> {
  final EspBtClassicSource source;
  final IngestWsClient ingest;

  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<void>? _errorSub;
  bool _starting = false;
  String? _mac;
  int _packetsSent = 0;

  // Connection monitoring
  Timer? _healthTimer;
  DateTime? _lastDataTime;
  static const Duration healthCheckInterval = Duration(seconds: 5);
  static const Duration dataTimeout = Duration(seconds: 15);

  TelemetryCubit({required this.source, required this.ingest})
      : super(const TelemetryState());

  Future<void> startWithMac(String mac) async {
    if (_starting) return;
    _starting = true;
    _mac = mac;

    emit(TelemetryState(
      loading: true,
      data: state.data,
      error: null,
      connected: false,
      connectionStatus: "Connecting...",
    ));

    // Connect WebSocket in background
    _connectWebSocketInBackground();

    try {
      // Connect to Bluetooth with timeout
      await source.connect(mac).timeout(const Duration(seconds: 15));
      
      // Start listening to stream
      await _setupStreamListeners();
      
      // Start health monitoring
      _startHealthMonitoring();
      
      emit(TelemetryState(
        loading: false,
        error: null,
        data: state.data,
        connected: true,
        wsConnected: state.wsConnected,
        connectionStatus: "Connected",
      ));
      
    } on TimeoutException {
      emit(TelemetryState(
        loading: false,
        error: "Connection timeout",
        data: state.data,
        connected: false,
        connectionStatus: "Timeout",
      ));
    } catch (e) {
      emit(TelemetryState(
        loading: false,
        error: "Connection failed: $e",
        data: state.data,
        connected: false,
        connectionStatus: "Failed",
      ));
    } finally {
      _starting = false;
    }
  }

  Future<void> _setupStreamListeners() async {
    await _sub?.cancel();
    await _errorSub?.cancel();

    // Listen for telemetry data
    _sub = source.stream.listen(
      (payload) async {
        _lastDataTime = DateTime.now();
        
        // Send to WebSocket
        _sendToWebSocket(payload);
        
        // Parse telemetry
        final t = parseTelemetry(payload);
        
        if (t != null) {
          emit(state.copyWith(
            data: t,
            error: null,
            connected: true,
            connectionStatus: "Receiving data",
          ));
        }
      },
      onError: (error) {
        print("❌ Telemetry stream error: $error");
        if (error.toString().contains("disconnected")) {
          emit(state.copyWith(
            connected: false,
            connectionStatus: "Disconnected",
          ));
          
          // Try to reconnect after delay
          _scheduleReconnect();
        }
      },
    );

    // Listen for errors from source
    _errorSub = source.stream.asBroadcastStream().handleError((error) {
      print("❌ Source error: $error");
    }) as StreamSubscription<void>?;
  }

  Future<void> _connectWebSocketInBackground() async {
    unawaited(Future(() async {
      try {
        await ingest.connect();
        if (state.wsConnected == false) {
          emit(state.copyWith(wsConnected: true));
        }
      } catch (e) {
        print('⚠️ WebSocket connect failed: $e');
      }
    }));
  }

  Future<void> _sendToWebSocket(Map<String, dynamic> payload) async {
    try {
      final enhancedPayload = Map<String, dynamic>.from(payload);
      enhancedPayload['_meta'] = {
        'device_id': _mac ?? 'unknown',
        'received_at': DateTime.now().millisecondsSinceEpoch,
        'packet_number': _packetsSent + 1,
      };

      await ingest.send(enhancedPayload);
      _packetsSent++;
      
      if (_packetsSent % 10 == 0) {
        emit(state.copyWith(packetsSent: _packetsSent));
      }
    } catch (e) {
      print('⚠️ WebSocket send failed: $e');
      if (state.wsConnected) {
        emit(state.copyWith(wsConnected: false));
        _connectWebSocketInBackground();
      }
    }
  }

  void _startHealthMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(healthCheckInterval, (timer) {
      if (_lastDataTime != null && 
          DateTime.now().difference(_lastDataTime!) > dataTimeout &&
          state.connected) {
        
        print("⚠️ No data for ${dataTimeout.inSeconds} seconds");
        
        emit(state.copyWith(
          connected: false,
          connectionStatus: "Connection lost - No data",
        ));
        
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    // Wait 2 seconds then try to reconnect
    Future.delayed(const Duration(seconds: 2), () {
      if (_mac != null && !_starting && !state.connected) {
        print("🔄 Attempting auto-reconnect...");
        startWithMac(_mac!);
      }
    });
  }

  Future<void> disconnect() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    
    await _sub?.cancel();
    _sub = null;
    
    await _errorSub?.cancel();
    _errorSub = null;
    
    try {
      await source.disconnect();
    } catch (_) {}
    
    emit(TelemetryState(
      loading: false,
      error: null,
      data: state.data,
      connected: false,
      connectionStatus: "Disconnected",
    ));
  }

  Future<void> reconnect() async {
    if (_mac != null) {
      await startWithMac(_mac!);
    }
  }

  String? get currentMac => _mac;
  int get packetsSent => _packetsSent;
  bool get isWsConnected => state.wsConnected;

  @override
  Future<void> close() async {
    _healthTimer?.cancel();
    await _sub?.cancel();
    await _errorSub?.cancel();
    await source.dispose();
    await ingest.close();
    return super.close();
  }
}
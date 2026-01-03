import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:isd/core/errors/flutter_bl_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';
import 'package:isd/features/home/data/ingest_ws_client.dart';
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
  bool _starting = false;
  String? _mac;
  int _packetsSent = 0;
  
  // JSON Buffer for handling split data
  final _jsonBufferHelper = JsonBufferHelper();

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
    _jsonBufferHelper.clear();
    
    // Step 1: Checking permissions
    emit(TelemetryState(
      loading: true,
      data: state.data,
      error: null,
      connected: false,
      connectionStatus: "Checking permissions...",
    ));
    
    final hasPermissions = await _checkBluetoothPermissions();
    if (!hasPermissions) {
      emit(TelemetryState(
        loading: false,
        error: "Bluetooth permissions required. Please grant permissions in app settings.",
        data: state.data,
        connected: false,
        connectionStatus: "Permissions needed",
      ));
      _starting = false;
      return;
    }

    // Try to connect with retry logic
    bool connected = false;
    int retryCount = 0;
    const int maxRetries = 2;
    
    while (!connected && retryCount < maxRetries) {
      try {
        emit(state.copyWith(
          connectionStatus: retryCount == 0 
              ? "Connecting to device..." 
              : "Retrying connection... (${retryCount + 1}/$maxRetries)",
        ));

        // Connect WebSocket in background
        _connectWebSocketInBackground();

        // Connect to Bluetooth with timeout
        await source.connect(mac).timeout(const Duration(seconds: 15));
        
        // Step 3: Setting up stream
        emit(state.copyWith(
          connectionStatus: "Setting up connection...",
        ));
        
        // Start listening to stream
        await _setupStreamListener();
        
        // Start health monitoring
        _startHealthMonitoring();
        
        // Step 4: Connected
        connected = true;
        emit(TelemetryState(
          loading: false,
          error: null,
          data: state.data,
          connected: true,
          wsConnected: state.wsConnected,
          connectionStatus: "Connected",
        ));
        
      } on TimeoutException {
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        emit(TelemetryState(
          loading: false,
          error: "Connection timeout. Please ensure:\n• Device is powered on\n• Device is in pairing mode\n• You're within range (10m)",
          data: state.data,
          connected: false,
          connectionStatus: "Timeout",
        ));
        _scheduleReconnect();
        
      } on Exception catch (e) {
        retryCount++;
        
        final errorMessage = _parseConnectionError(e);
        
        if (retryCount < maxRetries) {
          print("⚠️ Connection failed, retrying... ($retryCount/$maxRetries)");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        emit(TelemetryState(
          loading: false,
          error: errorMessage,
          data: state.data,
          connected: false,
          connectionStatus: "Failed",
        ));
        
        // Don't auto-retry on certain errors
        if (!errorMessage.contains("paired") && 
            !errorMessage.contains("permission") &&
            !errorMessage.contains("not found")) {
          _scheduleReconnect();
        }
      }
    }
    
    _starting = false;
  }

  String _parseConnectionError(Exception e) {
    final errorStr = e.toString();
    print('🔍 Connection error: $errorStr');
    
    if (errorStr.contains("connection_failed") || errorStr.contains("could not connect")) {
      return "Failed to connect to device. Please ensure:\n"
             "1. Device is powered on\n"
             "2. Device is paired in Android Bluetooth settings\n"
             "3. You're within range (10 meters)\n"
             "4. Device isn't connected to another phone";
    }
    
    if (errorStr.contains("bluetooth_disabled")) {
      return "Bluetooth is disabled. Please enable Bluetooth in device settings.";
    }
    
    if (errorStr.contains("permission") || errorStr.contains("denied")) {
      return "Bluetooth permission denied. Please grant permissions in app settings.";
    }
    
    if (errorStr.contains("device_not_found") || errorStr.contains("not found")) {
      return "Device not found. It may be out of range or turned off.";
    }
    
    if (errorStr.contains("already_connected")) {
      return "Already connected to this device.";
    }
    
    return "Connection failed. Please try again.";
  }

  Future<bool> _checkBluetoothPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Request all necessary permissions
        final permissions = await [
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        
        // Check if all are granted
        return permissions[Permission.locationWhenInUse]?.isGranted == true &&
               permissions[Permission.bluetoothScan]?.isGranted == true &&
               permissions[Permission.bluetoothConnect]?.isGranted == true;
      } catch (e) {
        print('⚠️ Permission check error: $e');
        return false;
      }
    }
    return true; // For iOS
  }

  Future<void> _setupStreamListener() async {
    await _sub?.cancel();

    _sub = source.stream.listen(
      (payload) async {
        _lastDataTime = DateTime.now();
        
        Telemetry? telemetry;
        
        if (payload is String) {
          // Handle raw string data with buffer
          telemetry = _parseTelemetryFromString(payload as String);
        } else if (payload is Map<String, dynamic>) {
          // Already parsed data
          telemetry = _parseTelemetryFromMap(payload);
          
          // Send to WebSocket
          _sendToWebSocket(payload);
        }
        
        if (telemetry != null) {
          emit(state.copyWith(
            data: telemetry,
            error: null,
            connected: true,
            connectionStatus: "Receiving data",
          ));
        }
      },
      onError: (error) {
        print("❌ Telemetry stream error: $error");
        _handleStreamError(error);
      },
      onDone: () {
        print("ℹ️ Telemetry stream closed");
        _handleStreamClosed();
      },
    );
  }

  Telemetry? _parseTelemetryFromString(String rawData) {
    try {
      // Add chunk to buffer
      _jsonBufferHelper.addChunk(rawData);
      
      // Try to extract complete JSONs
      final completeJsons = _jsonBufferHelper.extractCompleteJsons();
      
      if (completeJsons.isNotEmpty) {
        // Process the first complete JSON
        final jsonData = completeJsons.first;
        return _parseTelemetryFromMap(jsonData);
      } else {
        print('⏳ No complete JSON yet, buffer: ${_jsonBufferHelper.bufferLength} chars');
        return null;
      }
    } catch (e) {
      print('❌ Error parsing string to telemetry: $e');
      return null;
    }
  }

  Telemetry? _parseTelemetryFromMap(Map<String, dynamic> payload) {
    try {
      // Use device_id from JSON
      final deviceIdFromJson = payload['device_id'] as String? ?? 'HELMET_001';
      
      // Create enhanced payload
      final enhancedPayload = Map<String, dynamic>.from(payload);
      enhancedPayload['device_id'] = deviceIdFromJson;
      
      // Create Telemetry object
      final telemetry = Telemetry.fromJson(enhancedPayload);

      return telemetry;
    } catch (e) {
      print('❌ Error parsing map to telemetry: $e');
      return null;
    }
  }

  void _handleStreamError(error) {
    if (error.toString().contains("disconnected") ||
        error.toString().contains("connection")) {
      emit(state.copyWith(
        connected: false,
        connectionStatus: "Disconnected",
        error: "Lost connection to device",
      ));
      
      _jsonBufferHelper.clear(); // Clear buffer on disconnect
      _scheduleReconnect();
    }
  }

  void _handleStreamClosed() {
    if (state.connected) {
      emit(state.copyWith(
        connected: false,
        connectionStatus: "Connection closed",
        error: "Connection closed unexpectedly",
      ));
      _jsonBufferHelper.clear();
      _scheduleReconnect();
    }
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
        
        print("⚠️ No data for ${dataTimeout.inSeconds} seconds (Connection kept alive)");
        
        if (state.connectionStatus != "Connected (Idle)") {
           emit(state.copyWith(
            connectionStatus: "Connected (Idle)",
          ));
        }
      }
    });
  }

  void _scheduleReconnect() {
    // Wait 5 seconds then try to reconnect
    Future.delayed(const Duration(seconds: 5), () {
      if (_mac != null && !_starting && !state.connected) {
        print("🔄 Attempting auto-reconnect to $_mac...");
        startWithMac(_mac!);
      }
    });
  }

  Future<void> disconnect() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    
    await _sub?.cancel();
    _sub = null;
    
    _jsonBufferHelper.clear(); // Clear buffer on disconnect
    
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

  String get bufferStatus => 'Buffer: ${_jsonBufferHelper.bufferLength} chars';
  String? get currentMac => _mac;
  int get packetsSent => _packetsSent;
  bool get isWsConnected => state.wsConnected;

  @override
  Future<void> close() async {
    _healthTimer?.cancel();
    await _sub?.cancel();
    _jsonBufferHelper.clear();
    await source.dispose();
    await ingest.close();
    return super.close();
  }
}